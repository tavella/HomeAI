import SwiftUI
import SwiftData

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var connection = ConnectionManager.shared
    
    public var isInitialSetup: Bool = false
    
    @State private var selectedTab: AppSettingsTab = .server
    
    // Alert & Sheet States
    @State private var showingSavePresetAlert = false
    @State private var presetNameInput = ""
    @State private var showingAddPreset = false
    @State private var modelToDelete: String? = nil
    @State private var showingDeleteConfirm = false
    @State private var selectedModelForSettings: HomeAIModel? = nil
    
    @State private var showingCreatePromptSheet = false
    @State private var promptToEditInSheet: SystemPromptPreset? = nil
    @State private var editingPromptId: UUID? = nil
    @State private var editingPromptName: String = ""
    @State private var editingPromptText: String = ""
    @State private var promptSaveSuccessBanner = false
    @State private var showingResetPromptsConfirm = false
    
    public init(isInitialSetup: Bool = false) {
        self.isInitialSetup = isInitialSetup
    }
    
    public var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                TabView(selection: $selectedTab) {
                    Tab(AppSettingsTab.server.title, systemImage: AppSettingsTab.server.icon, value: AppSettingsTab.server) {
                        tabNavigationContainer(for: .server)
                    }
                    .badge(connection.isConnected ? nil : Text("!"))
                    
                    Tab(AppSettingsTab.models.title, systemImage: AppSettingsTab.models.icon, value: AppSettingsTab.models) {
                        tabNavigationContainer(for: .models)
                    }
                    .badge(connection.availableModels.count)
                    
                    Tab(AppSettingsTab.prompts.title, systemImage: AppSettingsTab.prompts.icon, value: AppSettingsTab.prompts) {
                        tabNavigationContainer(for: .prompts)
                    }
                    
                    Tab(AppSettingsTab.general.title, systemImage: AppSettingsTab.general.icon, value: AppSettingsTab.general) {
                        tabNavigationContainer(for: .general)
                    }
                }
                .tabViewStyle(.sidebarAdaptable)
            } else {
                TabView(selection: $selectedTab) {
                    tabNavigationContainer(for: .server)
                        .tabItem { Label(AppSettingsTab.server.title, systemImage: AppSettingsTab.server.icon) }
                        .tag(AppSettingsTab.server)
                    
                    tabNavigationContainer(for: .models)
                        .tabItem { Label(AppSettingsTab.models.title, systemImage: AppSettingsTab.models.icon) }
                        .tag(AppSettingsTab.models)
                    
                    tabNavigationContainer(for: .prompts)
                        .tabItem { Label(AppSettingsTab.prompts.title, systemImage: AppSettingsTab.prompts.icon) }
                        .tag(AppSettingsTab.prompts)
                    
                    tabNavigationContainer(for: .general)
                        .tabItem { Label(AppSettingsTab.general.title, systemImage: AppSettingsTab.general.icon) }
                        .tag(AppSettingsTab.general)
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
                Text("Are you sure you want to delete '\(modelId)' from your oMLX host storage? This cannot be undone.")
            }
        }
        .sheet(item: $selectedModelForSettings) { model in
            ModelSettingsView(model: model)
        }
        .sheet(isPresented: $showingCreatePromptSheet) {
            PromptEditorSheetView(presetToEdit: promptToEditInSheet) { _ in
                syncActivePromptEditor()
            }
        }
        .alert("Reset Prompts", isPresented: $showingResetPromptsConfirm) {
            Button("Reset to Defaults", role: .destructive) {
                connection.resetSystemPromptPresetsToDefault()
                syncActivePromptEditor()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to restore default system prompts? Any custom prompts will be reset.")
        }
        .onAppear {
            if isInitialSetup || !connection.hasPreviousConnection {
                selectedTab = .server
            }
            syncActivePromptEditor()
        }
        .onChange(of: connection.selectedPromptPresetID) { _, _ in
            syncActivePromptEditor()
        }
    }
    
    // MARK: - Tab Container
    
    @ViewBuilder
    private func tabNavigationContainer(for tab: AppSettingsTab) -> some View {
        NavigationStack {
            ZStack {
                backgroundLayer
                
                ScrollView {
                    VStack(spacing: 16) {
                        pageView(for: tab)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(isInitialSetup ? "Setup Connection" : tab.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        viewModel.saveSettings()
                    }
                    .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isInitialSetup ? "Connect" : "Done") {
                        viewModel.saveSettings()
                        if isInitialSetup || !connection.isConnected {
                            viewModel.startTestConnection()
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(isInitialSetup && viewModel.hostNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    // MARK: - Page View Selector
    
    @ViewBuilder
    private func pageView(for tab: AppSettingsTab) -> some View {
        switch tab {
        case .server:
            ServerConnectionSettingsView(
                viewModel: viewModel,
                isInitialSetup: isInitialSetup,
                showingSavePresetAlert: $showingSavePresetAlert,
                showingAddPreset: $showingAddPreset,
                onSaveAsPresetTapped: {
                    presetNameInput = ""
                    showingSavePresetAlert = true
                }
            )
            
        case .models:
            ModelManagementSettingsView(
                viewModel: viewModel,
                onConfigureModel: { model in
                    selectedModelForSettings = model
                },
                onDeleteModel: { modelId in
                    modelToDelete = modelId
                    showingDeleteConfirm = true
                }
            )
            
        case .prompts:
            SystemPromptSettingsView(
                editingPromptId: $editingPromptId,
                editingPromptName: $editingPromptName,
                editingPromptText: $editingPromptText,
                promptSaveSuccessBanner: $promptSaveSuccessBanner,
                onSelectPreset: { preset in
                    connection.selectSystemPromptPreset(id: preset.id)
                    syncActivePromptEditor()
                },
                onEditPresetInSheet: { preset in
                    promptToEditInSheet = preset
                    showingCreatePromptSheet = true
                },
                onNewPromptTapped: {
                    promptToEditInSheet = nil
                    showingCreatePromptSheet = true
                },
                onResetPromptsTapped: {
                    showingResetPromptsConfirm = true
                },
                onSaveChanges: {
                    saveActivePromptChanges()
                },
                onDeletePrompt: { preset in
                    connection.deleteSystemPromptPreset(id: preset.id)
                    syncActivePromptEditor()
                }
            )
            
        case .general:
            GeneralSettingsView(viewModel: viewModel)
        }
    }
    
    // MARK: - Background Layer
    
    private var backgroundLayer: some View {
        Color.themeBackground.ignoresSafeArea()
    }
    
    // MARK: - Helper Methods
    
    private func syncActivePromptEditor() {
        let active = connection.activeSystemPrompt
        editingPromptId = active.id
        editingPromptName = active.name
        editingPromptText = active.promptText
    }
    
    private func saveActivePromptChanges() {
        guard let currentId = editingPromptId,
              let existing = connection.systemPromptPresets.first(where: { $0.id == currentId }) else { return }
        var modified = existing
        let trimmedName = editingPromptName.trimmingCharacters(in: .whitespacesAndNewlines)
        modified.name = trimmedName.isEmpty ? existing.name : trimmedName
        modified.promptText = editingPromptText
        connection.saveSystemPromptPreset(modified)
        
        withAnimation {
            promptSaveSuccessBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                promptSaveSuccessBanner = false
            }
        }
    }
    
    private func saveAsPreset() {
        guard !presetNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let cleanName = presetNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanHost = viewModel.hostNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPort = Int(viewModel.portInput.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1234
        
        let newPreset = HostPreset(name: cleanName, hostname: cleanHost, port: cleanPort)
        modelContext.insert(newPreset)
        try? modelContext.save()
        
        let apiKeyToSave = viewModel.apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKeyToSave.isEmpty {
            Task {
                await newPreset.saveApiKey(apiKeyToSave)
            }
        }
        
        presetNameInput = ""
        AppLogger.settings.info("Created new host preset: \(cleanName, privacy: .public)")
    }
}
