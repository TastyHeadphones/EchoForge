import Foundation
import SwiftUI
import EchoForgeCore
import EchoForgeExport
import EchoForgeGemini
import EchoForgePersistence

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var projects: [PodcastProject] = []
    @Published private(set) var isGeminiConfigured: Bool = false

    @Published var isShowingSettings: Bool = false
    @Published var isShowingNewPodcast: Bool = false

    @Published private(set) var isExporting: Bool = false
    @Published var isShowingExportPicker: Bool = false
    @Published var exportDefaultFilename: String = "EchoForge.zip"
    @Published var exportDocument: ZipFileDocument?

    @Published var errorMessage: String?

    private let geminiConfigurationStore: any GeminiConfigurationStoring
    private let projectStore: any ProjectStoring
    private let exporter: any PodcastExporting
    private let episodeAudioStore: any EpisodeAudioStoring

    private let generationBackend: PodcastGenerationBackend
    private let audioBackend: EpisodeAudioGenerationBackend

    private var textUpdatesTask: Task<Void, Never>?
    private var audioUpdatesTask: Task<Void, Never>?

    init(dependencies: AppDependencies = .live()) {
        self.geminiConfigurationStore = dependencies.geminiConfigurationStore
        self.projectStore = dependencies.projectStore
        self.exporter = dependencies.exporter
        self.episodeAudioStore = dependencies.episodeAudioStore

        let generationService = PodcastGenerationService(
            geminiClient: dependencies.geminiClient,
            projectStore: dependencies.projectStore
        )
        self.generationBackend = PodcastGenerationBackend(generationService: generationService)

        let audioService = EpisodeAudioGenerationService(
            speechClient: dependencies.geminiSpeechClient,
            projectStore: dependencies.projectStore,
            audioStore: dependencies.episodeAudioStore
        )
        self.audioBackend = EpisodeAudioGenerationBackend(service: audioService)

        subscribeToUpdates()
    }

    deinit {
        textUpdatesTask?.cancel()
        audioUpdatesTask?.cancel()
    }

    func bootstrap() async {
        await refreshGeminiConfigurationStatus()
        await loadProjects()

        if !isGeminiConfigured {
            isShowingSettings = true
        }
    }

    func refreshGeminiConfigurationStatus() async {
        let apiKey = try? await geminiConfigurationStore.readAPIKey()
        isGeminiConfigured = apiKey?.isEmpty == false
    }

    func loadProjects() async {
        do {
            let loaded = try await projectStore.loadAll()
            projects = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func project(id: UUID) -> PodcastProject? {
        projects.first(where: { $0.id == id })
    }

    func createPodcast(title: String, topic: String, episodeCount: Int) async -> UUID? {
        let cleanedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTopic.isEmpty else {
            errorMessage = "Please enter a topic."
            return nil
        }

        guard isGeminiConfigured else {
            errorMessage = "Gemini is not configured. Open Settings to add your API key."
            isShowingSettings = true
            return nil
        }

        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedEpisodeCount = max(1, episodeCount)

        let hostA = PodcastHost(id: .hostA, displayName: "Ava", roleDescription: "Curious and upbeat")
        let hostB = PodcastHost(id: .hostB, displayName: "Noah", roleDescription: "Skeptical and precise")

        var newProject = PodcastProject(
            topic: cleanedTopic,
            episodeCountRequested: requestedEpisodeCount,
            title: cleanedTitle.isEmpty ? nil : cleanedTitle,
            hosts: [hostA, hostB],
            status: .generating
        )
        newProject.lastUpdatedAt = Date()

        do {
            try await projectStore.save(newProject)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }

        upsertProject(newProject)

        let request = PodcastGenerationRequest(
            projectTitle: newProject.title,
            topic: cleanedTopic,
            episodeCount: requestedEpisodeCount,
            hostAName: hostA.displayName,
            hostBName: hostB.displayName
        )

        await generationBackend.startGeneration(initialProject: newProject, request: request)
        return newProject.id
    }

    func cancelGeneration(for projectID: UUID) async {
        await generationBackend.cancel(projectID: projectID)

        guard var project = project(id: projectID) else { return }
        project.status = .failed
        project.errorMessage = "Generation cancelled."
        project.lastUpdatedAt = Date()

        project.episodes = project.episodes.map { episode in
            var updated = episode
            if updated.status == .generating {
                updated.status = .failed
            }
            return updated
        }

        try? await projectStore.save(project)
        upsertProject(project)
    }

    func retryGeneration(projectID: UUID) {
        Task { [weak self] in
            guard let self else { return }
            await self.retryGenerationImpl(projectID: projectID)
        }
    }

    private func retryGenerationImpl(projectID: UUID) async {
        guard isGeminiConfigured else {
            errorMessage = "Gemini is not configured. Open Settings to add your API key."
            isShowingSettings = true
            return
        }

        await generationBackend.cancel(projectID: projectID)

        guard var project = project(id: projectID) else { return }

        project.status = .generating
        project.errorMessage = nil
        project.episodes = []
        project.lastUpdatedAt = Date()

        do {
            try await projectStore.save(project)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        upsertProject(project)

        let hostAName = project.hosts.first(where: { $0.id == .hostA })?.displayName ?? "Host A"
        let hostBName = project.hosts.first(where: { $0.id == .hostB })?.displayName ?? "Host B"

        let request = PodcastGenerationRequest(
            projectTitle: project.title,
            topic: project.topic,
            episodeCount: max(1, project.episodeCountRequested),
            hostAName: hostAName,
            hostBName: hostBName
        )

        await generationBackend.startGeneration(initialProject: project, request: request)
    }

    func deleteProject(id: UUID) async {
        await generationBackend.cancel(projectID: id)
        await audioBackend.cancelAll(projectID: id)

        do {
            try await projectStore.delete(id: id)
            try? await episodeAudioStore.deleteAllAudio(projectID: id)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        projects.removeAll(where: { $0.id == id })
    }

    func generateAudio(projectID: UUID, episodeID: Episode.ID) {
        Task { [audioBackend] in
            await audioBackend.start(projectID: projectID, episodeID: episodeID)
        }
    }

    func audioFileURL(projectID: UUID, episode: Episode) async -> URL? {
        do {
            return try await episodeAudioStore.fileURL(
                projectID: projectID,
                episodeID: episode.id,
                fileName: episode.audio?.fileName
            )
        } catch {
            return nil
        }
    }

    func exportProject(id: UUID) {
        guard let project = project(id: id) else {
            errorMessage = "Nothing to export."
            return
        }

        export(project: project)
    }

    func export(project: PodcastProject) {
        isExporting = true
        errorMessage = nil

        Task { [exporter] in
            do {
                let zipURL = try await exporter.export(project: project)
                let data = try Data(contentsOf: zipURL)

                let filename = sanitizedFilename(
                    (project.title?.isEmpty == false ? project.title : project.topic) ?? "EchoForge"
                )

                await MainActor.run {
                    self.exportDocument = ZipFileDocument(data: data)
                    self.exportDefaultFilename = "\(filename).zip"
                    self.isExporting = false
                    self.isShowingExportPicker = true
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func subscribeToUpdates() {
        textUpdatesTask?.cancel()
        textUpdatesTask = Task { @MainActor [generationBackend] in
            for await updated in generationBackend.updates {
                self.upsertProject(updated)
            }
        }

        audioUpdatesTask?.cancel()
        audioUpdatesTask = Task { @MainActor [audioBackend] in
            for await updated in audioBackend.updates {
                self.upsertProject(updated)
            }
        }
    }

    private func upsertProject(_ updated: PodcastProject) {
        if let index = projects.firstIndex(where: { $0.id == updated.id }) {
            projects[index] = updated
        } else {
            projects.insert(updated, at: 0)
            projects.sort(by: { $0.createdAt > $1.createdAt })
        }

        maybeAutoGenerateAudio(for: updated)
    }
}

private extension LibraryViewModel {
    func maybeAutoGenerateAudio(for project: PodcastProject) {
        guard isGeminiConfigured else { return }
        guard project.status == .complete else { return }

        let pendingEpisodes = project.episodes.filter { episode in
            episode.status == .complete && episode.audioStatus == .none && !episode.lines.isEmpty
        }
        guard !pendingEpisodes.isEmpty else { return }

        Task { [audioBackend] in
            for episode in pendingEpisodes {
                await audioBackend.start(projectID: project.id, episodeID: episode.id)
            }
        }
    }

    func sanitizedFilename(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-_ "))
        let cleaned = String(input.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
        let condensed = cleaned
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return condensed.isEmpty ? "EchoForge" : condensed
    }
}
