import Foundation
import EchoForgeGemini
import EchoForgePersistence
import EchoForgeExport

public struct AppDependencies: Sendable {
    public var geminiClient: any GeminiClient
    public var geminiSpeechClient: any GeminiSpeechGenerating
    public var geminiConfigurationStore: any GeminiConfigurationStoring
    public var projectStore: any ProjectStoring
    public var episodeAudioStore: any EpisodeAudioStoring
    public var exporter: any PodcastExporting

    public init(
        geminiClient: any GeminiClient,
        geminiSpeechClient: any GeminiSpeechGenerating,
        geminiConfigurationStore: any GeminiConfigurationStoring,
        projectStore: any ProjectStoring,
        episodeAudioStore: any EpisodeAudioStoring,
        exporter: any PodcastExporting
    ) {
        self.geminiClient = geminiClient
        self.geminiSpeechClient = geminiSpeechClient
        self.geminiConfigurationStore = geminiConfigurationStore
        self.projectStore = projectStore
        self.episodeAudioStore = episodeAudioStore
        self.exporter = exporter
    }

    public static func live() -> AppDependencies {
        let projectStore = ProjectStore()
        let exporter = PodcastZipExporter()
        let episodeAudioStore = EpisodeAudioStore()

        let geminiConfigurationStore = GeminiConfigurationStore()
        let geminiClient: any GeminiClient = InAppGeminiClient(configurationStore: geminiConfigurationStore)
        let geminiSpeechClient: any GeminiSpeechGenerating = InAppGeminiSpeechClient(
            configurationStore: geminiConfigurationStore
        )

        return AppDependencies(
            geminiClient: geminiClient,
            geminiSpeechClient: geminiSpeechClient,
            geminiConfigurationStore: geminiConfigurationStore,
            projectStore: projectStore,
            episodeAudioStore: episodeAudioStore,
            exporter: exporter
        )
    }
}
