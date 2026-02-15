import SwiftUI
import EchoForgeGemini

struct GeminiModelPickerView: View {
    @Binding var selectedModel: String
    @Binding var models: [GeminiModelDescriptor]
    @Binding var isRefreshing: Bool
    let refresh: @Sendable () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""

    var body: some View {
        List(filteredModels) { model in
            Button {
                selectedModel = model.id
                dismiss()
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.id)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let displayName = model.displayName, !displayName.isEmpty {
                            Text(displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)

                    if model.id == selectedModel {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Choose Model")
        .searchable(text: $query, placement: .toolbar, prompt: "Search models")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await refresh() }
                } label: {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Text("Refresh")
                    }
                }
                .disabled(isRefreshing)
            }
        }
    }

    private var filteredModels: [GeminiModelDescriptor] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return models
        }

        return models.filter { model in
            model.id.localizedCaseInsensitiveContains(trimmed)
                || (model.displayName?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }
}
