import SwiftUI
import UniformTypeIdentifiers

public struct RootView: View {
    private let dependencies: AppDependencies

    @StateObject private var viewModel: LibraryViewModel

    public init(dependencies: AppDependencies = .live()) {
        self.dependencies = dependencies
        _viewModel = StateObject(wrappedValue: LibraryViewModel(dependencies: dependencies))
    }

    public var body: some View {
        LibraryView(viewModel: viewModel)
        .task {
            await viewModel.bootstrap()
        }
        .sheet(isPresented: $viewModel.isShowingSettings) {
            GeminiSettingsView(configurationStore: dependencies.geminiConfigurationStore)
        }
        .onChange(of: viewModel.isShowingSettings) { _, showing in
            if !showing {
                Task { await viewModel.refreshGeminiConfigurationStatus() }
            }
        }
        .fileExporter(
            isPresented: $viewModel.isShowingExportPicker,
            document: viewModel.exportDocument ?? ZipFileDocument(data: Data()),
            contentType: .zip,
            defaultFilename: viewModel.exportDefaultFilename
        ) { result in
            if case let .failure(error) = result {
                viewModel.errorMessage = error.localizedDescription
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
