import Foundation
import EchoForgeGemini
import EchoForgePersistence
import EchoForgeExport

public struct AppDependencies: Sendable {
    public var geminiClient: any GeminiClient
    public var geminiConfigurationStore: any GeminiConfigurationStoring
    public var projectStore: any ProjectStoring
    public var exporter: any PodcastExporting

    public init(
        geminiClient: any GeminiClient,
        geminiConfigurationStore: any GeminiConfigurationStoring,
        projectStore: any ProjectStoring,
        exporter: any PodcastExporting
    ) {
        self.geminiClient = geminiClient
        self.geminiConfigurationStore = geminiConfigurationStore
        self.projectStore = projectStore
        self.exporter = exporter
    }

    public static func live() -> AppDependencies {
        let projectStore = ProjectStore()
        let exporter = PodcastZipExporter()

        let geminiConfigurationStore = GeminiConfigurationStore()
        let geminiClient: any GeminiClient = InAppGeminiClient(configurationStore: geminiConfigurationStore)

        return AppDependencies(
            geminiClient: geminiClient,
            geminiConfigurationStore: geminiConfigurationStore,
            projectStore: projectStore,
            exporter: exporter
        )
    }
}
