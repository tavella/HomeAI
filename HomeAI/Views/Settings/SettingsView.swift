import SwiftUI
import SwiftData

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var connection = ConnectionManager.shared
    
    @State private var showingSavePresetAlert = false
    @State private var presetNameInput = ""
    @State private var showingAddPreset = false
    @State private var modelToDelete: String? = nil
    @State private var showingDeleteConfirm = false
    
    public var body: some View {
        NavigationStack {
            Form {
                // Section 1: Appearance
                Section {
                    Picker("Theme Mode", selection: $viewModel.selectedTheme) {
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                        Text("Navy").tag("warm_navy")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.selectedTheme) { _, newTheme in
                        connection.applyTheme(newTheme)
                    }
                } header: {
                    HStack {
                        Text("Appearance")
                        Spacer()
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
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.blue)
                    }
                    .textCase(nil)
                }
                .listRowBackground(connection.appTheme == "warm_navy" ? Color.themeSurface : nil)

                // Section 2: Server Connection Details
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hostname or Tailscale IP")
                            .font(.caption)
                            .foregroundColor(Color.themeSecondaryText)
                        TextField("100.x.y.z or macbook.local", text: $viewModel.hostNameInput)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Port")
                            .font(.caption)
                            .foregroundColor(Color.themeSecondaryText)
                        TextField("1234", text: $viewModel.portInput)
                            .keyboardType(.numberPad)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Key (Optional / Local Dummy)")
                            .font(.caption)
                            .foregroundColor(Color.themeSecondaryText)
                        SecureField("omlx-key", text: $viewModel.apiKeyInput)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Constructed Base Endpoint")
                            .font(.caption2)
                            .foregroundColor(Color.themeSecondaryText)
                        Text("http://\(viewModel.hostNameInput.isEmpty ? "100.x.y.z" : viewModel.hostNameInput):\(viewModel.portInput)/v1")
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                } header: {
                    HStack {
                        Text("Server Connection Details")
                        Spacer()
                        Button {
                            presetNameInput = ""
                            showingSavePresetAlert = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.app.fill")
                                Text("Save Preset")
                            }
                            .font(.footnote)
                            .fontWeight(.medium)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.blue)
                        .disabled(viewModel.hostNameInput.isEmpty)
                    }
                    .textCase(nil)
                }
                .listRowBackground(connection.appTheme == "warm_navy" ? Color.themeSurface : nil)

                // Section 3: Connection Status (Moved below Server Connection Details and above Presets)
                Section {
                    HStack(spacing: 8) {
                        StatusBadgeView(
                            isConnected: connection.isConnected,
                            isTesting: viewModel.isFetchingModels
                        )
                        
                        if let status = viewModel.statusMessage {
                            Text(status)
                                .font(.caption)
                                .foregroundColor(viewModel.isError ? .red : .green)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                } header: {
                    HStack {
                        Text("Connection Status")
                        Spacer()
                        Button {
                            Task {
                                await viewModel.testConnectionAndFetchModels()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if viewModel.isFetchingModels {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                }
                                Text("Test Connection")
                            }
                            .font(.footnote)
                            .fontWeight(.medium)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.blue)
                        .disabled(viewModel.isFetchingModels)
                    }
                    .textCase(nil)
                }
                .listRowBackground(connection.appTheme == "warm_navy" ? Color.themeSurface : nil)
                
                // Section 4: Presets List
                Section {
                    HostPresetsView(showingAddPreset: $showingAddPreset) { preset in
                        viewModel.applyPreset(preset)
                    }
                } header: {
                    HStack {
                        Text("Presets")
                        Spacer()
                        Button {
                            showingAddPreset = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Preset")
                            }
                            .font(.footnote)
                            .fontWeight(.medium)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.blue)
                    }
                    .textCase(nil)
                }
                .listRowBackground(connection.appTheme == "warm_navy" ? Color.themeSurface : nil)
                
                // Section 5: Model Management (Just lists active/available models, not selectable)
                Section {
                    if let errorMsg = viewModel.modelErrorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMsg)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    if connection.availableModels.isEmpty {
                        Text("No models discovered. Tap Refresh Models or verify connection.")
                            .font(.caption)
                            .foregroundColor(Color.themeSecondaryText)
                    } else {
                        ForEach(connection.availableModels) { model in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.id)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color.themeText)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text(model.isLoaded ? "Loaded (Active)" : "Unloaded (Available)")
                                        .font(.caption2)
                                        .foregroundColor(model.isLoaded ? .green : Color.themeSecondaryText)
                                }
                                
                                Spacer()
                                
                                if viewModel.loadingModelId == model.id {
                                    ProgressView().controlSize(.small)
                                } else {
                                    if model.isLoaded {
                                        Button {
                                            Task { await viewModel.unloadModel(model.id) }
                                        } label: {
                                            Image(systemName: "eject.fill")
                                                .foregroundColor(.orange)
                                                .font(.system(size: 14))
                                        }
                                        .buttonStyle(.borderless)
                                        .disabled(viewModel.isModelActionLoading)
                                    } else {
                                        Button {
                                            Task { await viewModel.loadModel(model.id) }
                                        } label: {
                                            Image(systemName: "opticaldisc")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 14))
                                        }
                                        .buttonStyle(.borderless)
                                        .disabled(viewModel.isModelActionLoading)
                                    }
                                    
                                    Button {
                                        modelToDelete = model.id
                                        showingDeleteConfirm = true
                                    } label: {
                                        Image(systemName: "trash.fill")
                                            .foregroundColor(.red)
                                            .font(.system(size: 14))
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(viewModel.isModelActionLoading)
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Model Management")
                        Spacer()
                        Button {
                            Task {
                                await viewModel.refreshModels()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if viewModel.isFetchingModels {
                                    ProgressView().controlSize(.mini)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text("Refresh")
                            }
                            .font(.footnote)
                            .fontWeight(.medium)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.blue)
                        .disabled(viewModel.isFetchingModels || viewModel.isModelActionLoading)
                    }
                    .textCase(nil)
                }
                .listRowBackground(connection.appTheme == "warm_navy" ? Color.themeSurface : nil)
                
                // Section 6: System Prompt
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Global Context")
                            .font(.caption)
                            .foregroundColor(Color.themeSecondaryText)
                        TextEditor(text: connection.$globalSystemPrompt)
                            .frame(height: 100)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                    }
                } header: {
                    HStack {
                        Text("System Prompt")
                        Spacer()
                        Button {
                            connection.globalSystemPrompt = "You are HomeAI, a highly secure, private, local-first AI assistant running entirely on the user's local hardware. Your purpose is to assist the user with their queries, analysis, coding, and general tasks while maintaining absolute privacy and confidentiality. Do not mention external cloud APIs or online models unless asked. Focus on precise, helpful, and direct responses."
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward.circle")
                                Text("Reset to Default")
                            }
                            .font(.footnote)
                            .fontWeight(.medium)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.blue)
                    }
                    .textCase(nil)
                }
                .listRowBackground(connection.appTheme == "warm_navy" ? Color.themeSurface : nil)
                
                // Section 7: Advanced Chat Options (Moved below System Prompt)
                Section("Advanced Chat Options") {
                    Toggle("Show Conversation Previews", isOn: connection.$isScreenshotsEnabled)
                    Toggle("Enable Web Search Tool", isOn: connection.$isWebSearchEnabled)
                }
                .listRowBackground(connection.appTheme == "warm_navy" ? Color.themeSurface : nil)
                
                // Section 8: Diagnostics & System
                Section("App Diagnostics and System") {
                    HStack {
                        Text("Target Device")
                        Spacer()
                        Text(UIDevice.current.name)
                            .foregroundColor(Color.themeSecondaryText)
                    }
                    HStack {
                        Text("Target OS")
                        Spacer()
                        Text("\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                            .foregroundColor(Color.themeSecondaryText)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0") (Local-First)")
                            .foregroundColor(Color.themeSecondaryText)
                    }
                }
                .listRowBackground(connection.appTheme == "warm_navy" ? Color.themeSurface : nil)
            }
            .scrollContentBackground(connection.appTheme == "warm_navy" ? .hidden : .visible)
            .background(connection.appTheme == "warm_navy" ? Color.themeBackground : Color(UIColor.systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.saveSettings()
                        dismiss()
                    }
                }
            }
            .alert("New Connection Preset", isPresented: $showingSavePresetAlert) {
                TextField("Preset Name (e.g. Home Server)", text: $presetNameInput)
                Button("Save") {
                    saveAsPreset()
                }
                Button("Cancel", role: .cancel) {
                    presetNameInput = ""
                }
            } message: {
                Text("Enter a friendly name for this connection preset.")
            }
            .alert("Delete Model", isPresented: $showingDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    if let modelId = modelToDelete {
                        Task { await viewModel.deleteModel(modelId) }
                    }
                }
                Button("Cancel", role: .cancel) {
                    modelToDelete = nil
                }
            } message: {
                if let modelId = modelToDelete {
                    Text("Are you sure you want to permanently delete \(modelId)? This action cannot be undone.")
                } else {
                    Text("Are you sure you want to permanently delete this model?")
                }
            }
            .onAppear {
                Task {
                    await viewModel.testConnectionAndFetchModels()
                }
            }
        }
    }
    
    private func saveAsPreset() {
        let name = presetNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let hostname = viewModel.hostNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = Int(viewModel.portInput) ?? 1234
        
        let newPreset = HostPreset(
            name: name.isEmpty ? "oMLX Preset" : name,
            hostname: hostname,
            port: port
        )
        modelContext.insert(newPreset)
        try? modelContext.save()
        
        let key = viewModel.apiKeyInput
        Task {
            await newPreset.saveApiKey(key)
        }
        
        presetNameInput = ""
        showingSavePresetAlert = false
    }
}
