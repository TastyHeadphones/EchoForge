import Foundation
import SwiftUI
import EchoForgeCore
import EchoForgeGemini
import EchoForgePersistence
import EchoForgeExport

@MainActor
public final class GenerateViewModel: ObservableObject {
    @Published public var topic: String = ""
    @Published public var episodeCount: Int = 3

    @Published public private(set) var project: PodcastProject?
    @Published public private(set) var isGenerating: Bool = false
    @Published public private(set) var isGeminiConfigured: Bool = false

    @Published public private(set) var isExporting: Bool = false
    @Published public var isShowingExportPicker: Bool = false
    @Published public var exportDefaultFilename: String = "EchoForge.zip"
    @Published public var exportDocument: ZipFileDocument?

    @Published public var errorMessage: String?

    private let geminiConfigurationStore: any GeminiConfigurationStoring
    private let projectStore: any ProjectStoring
    private let exporter: any PodcastExporting
    private let generationService: PodcastGenerationService
    private var generationTask: Task<Void, Never>?

    public init(dependencies: AppDependencies) {
        self.geminiConfigurationStore = dependencies.geminiConfigurationStore
        self.projectStore = dependencies.projectStore
        self.exporter = dependencies.exporter
        self.generationService = PodcastGenerationService(
            geminiClient: dependencies.geminiClient,
            projectStore: dependencies.projectStore
        )
    }

    public func refreshGeminiConfigurationStatus() {
        Task { [geminiConfigurationStore] in
            let apiKey = try? await geminiConfigurationStore.readAPIKey()
            self.isGeminiConfigured = apiKey?.isEmpty == false
        }
    }

    public func restoreMostRecentProject() {
        Task {
            do {
                let projects = try await projectStore.loadAll()
                await MainActor.run {
                    self.project = projects.first
                }
            } catch {
                // Non-fatal.
            }
        }
    }

    public func startGeneration() {
        let cleanedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTopic.isEmpty else {
            errorMessage = "Please enter a topic."
            return
        }

        guard isGeminiConfigured else {
            errorMessage = "Gemini is not configured. Open Settings to add your API key."
            return
        }

        let clampedEpisodeCount = max(1, min(episodeCount, 10))

        generationTask?.cancel()
        errorMessage = nil

        let hostA = PodcastHost(id: .hostA, displayName: "Ava", roleDescription: "Curious and upbeat")
        let hostB = PodcastHost(id: .hostB, displayName: "Noah", roleDescription: "Skeptical and precise")

        var newProject = PodcastProject(
            topic: cleanedTopic,
            episodeCountRequested: clampedEpisodeCount,
            hosts: [hostA, hostB],
            status: .generating
        )

        newProject.lastUpdatedAt = Date()

        project = newProject
        isGenerating = true

        let request = PodcastGenerationRequest(
            topic: cleanedTopic,
            episodeCount: clampedEpisodeCount,
            hostAName: hostA.displayName,
            hostBName: hostB.displayName
        )

        startGenerationTask(initialProject: newProject, request: request)
    }

    private func startGenerationTask(initialProject: PodcastProject, request: PodcastGenerationRequest) {
        generationTask = Task { @MainActor [generationService] in
            defer { self.isGenerating = false }

            do {
                let stream = await generationService.streamProject(initialProject: initialProject, request: request)
                for try await updated in stream {
                    self.project = updated
                }
            } catch is CancellationError {
                // Silent cancel.
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    public func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
    }

    public func startNewProject() {
        generationTask?.cancel()
        generationTask = nil

        project = nil
        isGenerating = false
        isExporting = false
        isShowingExportPicker = false
        exportDocument = nil
        errorMessage = nil

        topic = ""
        episodeCount = 3
    }

    public func exportZip() {
        guard let project else {
            errorMessage = "Nothing to export."
            return
        }

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

    private func sanitizedFilename(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-_ "))
        let cleaned = String(input.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
        let condensed = cleaned
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return condensed.isEmpty ? "EchoForge" : condensed
    }
}
