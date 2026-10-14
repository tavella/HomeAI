import SwiftUI

public struct ModelSettingsView: View {
    @StateObject private var viewModel: ModelSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var connection = ConnectionManager.shared
    
    @State private var showingResetAlert: Bool = false
    @FocusState private var focusedField: String?
    
    public init(model: HomeAIModel) {
        _viewModel = StateObject(wrappedValue: ModelSettingsViewModel(model: model))
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Segmented Bar matching screenshot
                topSegmentedControl
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.themeBackground)
                
                Divider()
                    .background(Color.secondary.opacity(0.2))
                
                // Success / Error Banner
                if let successMsg = viewModel.saveSuccessMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(successMsg)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.themeText)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.12))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                if let errorMsg = viewModel.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(errorMsg)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.themeText)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.12))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch viewModel.selectedTab {
                        case .profiles:
                            profilesTabContent
                        case .basic:
                            basicTabContent
                        case .advanced:
                            advancedTabContent
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                
                // Bottom Action Bar
                bottomActionBar
            }
            .background(Color.themeBackground.ignoresSafeArea())
            .navigationTitle(viewModel.model.effectiveDisplayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color.themeSecondaryText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.saveSettings()
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .task {
                await viewModel.loadProfiles()
            }
            .alert("Reset Settings", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset to Defaults", role: .destructive) {
                    Task {
                        await viewModel.resetSettings()
                    }
                }
            } message: {
                Text("Are you sure you want to reset '\(viewModel.model.effectiveDisplayName)' to oMLX default settings?")
            }
        }
    }
    
    // MARK: - Top Segmented Control (Profiles | Basic | Advanced)
    private var topSegmentedControl: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        viewModel.selectedTab = tab
                    }
                    if tab == .profiles && viewModel.profiles.isEmpty {
                        Task { await viewModel.loadProfiles() }
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline)
                        .fontWeight(viewModel.selectedTab == tab ? .semibold : .medium)
                        .foregroundColor(viewModel.selectedTab == tab ? .white : Color.themeSecondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(viewModel.selectedTab == tab ? Color.blue : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.themeSurface)
        )
    }
    
    // MARK: - Basic Settings Tab
    private var basicTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("BASIC SETTINGS")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(Color.themeSecondaryText)
                .tracking(1.0)
            
            VStack(spacing: 1) {
                // 1. Model Alias
                settingRow(
                    title: "Model Alias",
                    subtitle: "Falls back to the model id"
                ) {
                    TextField("Model ID fallback", text: $viewModel.modelAlias)
                        .font(.system(.subheadline, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.themeBackground)
                        .cornerRadius(6)
                        .frame(maxWidth: 200)
                }
                
                // 2. Model Type
                settingRow(
                    title: "Model Type"
                ) {
                    Picker("Model Type", selection: $viewModel.modelTypeOverride) {
                        Text("Auto-detect").tag("auto")
                        Text("Chat (LLM)").tag("chat")
                        Text("Completion").tag("completion")
                        Text("Vision (VLM)").tag("vlm")
                        Text("Embedding").tag("embedding")
                    }
                    .pickerStyle(.menu)
                    .tint(Color.themeText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.themeBackground)
                    .cornerRadius(6)
                }
                
                // 3. Context Window
                settingRow(
                    title: "Context Window",
                    subtitle: "Maximum tokens per request"
                ) {
                    HStack(spacing: 4) {
                        TextField("32768", text: $viewModel.contextWindowText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.subheadline, design: .monospaced))
                            .frame(width: 80)
                        Text("tk")
                            .font(.caption2)
                            .foregroundColor(Color.themeSecondaryText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.themeBackground)
                    .cornerRadius(6)
                }
                
                // 4. Max Tokens
                settingRow(
                    title: "Max Tokens",
                    subtitle: "Cap on generated tokens (empty = default)"
                ) {
                    TextField("4096", text: $viewModel.maxTokensText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(.subheadline, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.themeBackground)
                        .cornerRadius(6)
                        .frame(width: 90)
                }
                
                // 5. Temperature
                VStack(spacing: 6) {
                    settingRow(
                        title: "Temperature",
                        subtitle: "Sampling randomness (≥ 0). 0 = deterministic."
                    ) {
                        TextField("0.7", text: $viewModel.temperatureText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.subheadline, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.themeBackground)
                            .cornerRadius(6)
                            .frame(width: 80)
                            .onChange(of: viewModel.temperatureText) { _, newText in
                                viewModel.updateTemperature(fromText: newText)
                            }
                    }
                    
                    Slider(value: $viewModel.temperature, in: 0.0...2.0, step: 0.05) {
                        Text("Temperature")
                    }
                    .tint(.blue)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                    .onChange(of: viewModel.temperature) { _, newVal in
                        viewModel.updateTemperature(fromSlider: newVal)
                    }
                }
                
                // 6. Top P
                VStack(spacing: 6) {
                    settingRow(
                        title: "Top P",
                        subtitle: "Nucleus sampling cutoff (0 < p ≤ 1)."
                    ) {
                        TextField("1.0", text: $viewModel.topPText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.subheadline, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.themeBackground)
                            .cornerRadius(6)
                            .frame(width: 80)
                            .onChange(of: viewModel.topPText) { _, newText in
                                viewModel.updateTopP(fromText: newText)
                            }
                    }
                    
                    Slider(value: $viewModel.topP, in: 0.0...1.0, step: 0.05) {
                        Text("Top P")
                    }
                    .tint(.blue)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                    .onChange(of: viewModel.topP) { _, newVal in
                        viewModel.updateTopP(fromSlider: newVal)
                    }
                }
                
                // 7. Top K
                settingRow(
                    title: "Top K",
                    subtitle: "Limit candidates to top K (positive integer)."
                ) {
                    TextField("40", text: $viewModel.topKText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(.subheadline, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.themeBackground)
                        .cornerRadius(6)
                        .frame(width: 80)
                }
                
                // 8. Min P
                settingRow(
                    title: "Min P",
                    subtitle: "Minimum probability floor (0 ≤ p ≤ 1)."
                ) {
                    TextField("Default", text: $viewModel.minPText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(.subheadline, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.themeBackground)
                        .cornerRadius(6)
                        .frame(width: 80)
                }
                
                // 9. Repetition Penalty
                settingRow(
                    title: "Repetition Penalty",
                    subtitle: "Penalize repeated tokens (-2 to 2)."
                ) {
                    TextField("1.05", text: $viewModel.repetitionPenaltyText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(.subheadline, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.themeBackground)
                        .cornerRadius(6)
                        .frame(width: 80)
                }
                
                // 10. Presence Penalty
                settingRow(
                    title: "Presence Penalty",
                    subtitle: "Penalize tokens already present (-2 to 2)."
                ) {
                    TextField("Default", text: $viewModel.presencePenaltyText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(.subheadline, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.themeBackground)
                        .cornerRadius(6)
                        .frame(width: 80)
                }
                
                // 11. TTL
                settingRow(
                    title: "TTL",
                    subtitle: "Seconds before idle unload (empty = no TTL)"
                ) {
                    HStack(spacing: 4) {
                        TextField("No TTL", text: $viewModel.ttlText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.subheadline, design: .monospaced))
                            .frame(width: 70)
                        Text("s")
                            .font(.caption2)
                            .foregroundColor(Color.themeSecondaryText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.themeBackground)
                    .cornerRadius(6)
                }
            }
            .background(Color.themeSurface)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Advanced Settings Tab
    private var advancedTabContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section 1: Reasoning & Thinking
            VStack(alignment: .leading, spacing: 10) {
                Text("REASONING & THINKING")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Color.themeSecondaryText)
                    .tracking(1.0)
                
                VStack(spacing: 1) {
                    ToggleRow(title: "Enable Thinking Mode", subtitle: "Extract and isolate chain-of-thought tokens", isOn: $viewModel.enableThinking)
                    
                    ToggleRow(title: "Thinking Token Budget", subtitle: "Limit reasoning step output tokens", isOn: $viewModel.thinkingBudgetEnabled)
                    
                    if viewModel.thinkingBudgetEnabled {
                        settingRow(title: "Budget Cap Tokens", subtitle: "Maximum reasoning tokens generated") {
                            TextField("4096", text: $viewModel.thinkingBudgetText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(.subheadline, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.themeBackground)
                                .cornerRadius(6)
                                .frame(width: 90)
                        }
                    }
                }
                .background(Color.themeSurface)
                .cornerRadius(12)
            }
            
            // Section 2: Hardware & Acceleration (oMLX Core)
            VStack(alignment: .leading, spacing: 10) {
                Text("HARDWARE ACCELERATION")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Color.themeSecondaryText)
                    .tracking(1.0)
                
                VStack(spacing: 1) {
                    ToggleRow(title: "Lightning MTP (Speculative)", subtitle: "Multi-Token Prediction for faster decoding", isOn: $viewModel.mtpEnabled)
                    
                    if viewModel.mtpEnabled {
                        settingRow(title: "MTP Adaptive Depth", subtitle: "Draft token depth (1 to 8)") {
                            TextField("4", text: $viewModel.mtpAdaptiveDepthText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(.subheadline, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.themeBackground)
                                .cornerRadius(6)
                                .frame(width: 70)
                        }
                    }
                    
                    ToggleRow(title: "TurboQuant KV Cache", subtitle: "Compresses Key-Value cache in RAM/SSD", isOn: $viewModel.turboquantKvEnabled)
                    
                    if viewModel.turboquantKvEnabled {
                        settingRow(title: "TurboQuant Bits", subtitle: "Bit-depth quantization for attention") {
                            Picker("Bits", selection: $viewModel.turboquantBits) {
                                Text("4.0 bit").tag(4.0)
                                Text("8.0 bit").tag(8.0)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 140)
                        }
                    }
                    
                    ToggleRow(title: "DFlash Acceleration", subtitle: "Draft model speculative decoding", isOn: $viewModel.dflashEnabled)
                    
                    ToggleRow(title: "Apple Neural Engine (ANE)", subtitle: "Offload prompt prefill to Apple Neural Engine", isOn: $viewModel.qwen35AnePrefillEnabled)
                }
                .background(Color.themeSurface)
                .cornerRadius(12)
            }
            
            // Section 3: Sampling & Tool Limits
            VStack(alignment: .leading, spacing: 10) {
                Text("SAMPLING & LIMITS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Color.themeSecondaryText)
                    .tracking(1.0)
                
                VStack(spacing: 1) {
                    ToggleRow(title: "Force Sampling", subtitle: "Bypass greedy decoding overrides", isOn: $viewModel.forceSampling)
                    
                    settingRow(title: "Max Tool Result Tokens", subtitle: "Cap on tool or web search output length") {
                        TextField("Default", text: $viewModel.maxToolResultTokensText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.subheadline, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.themeBackground)
                            .cornerRadius(6)
                            .frame(width: 90)
                    }
                }
                .background(Color.themeSurface)
                .cornerRadius(12)
            }
            
            // Section 4: Model Status & Pinning
            VStack(alignment: .leading, spacing: 10) {
                Text("MODEL LIFECYCLE & FLAGS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Color.themeSecondaryText)
                    .tracking(1.0)
                
                VStack(spacing: 1) {
                    ToggleRow(title: "Pin in RAM (is_pinned)", subtitle: "Keep model resident and prevent LRU unload", isOn: $viewModel.isPinned)
                    
                    ToggleRow(title: "Favorite Model", subtitle: "Mark as prioritized favorite in model lists", isOn: $viewModel.isFavorite)
                }
                .background(Color.themeSurface)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Profiles Tab
    private var profilesTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("AVAILABLE PROFILES")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Color.themeSecondaryText)
                    .tracking(1.0)
                Spacer()
                if viewModel.isLoadingProfiles {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await viewModel.loadProfiles() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            if viewModel.profiles.isEmpty && !viewModel.isLoadingProfiles {
                VStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.2.square")
                        .font(.system(size: 36))
                        .foregroundColor(Color.themeSecondaryText)
                    Text("No Server Profiles Discovered")
                        .font(.headline)
                        .foregroundColor(Color.themeText)
                    Text("Profiles allow saving named parameter presets in oMLX that can be applied to this model.")
                        .font(.caption)
                        .foregroundColor(Color.themeSecondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .padding(.horizontal, 20)
                .background(Color.themeSurface)
                .cornerRadius(12)
            } else {
                ForEach(viewModel.profiles) { profile in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.displayName ?? profile.name)
                                    .font(.headline)
                                    .foregroundColor(Color.themeText)
                                Text(profile.name)
                                    .font(.caption2)
                                    .fontDesign(.monospaced)
                                    .foregroundColor(Color.themeSecondaryText)
                            }
                            Spacer()
                            
                            if viewModel.activeProfileName == profile.name {
                                Text("ACTIVE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(6)
                            }
                        }
                        
                        // Summary Badges
                        HStack(spacing: 8) {
                            if let temp = profile.settings?.temperature {
                                BadgeView(label: "Temp", value: String(format: "%.2f", temp))
                            }
                            if let ctx = profile.settings?.maxContextWindow {
                                BadgeView(label: "Context", value: "\(ctx)")
                            }
                            if let maxT = profile.settings?.maxTokens {
                                BadgeView(label: "MaxTok", value: "\(maxT)")
                            }
                            if profile.settings?.mtpEnabled == true {
                                BadgeView(label: "MTP", value: "ON")
                            }
                        }
                        
                        // Apply Button
                        Button {
                            Task { await viewModel.applyProfile(profile) }
                        } label: {
                            HStack {
                                if viewModel.applyingProfileName == profile.name {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "checkmark.circle")
                                }
                                Text("Apply Profile to Model")
                                    .fontWeight(.medium)
                            }
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                        .disabled(viewModel.applyingProfileName != nil)
                    }
                    .padding()
                    .background(Color.themeSurface)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        VStack(spacing: 8) {
            Divider()
                .background(Color.secondary.opacity(0.2))
            
            HStack(spacing: 12) {
                Button {
                    showingResetAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Reset")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(10)
                }
                .disabled(viewModel.isSaving || viewModel.isResetting)
                
                Button {
                    Task {
                        await viewModel.saveSettings()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isSaving {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.down.fill")
                        }
                        Text(viewModel.isSaving ? "Saving..." : "Save Settings to oMLX")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .disabled(viewModel.isSaving || viewModel.isResetting)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.themeSurface)
    }
    
    // MARK: - Helper Subviews
    private func settingRow<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color.themeText)
                if let sub = subtitle {
                    Text(sub)
                        .font(.caption2)
                        .foregroundColor(Color.themeSecondaryText)
                }
            }
            Spacer()
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct ToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color.themeText)
                if let sub = subtitle {
                    Text(sub)
                        .font(.caption2)
                        .foregroundColor(Color.themeSecondaryText)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct BadgeView: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .foregroundColor(Color.themeSecondaryText)
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(Color.themeText)
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.themeBackground)
        .cornerRadius(4)
    }
}
