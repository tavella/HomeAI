import SwiftUI
import SwiftData

public struct ServerConnectionSettingsView: View {
    @ObservedObject public var viewModel: SettingsViewModel
    @ObservedObject private var connection = ConnectionManager.shared
    
    public var isInitialSetup: Bool
    @Binding public var showingSavePresetAlert: Bool
    @Binding public var showingAddPreset: Bool
    public let onSaveAsPresetTapped: () -> Void
    
    public enum ConnectionField: Hashable {
        case hostname
        case port
        case apiKey
    }
    @FocusState private var focusedField: ConnectionField?
    @State private var isApiKeyVisible: Bool = false
    
    public init(
        viewModel: SettingsViewModel,
        isInitialSetup: Bool = false,
        showingSavePresetAlert: Binding<Bool>,
        showingAddPreset: Binding<Bool>,
        onSaveAsPresetTapped: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.isInitialSetup = isInitialSetup
        self._showingSavePresetAlert = showingSavePresetAlert
        self._showingAddPreset = showingAddPreset
        self.onSaveAsPresetTapped = onSaveAsPresetTapped
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Initial Welcome Banner
            if isInitialSetup || !connection.hasPreviousConnection {
                LiquidGlassCard(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Welcome to HomeAI",
                    subtitle: "Configure your local oMLX server to start chatting",
                    tint: .blue
                ) {
                    Text("Please configure your local oMLX or Tailscale server connection details below. Once connected, your models will automatically sync.")
                        .font(.footnote)
                        .foregroundColor(Color.themeSecondaryText)
                        .lineSpacing(2)
                }
            }
            
            // Connection Status & Live Diagnostics Card
            LiquidGlassCard(
                icon: "waveform.path.ecg",
                title: "Connection Status",
                subtitle: connection.isConnected ? "Online & Ready" : "Disconnected",
                tint: nil,
                headerTrailing: {
                    if viewModel.isFetchingModels || connection.isTestingConnection {
                        Button {
                            viewModel.cancelTestConnection()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Cancel")
                            }
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                        }
                        .glassButtonStyle(tint: .red)
                    } else {
                        Button {
                            viewModel.startTestConnection()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("Test Connection")
                            }
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        }
                        .glassButtonStyle(tint: .blue)
                    }
                }
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        StatusBadgeView(
                            isConnected: connection.isConnected,
                            isTesting: viewModel.isFetchingModels || connection.isTestingConnection
                        )
                        
                        if let status = viewModel.statusMessage {
                            Text(status)
                                .font(.caption)
                                .foregroundColor(
                                    status == "Connection test cancelled."
                                        ? .orange
                                        : (viewModel.isError ? .red : .green)
                                )
                                .lineLimit(2)
                        }
                        
                        Spacer()
                    }
                    
                    // Base Endpoint Indicator
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Base Endpoint")
                            .font(.caption2)
                            .foregroundColor(Color.themeSecondaryText)
                        
                        Text("http://\(viewModel.hostNameInput.isEmpty ? "100.x.y.z" : viewModel.hostNameInput):\(viewModel.portInput)/v1")
                            .font(.system(.footnote, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundColor(Color.themeText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.themeSurfaceVariant)
                            )
                    }
                    
                    if !viewModel.hostNameInput.isEmpty && !ConnectionManager.isPrivateOrLocalAddress(viewModel.hostNameInput) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.footnote)
                            Text("Cleartext HTTP Warning: This host does not appear to be a local LAN, loopback, or Tailscale address. Transmitting unencrypted traffic over public networks exposes your API key and prompt payloads.")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.12))
                        )
                    }
                }
            }
            
            // Server Connection Details Card
            LiquidGlassCard(
                icon: "server.rack",
                title: "Server Connection Details",
                subtitle: "Hostname, Port, and Authentication",
                headerTrailing: {
                    Button {
                        onSaveAsPresetTapped()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.app.fill")
                            Text("Save Preset")
                        }
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.hostNameInput.isEmpty)
                }
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    // Hostname Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hostname or Tailscale IP")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.themeSecondaryText)
                        
                        TextField("100.x.y.z or macbook.local", text: $viewModel.hostNameInput)
                            .focused($focusedField, equals: .hostname)
                            .foregroundColor(Color.themeText)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.themeSurfaceVariant)
                            )
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .port
                            }
                    }
                    
                    // Port Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Port")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.themeSecondaryText)
                        
                        TextField("8000", text: $viewModel.portInput)
                            .focused($focusedField, equals: .port)
                            .foregroundColor(Color.themeText)
                            .keyboardType(.numberPad)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.themeSurfaceVariant)
                            )
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .apiKey
                            }
                    }
                    
                    // API Key Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Key (Required if oMLX Auth Enabled)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Color.themeSecondaryText)
                        
                        HStack(spacing: 8) {
                            if isApiKeyVisible {
                                TextField("omlx-key", text: $viewModel.apiKeyInput)
                                    .focused($focusedField, equals: .apiKey)
                                    .foregroundColor(Color.themeText)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        focusedField = nil
                                        viewModel.saveSettings()
                                    }
                            } else {
                                SecureField("omlx-key", text: $viewModel.apiKeyInput)
                                    .focused($focusedField, equals: .apiKey)
                                    .foregroundColor(Color.themeText)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        focusedField = nil
                                        viewModel.saveSettings()
                                    }
                            }
                            
                            Button {
                                isApiKeyVisible.toggle()
                            } label: {
                                Image(systemName: isApiKeyVisible ? "eye.slash" : "eye")
                                    .foregroundColor(Color.themeSecondaryText)
                                    .padding(4)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isApiKeyVisible ? "Hide API key" : "Show API key")
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.themeSurfaceVariant)
                        )
                    }
                }
            }
            
            // Saved Connection Presets Card
            LiquidGlassCard(
                icon: "externaldrive.connected.to.line.below",
                title: "Saved Presets",
                subtitle: "Fast switching between VPN, local, or cloud hosts",
                headerTrailing: {
                    Button {
                        showingAddPreset = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Add")
                        }
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    }
                    .glassButtonStyle()
                }
            ) {
                HostPresetsView(showingAddPreset: $showingAddPreset) { preset in
                    viewModel.applyPreset(preset)
                }
            }
        }
    }
}
