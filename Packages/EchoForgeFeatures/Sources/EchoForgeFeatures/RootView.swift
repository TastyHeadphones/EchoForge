import SwiftUI
import EchoForgeCore

public struct RootView: View {
    private let dependencies: AppDependencies

    @StateObject private var viewModel: GenerateViewModel
    @State private var isShowingSettings: Bool = false

    public init(dependencies: AppDependencies = .live()) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: GenerateViewModel(dependencies: dependencies))
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let project = viewModel.project {
                    ProjectView(project: project, viewModel: viewModel)
                } else {
                    GenerateView(viewModel: viewModel) {
                        isShowingSettings = true
                    }
                }
            }
        }
        .task {
            viewModel.restoreMostRecentProject()
            viewModel.refreshGeminiConfigurationStatus()

            let apiKey = try? await dependencies.geminiConfigurationStore.readAPIKey()
            if apiKey?.isEmpty != false {
                isShowingSettings = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Settings") {
                    isShowingSettings = true
                }
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            GeminiSettingsView(configurationStore: dependencies.geminiConfigurationStore)
        }
        .onChange(of: isShowingSettings) { _, showing in
            if !showing {
                viewModel.refreshGeminiConfigurationStatus()
            }
        }
        .alert("Error", isPresented: isPresentingError) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var isPresentingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { presenting in
                if !presenting {
                    viewModel.errorMessage = nil
                }
            }
        )
    }
}
