import SwiftUI
import SwiftData

public struct SystemPromptSwitcherSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var connection = ConnectionManager.shared
    @Bindable public var session: ChatSession
    
    @State private var expandedPromptId: UUID? = nil
    @State private var showingNewPromptSheet = false
    
    public init(session: ChatSession) {
        self.session = session
    }
    
    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("System Prompt")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.themeText)
                        
                        Text("Select the persona and behavior guidelines for this conversation.")
                            .font(.caption)
                            .foregroundColor(.themeSecondaryText)
                    }
                    
                    Spacer()
                    
                    Button {
                        showingNewPromptSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("New")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    }
                    .accessibilityIdentifier("ConversationNewPromptButton")
                }
                .padding(.horizontal)
                .padding(.top)
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(connection.systemPromptPresets) { preset in
                            let isSelected = session.systemPrompt == preset.promptText || session.effectivePromptTitle == preset.name
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Text(preset.name)
                                                .font(.headline)
                                                .foregroundColor(.themeText)
                                            
                                            if preset.isBuiltIn {
                                                LiquidGlassBadge(text: "Built-in", tint: .secondary)
                                            }
                                        }
                                        
                                        Text(preset.promptText)
                                            .font(.caption)
                                            .foregroundColor(.themeSecondaryText)
                                            .lineLimit(expandedPromptId == preset.id ? nil : 2)
                                    }
                                    
                                    Spacer()
                                    
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 20))
                                    }
                                }
                                
                                HStack {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if expandedPromptId == preset.id {
                                                expandedPromptId = nil
                                            } else {
                                                expandedPromptId = preset.id
                                            }
                                        }
                                    } label: {
                                        Text(expandedPromptId == preset.id ? "Show Less" : "View Full Prompt")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    .glassButtonStyle()
                                    
                                    Spacer()
                                }
                            }
                            .padding()
                            .liquidGlass(cornerRadius: 14, isInteractive: true, tint: isSelected ? .blue : nil)
                            .padding(.horizontal)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                session.systemPrompt = preset.promptText
                                session.systemPromptTitle = preset.name
                                try? session.modelContext?.save()
                                dismiss()
                            }
                            .accessibilityIdentifier("SelectPrompt_\(preset.name)")
                        }
                    }
                    .padding(.bottom, 16)
                }
                
                HStack {
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding()
                }
            }
            .background(Color.themeBackground.ignoresSafeArea())
            .sheet(isPresented: $showingNewPromptSheet) {
                PromptEditorSheetView { newPreset in
                    session.systemPrompt = newPreset.promptText
                    session.systemPromptTitle = newPreset.name
                    try? session.modelContext?.save()
                    dismiss()
                }
            }
        }
    }
}
