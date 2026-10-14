import SwiftUI

public struct GeneralSettingsView: View {
    @ObservedObject public var viewModel: SettingsViewModel
    @ObservedObject private var connection = ConnectionManager.shared
    
    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Appearance Theme Card
            LiquidGlassCard(
                icon: "circle.lefthalf.filled",
                title: "Appearance",
                subtitle: "Customize interface theme and palette",
                tint: nil,
                headerTrailing: {
                    Button {
                        viewModel.selectedTheme = "system"
                        connection.applyTheme("system")
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "circle.lefthalf.filled")
                            Text("Auto")
                        }
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    }
                    .glassButtonStyle()
                }
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Theme Mode", selection: $viewModel.selectedTheme) {
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                        Text("Navy").tag("warm_navy")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.selectedTheme) { _, newTheme in
                        connection.applyTheme(newTheme)
                    }
                    
                    Text("Auto matches your system appearance. Warm Navy activates our custom midnight indigo glass palette.")
                        .font(.caption2)
                        .foregroundColor(Color.themeSecondaryText)
                }
            }
            
            // Advanced Chat Options Card
            LiquidGlassCard(
                icon: "sparkles",
                title: "Advanced Chat Options",
                subtitle: "On-device intelligence & search tools",
                tint: nil
            ) {
                VStack(spacing: 12) {
                    Toggle(isOn: connection.$isScreenshotsEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Conversation Previews")
                                .font(.subheadline)
                                .foregroundColor(Color.themeText)
                            Text("Generate rich dynamic snapshots for conversations")
                                .font(.caption2)
                                .foregroundColor(Color.themeSecondaryText)
                        }
                    }
                    
                    Divider()
                    
                    Toggle(isOn: connection.$isWebSearchEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Web Search Tool")
                                .font(.subheadline)
                                .foregroundColor(Color.themeText)
                            Text("Allow models to fetch real-time facts via DuckDuckGo")
                                .font(.caption2)
                                .foregroundColor(Color.themeSecondaryText)
                        }
                    }
                }
            }
            
            // App Diagnostics and System
            LiquidGlassCard(
                icon: "info.circle",
                title: "App Diagnostics & System",
                subtitle: "Local-First private architecture",
                tint: nil
            ) {
                VStack(spacing: 10) {
                    diagnosticRow(title: "Target Device", value: UIDevice.current.name)
                    Divider()
                    diagnosticRow(title: "Target OS", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                    Divider()
                    diagnosticRow(
                        title: "HomeAI Version",
                        value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
                    )
                    Divider()
                    diagnosticRow(title: "Engine Mode", value: "Local-First & Private")
                }
            }
        }
    }
    
    @ViewBuilder
    private func diagnosticRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.footnote)
                .foregroundColor(Color.themeSecondaryText)
            Spacer()
            Text(value)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(Color.themeText)
        }
    }
}
