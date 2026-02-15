import Foundation
import OSLog
import EchoForgeCore
import EchoForgeGemini
import EchoForgePersistence

actor EpisodeAudioGenerationService {
    private let speechClient: any GeminiSpeechGenerating
    private let projectStore: any ProjectStoring
    private let audioStore: any EpisodeAudioStoring
    private let logger: Logger
    private let retryPolicy: RetryPolicy

    init(
        speechClient: any GeminiSpeechGenerating,
        projectStore: any ProjectStoring,
        audioStore: any EpisodeAudioStoring,
        retryPolicy: RetryPolicy = RetryPolicy()
    ) {
        self.speechClient = speechClient
        self.projectStore = projectStore
        self.audioStore = audioStore
        self.retryPolicy = retryPolicy
        self.logger = Logger(subsystem: "EchoForge", category: "EpisodeAudioGeneration")
    }

    func streamEpisodeAudio(projectID: UUID, episodeID: UUID) -> AsyncThrowingStream<PodcastProject, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [weak self] in
                guard let self else { return }
                do {
                    try await self.generateEpisodeAudio(
                        projectID: projectID,
                        episodeID: episodeID,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch {
                    await self.persistFailure(
                        projectID: projectID,
                        episodeID: episodeID,
                        error: error,
                        continuation: continuation
                    )
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    private func makeSpeechRequest(project: PodcastProject, episode: Episode) -> GeminiSpeechRequest {
        let hostAName = (project.hosts.first(where: { $0.id == .hostA })?.displayName).trimmedNonEmpty
            ?? "Host A"
        let hostBName = (project.hosts.first(where: { $0.id == .hostB })?.displayName).trimmedNonEmpty
            ?? "Host B"

        let script = SpeechScriptBuilder.makeScript(
            hostAName: hostAName,
            hostBName: hostBName,
            lines: episode.lines
        )

        let speakers: [GeminiSpeechSpeaker] = [
            GeminiSpeechSpeaker(name: hostAName, voiceName: "Kore"),
            GeminiSpeechSpeaker(name: hostBName, voiceName: "Puck")
        ]

        return GeminiSpeechRequest(script: script, speakers: speakers)
    }

    private func generateEpisodeAudio(
        projectID: UUID,
        episodeID: UUID,
        continuation: AsyncThrowingStream<PodcastProject, Error>.Continuation
    ) async throws {
        var project = try await projectStore.load(id: projectID)
        guard project.status == .complete else {
            throw EpisodeAudioGenerationError.projectNotReady
        }

        guard var episode = project.episodes.first(where: { $0.id == episodeID }) else {
            throw EpisodeAudioGenerationError.episodeNotFound
        }

        guard episode.status == .complete, !episode.lines.isEmpty else {
            throw EpisodeAudioGenerationError.episodeNotReady
        }

        let fileName = "\(episodeID.uuidString).wav"
        project = try await markAudioGenerating(project: project, episode: &episode, fileName: fileName)
        continuation.yield(project)

        let speechRequest = makeSpeechRequest(project: project, episode: episode)
        let speechResult = try await retryPolicy.run(
            operationName: "Gemini speech generation",
            logger: logger,
            shouldRetry: { @Sendable error in
                isRetryableSpeechError(error)
            },
            operation: { [speechClient] in
                try await speechClient.generateSpeech(request: speechRequest)
            }
        )

        try await writeAudioFile(
            speechResult: speechResult,
            projectID: projectID,
            episodeID: episodeID,
            fileName: fileName
        )

        project = try await markAudioReady(project: project, episode: episode, fileName: fileName)
        continuation.yield(project)
    }

    private func markAudioGenerating(
        project: PodcastProject,
        episode: inout Episode,
        fileName: String
    ) async throws -> PodcastProject {
        episode.audio = EpisodeAudio(status: .generating, fileName: fileName, generatedAt: nil, errorMessage: nil)
        var updated = upsert(episode: episode, into: project)
        updated.lastUpdatedAt = Date()
        try await projectStore.save(updated)
        return updated
    }

    private func writeAudioFile(
        speechResult: GeminiSpeechResult,
        projectID: UUID,
        episodeID: UUID,
        fileName: String
    ) async throws {
        let format = WAVFormat(
            sampleRateHz: speechResult.sampleRateHz,
            channels: speechResult.channels,
            bitsPerSample: speechResult.bitsPerSample
        )
        _ = try await audioStore.writeWAV(
            pcmData: speechResult.pcmData,
            projectID: projectID,
            episodeID: episodeID,
            fileName: fileName,
            format: format
        )
    }

    private func markAudioReady(
        project: PodcastProject,
        episode: Episode,
        fileName: String
    ) async throws -> PodcastProject {
        var updatedEpisode = episode
        updatedEpisode.audio = EpisodeAudio(status: .ready, fileName: fileName, generatedAt: Date(), errorMessage: nil)

        var updated = upsert(episode: updatedEpisode, into: project)
        updated.lastUpdatedAt = Date()
        try await projectStore.save(updated)
        return updated
    }

    private func persistFailure(
        projectID: UUID,
        episodeID: UUID,
        error: Error,
        continuation: AsyncThrowingStream<PodcastProject, Error>.Continuation
    ) async {
        do {
            var project = try await projectStore.load(id: projectID)
            guard var episode = project.episodes.first(where: { $0.id == episodeID }) else { return }

            let fileName = episode.audio?.fileName ?? "\(episodeID.uuidString).wav"
            episode.audio = EpisodeAudio(
                status: .failed,
                fileName: fileName,
                generatedAt: nil,
                errorMessage: error.localizedDescription
            )

            project = upsert(episode: episode, into: project)
            project.lastUpdatedAt = Date()
            try await projectStore.save(project)
            continuation.yield(project)
        } catch {
            // Ignore persistence failures while handling a failure.
        }
    }
}

private func upsert(episode: Episode, into project: PodcastProject) -> PodcastProject {
    var copy = project
    if let index = copy.episodes.firstIndex(where: { $0.id == episode.id }) {
        copy.episodes[index] = episode
    } else {
        copy.episodes.append(episode)
    }
    return copy
}

private func isRetryableSpeechError(_ error: Error) -> Bool {
    if error is URLError {
        return true
    }

    if let speechError = error as? GeminiSpeechClientError {
        if case let .httpError(statusCode, _) = speechError {
            return statusCode == 429 || (500..<600).contains(statusCode)
        }
        return false
    }

    return false
}

enum EpisodeAudioGenerationError: LocalizedError, Sendable {
    case episodeNotFound
    case episodeNotReady
    case projectNotReady

    var errorDescription: String? {
        switch self {
        case .episodeNotFound:
            return "Episode not found."
        case .episodeNotReady:
            return "Episode audio can be generated after the transcript is complete."
        case .projectNotReady:
            return "Episode audio can be generated after the podcast is complete."
        }
    }
}

private enum SpeechScriptBuilder {
    static func makeScript(hostAName: String, hostBName: String, lines: [DialogueLine]) -> String {
        let prelude = [
            "You are generating audio for a two-host podcast episode.",
            "Do not speak speaker labels out loud; they are only cues for which voice to use.",
            "Read naturally with conversational pacing.",
            "",
            "Speakers:",
            "- \(hostAName)",
            "- \(hostBName)",
            "",
            "Script:"
        ].joined(separator: "\n")

        let body = lines.map { line in
            let speaker = line.speaker == .hostA ? hostAName : hostBName
            return "\(speaker): \(line.text)"
        }.joined(separator: "\n")

        return "\(prelude)\n\(body)"
    }
}

private extension Optional where Wrapped == String {
    var trimmedNonEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
