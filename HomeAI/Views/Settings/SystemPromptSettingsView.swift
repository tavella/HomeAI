import SwiftUI

public struct SystemPromptSettingsView: View {
    @ObservedObject private var connection = ConnectionManager.shared
    
    @Binding public var editingPromptId: UUID?
    @Binding public var editingPromptName: String
    @Binding public var editingPromptText: String
    @Binding public var promptSaveSuccessBanner: Bool
    
    public let onSelectPreset: (SystemPromptPreset) -> Void
    public let onEditPresetInSheet: (SystemPromptPreset) -> Void
    public let onNewPromptTapped: () -> Void
    public let onResetPromptsTapped: () -> Void
    public let onSaveChanges: () -> Void
    public let onDeletePrompt: (SystemPromptPreset) -> Void
    
    public init(
        editingPromptId: Binding<UUID?>,
        editingPromptName: Binding<String>,
        editingPromptText: Binding<String>,
        promptSaveSuccessBanner: Binding<Bool>,
        onSelectPreset: @escaping (SystemPromptPreset) -> Void,
        onEditPresetInSheet: @escaping (SystemPromptPreset) -> Void,
        onNewPromptTapped: @escaping () -> Void,
        onResetPromptsTapped: @escaping () -> Void,
        onSaveChanges: @escaping () -> Void,
        onDeletePrompt: @escaping (SystemPromptPreset) -> Void
    ) {
        self._editingPromptId = editingPromptId
        self._editingPromptName = editingPromptName
        self._editingPromptText = editingPromptText
        self._promptSaveSuccessBanner = promptSaveSuccessBanner
        self.onSelectPreset = onSelectPreset
        self.onEditPresetInSheet = onEditPresetInSheet
        self.onNewPromptTapped = onNewPromptTapped
        self.onResetPromptsTapped = onResetPromptsTapped
        self.onSaveChanges = onSaveChanges
        self.onDeletePrompt = onDeletePrompt
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Preset Library Card
            LiquidGlassCard(
                icon: "text.quote",
                title: "System Prompts",
                subtitle: "\(connection.systemPromptPresets.count) preset persona(s) configured",
                tint: nil,
                headerTrailing: {
                    HStack(spacing: 8) {
                        Button {
                            onNewPromptTapped()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("New Prompt")
                            }
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        }
                        .glassButtonStyle()
                        .accessibilityIdentifier("NewPromptHeaderButton")
                        
                        Menu {
                            Button(role: .destructive) {
                                onResetPromptsTapped()
                            } label: {
                                Label("Reset All Prompts to Default", systemImage: "arrow.uturn.backward.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.footnote)
                                .foregroundColor(.blue)
                                .padding(.leading, 2)
                        }
                    }
                }
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Select Active Persona")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color.themeSecondaryText)
                    
                    VStack(spacing: 8) {
                        ForEach(connection.systemPromptPresets) { preset in
                            let isSelected = connection.selectedPromptPresetID == preset.id.uuidString
                            
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(preset.name)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(Color.themeText)
                                        
                                        if isSelected {
                                            Text("Active")
                                                .font(.system(size: 10, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(Color.blue.opacity(0.15)))
                                                .foregroundColor(.blue)
                                        } else if preset.isBuiltIn {
                                            Text("Built-in")
                                                .font(.system(size: 9, weight: .semibold))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(Capsule().fill(Color.secondary.opacity(0.12)))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Text(preset.promptText)
                                        .font(.caption2)
                                        .foregroundColor(Color.themeSecondaryText)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                                
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                                
                                Button {
                                    onEditPresetInSheet(preset)
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 13))
                                        .foregroundColor(.blue)
                                        .padding(6)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityIdentifier("EditPromptButton_\(preset.name)")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isSelected ? Color.blue.opacity(0.08) : Color.themeSurfaceVariant)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isSelected ? Color.blue.opacity(0.35) : Color.clear, lineWidth: 1)
                                    )
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelectPreset(preset)
                            }
                            .accessibilityIdentifier("SelectPromptRow_\(preset.name)")
                        }
                    }
                }
            }
            
            // Inline Active Prompt Editor Card
            LiquidGlassCard(
                icon: "square.and.pencil",
                title: "Active Prompt Editor",
                subtitle: "Directly customize behavior and tone",
                tint: nil,
                headerTrailing: {
                    if promptSaveSuccessBanner {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Saved")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .transition(.opacity)
                    }
                }
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Prompt Name")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(Color.themeSecondaryText)
                        
                        TextField("Prompt Name", text: $editingPromptName)
                            .textFieldStyle(.roundedBorder)
                            .font(.subheadline)
                            .accessibilityIdentifier("InlinePromptNameField")
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Instructions")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(Color.themeSecondaryText)
                            
                            Spacer()
                            
                            Text("\(editingPromptText.count) chars")
                                .font(.caption2)
                                .foregroundColor(Color.themeSecondaryText)
                        }
                        
                        TextEditor(text: $editingPromptText)
                            .frame(height: 120)
                            .padding(4)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                            .accessibilityIdentifier("InlinePromptTextField")
                    }
                    
                    HStack {
                        Button {
                            onSaveChanges()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.down.fill")
                                Text("Save Changes")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        }
                        .glassProminentButtonStyle()
                        .accessibilityIdentifier("SaveActivePromptChangesButton")
                        
                        Spacer()
                        
                        if let active = connection.systemPromptPresets.first(where: { $0.id == editingPromptId }), !active.isBuiltIn {
                            Button(role: .destructive) {
                                onDeletePrompt(active)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                    Text("Delete")
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                            .glassButtonStyle()
                            .accessibilityIdentifier("DeletePromptButton")
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
}
