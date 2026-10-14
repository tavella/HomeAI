import SwiftUI

public struct ModelManagementSettingsView: View {
    @ObservedObject public var viewModel: SettingsViewModel
    @ObservedObject private var connection = ConnectionManager.shared
    
    public let onConfigureModel: (HomeAIModel) -> Void
    public let onDeleteModel: (String) -> Void
    
    @State private var searchText: String = ""
    
    public init(
        viewModel: SettingsViewModel,
        onConfigureModel: @escaping (HomeAIModel) -> Void,
        onDeleteModel: @escaping (String) -> Void
    ) {
        self.viewModel = viewModel
        self.onConfigureModel = onConfigureModel
        self.onDeleteModel = onDeleteModel
    }
    
    private var filteredModels: [HomeAIModel] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return connection.availableModels
        }
        let query = searchText.lowercased()
        return connection.availableModels.filter {
            $0.effectiveDisplayName.lowercased().contains(query) ||
            $0.id.lowercased().contains(query)
        }
    }
    
    private var loadedCount: Int {
        connection.availableModels.filter { $0.isLoaded }.count
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Model Management Header Card
            LiquidGlassCard(
                icon: "cpu",
                title: "oMLX Models",
                subtitle: "\(connection.availableModels.count) discovered • \(loadedCount) in memory",
                tint: nil,
                headerTrailing: {
                    Button {
                        Task {
                            await viewModel.refreshModels()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            if viewModel.isFetchingModels {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Refresh")
                        }
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    }
                    .glassButtonStyle()
                    .disabled(viewModel.isFetchingModels || viewModel.isModelActionLoading)
                }
            ) {
                VStack(spacing: 12) {
                    // Search bar if there are multiple models
                    if connection.availableModels.count > 3 {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color.themeSecondaryText)
                                .font(.caption)
                            
                            TextField("Search models...", text: $searchText)
                                .font(.subheadline)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Color.themeSecondaryText)
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(connection.appTheme == "warm_navy" ? Color.themeSurfaceVariant : Color(UIColor.tertiarySystemFill))
                        )
                    }
                    
                    if let error = viewModel.modelErrorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.12))
                        )
                    }
                    
                    if connection.availableModels.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "cube.transparent")
                                .font(.system(size: 36))
                                .foregroundColor(Color.themeSecondaryText.opacity(0.6))
                                .padding(.top, 8)
                            
                            Text("No models discovered yet.")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Color.themeText)
                            
                            Text("Verify that your oMLX host is online and connected, then tap Refresh Models.")
                                .font(.caption)
                                .foregroundColor(Color.themeSecondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                            
                            Button {
                                Task {
                                    await viewModel.refreshModels()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Discover Models")
                                }
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.blue))
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(filteredModels) { model in
                                modelRow(for: model)
                            }
                        }
                    }
                }
            }
        }
        .task {
            await connection.refreshModelStatuses()
        }
    }
    
    @ViewBuilder
    private func modelRow(for model: HomeAIModel) -> some View {
        HStack(spacing: 10) {
            // Model Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(model.effectiveDisplayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.themeText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    if let alias = model.settings?.modelAlias, alias != model.id {
                        Text(model.id)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color.themeSecondaryText)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.themeBackground)
                            .cornerRadius(3)
                            .lineLimit(1)
                    }
                }
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(model.isLoaded ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 6, height: 6)
                    
                    Text(model.isLoaded ? "Loaded in VRAM" : "Available to Load")
                        .font(.caption2)
                        .foregroundColor(model.isLoaded ? .green : Color.themeSecondaryText)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onConfigureModel(model)
            }
            
            Spacer()
            
            // Configure Model Button
            Button {
                onConfigureModel(model)
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.blue)
                    .font(.system(size: 14))
            }
            .glassButtonStyle()
            .accessibilityLabel("Configure \(model.effectiveDisplayName)")
            
            // Load / Unload or Spinner
            if viewModel.loadingModelId == model.id {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 32, height: 32)
            } else {
                if model.isLoaded {
                    Button {
                        Task { await viewModel.unloadModel(model.id) }
                    } label: {
                        Image(systemName: "eject.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 13))
                    }
                    .glassButtonStyle(tint: .orange)
                    .disabled(viewModel.isModelActionLoading)
                    .accessibilityLabel("Unload \(model.effectiveDisplayName)")
                } else {
                    Button {
                        Task { await viewModel.loadModel(model.id) }
                    } label: {
                        Image(systemName: "opticaldisc")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                    }
                    .glassButtonStyle(tint: .blue)
                    .disabled(viewModel.isModelActionLoading)
                    .accessibilityLabel("Load \(model.effectiveDisplayName)")
                }
                
                // Delete button
                Button {
                    onDeleteModel(model.id)
                } label: {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 13))
                }
                .glassButtonStyle(tint: .red)
                .disabled(viewModel.isModelActionLoading)
                .accessibilityLabel("Delete \(model.effectiveDisplayName)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(connection.appTheme == "warm_navy" ? Color.themeSurfaceVariant : Color(UIColor.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 0.75)
                )
        )
    }
}
