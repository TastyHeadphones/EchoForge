import SwiftUI
import EchoForgeGemini

struct GeminiModelBrowserSheet: View {
    @Binding var selectedModel: String
    let models: [GeminiModelDescriptor]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeminiModelPickerView(selectedModel: $selectedModel, models: models)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 520, minHeight: 600)
#endif
    }
}
