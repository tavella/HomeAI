import SwiftUI

public struct ModelSelectorView: View {
    @Binding public var selectedModelID: String
    public let availableModels: [HomeAIModel]
    public let onFetchModels: () -> Void
    public let isFetching: Bool
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Model Identifier")
                    .font(.headline)
                Spacer()
                Button(action: onFetchModels) {
                    HStack(spacing: 4) {
                        if isFetching {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Fetch Models")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                }
                .disabled(isFetching)
            }
            
            if availableModels.isEmpty {
                TextField("e.g. llama-3.2- vision, qwen2.5", text: $selectedModelID)
                    .textFieldStyle(.roundedBorder)
            } else {
                Picker("Active Model", selection: $selectedModelID) {
                    ForEach(availableModels) { model in
                        Text(model.id).tag(model.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
