import SwiftUI

public struct PromptEditorSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var connection = ConnectionManager.shared
    
    public var presetToEdit: SystemPromptPreset?
    public var onSave: ((SystemPromptPreset) -> Void)?
    
    @State private var nameInput: String = ""
    @State private var promptTextInput: String = ""
    @FocusState private var focusedField: Field?
    
    private enum Field: Hashable {
        case name, promptText
    }
    
    public init(presetToEdit: SystemPromptPreset? = nil, onSave: ((SystemPromptPreset) -> Void)? = nil) {
        self.presetToEdit = presetToEdit
        self.onSave = onSave
        _nameInput = State(initialValue: presetToEdit?.name ?? "")
        _promptTextInput = State(initialValue: presetToEdit?.promptText ?? "")
    }
    
    private var isEditing: Bool {
        presetToEdit != nil
    }
    
    private var canSave: Bool {
        !nameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !promptTextInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Prompt Information") {
                    TextField("Prompt Name (e.g. Code Reviewer)", text: $nameInput)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .promptText }
                        .accessibilityIdentifier("PromptNameInput")
                }
                
                Section("System Instructions") {
                    VStack(alignment: .leading, spacing: 6) {
                        TextEditor(text: $promptTextInput)
                            .focused($focusedField, equals: .promptText)
                            .frame(minHeight: 180)
                            .accessibilityIdentifier("PromptTextInput")
                        
                        HStack {
                            Text("\(promptTextInput.count) characters")
                                .font(.caption2)
                                .foregroundColor(Color.themeSecondaryText)
                            Spacer()
                            Text("\(promptTextInput.split { $0.isWhitespace }.count) words")
                                .font(.caption2)
                                .foregroundColor(Color.themeSecondaryText)
                        }
                    }
                }
            }
            .scrollContentBackground(connection.appTheme == "warm_navy" ? .hidden : .visible)
            .background(connection.appTheme == "warm_navy" ? Color.themeBackground : Color(UIColor.systemGroupedBackground))
            .preferredColorScheme(connection.preferredColorScheme)
            .navigationTitle(isEditing ? "Edit Prompt" : "New System Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePrompt()
                    }
                    .disabled(!canSave)
                    .fontWeight(.bold)
                    .accessibilityIdentifier("SavePromptButton")
                }
            }
            .onAppear {
                if !isEditing {
                    focusedField = .name
                }
            }
        }
    }
    
    private func savePrompt() {
        let trimmedName = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedText = promptTextInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let preset: SystemPromptPreset
        if let existing = presetToEdit {
            var updated = existing
            updated.name = trimmedName
            updated.promptText = trimmedText
            updated.updatedAt = Date()
            preset = updated
        } else {
            preset = SystemPromptPreset(
                name: trimmedName,
                promptText: trimmedText,
                isBuiltIn: false
            )
        }
        
        connection.saveSystemPromptPreset(preset)
        connection.selectSystemPromptPreset(id: preset.id)
        onSave?(preset)
        dismiss()
    }
}
