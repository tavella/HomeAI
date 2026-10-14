import SwiftUI
import SwiftData

public struct HostPresetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HostPreset.name) private var presets: [HostPreset]
    
    @Binding var showingAddPreset: Bool
    public let onSelectPreset: (HostPreset) -> Void
    
    @ObservedObject private var connection = ConnectionManager.shared
    
    public init(showingAddPreset: Binding<Bool> = .constant(false), onSelectPreset: @escaping (HostPreset) -> Void) {
        self._showingAddPreset = showingAddPreset
        self.onSelectPreset = onSelectPreset
    }
    
    private enum PresetField: Hashable {
        case name, host, port, apiKey
    }
    @FocusState private var focusedPresetField: PresetField?
    
    @State private var nameInput = ""
    @State private var hostInput = ""
    @State private var portInput = "1234"
    @State private var apiKeyInput = ""
    @State private var isApiKeyVisible = false
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if presets.isEmpty {
                Text("No saved presets. You can save Tailscale VPN IPs or local host connections for quick switching.")
                    .font(.caption)
                    .foregroundColor(Color.themeSecondaryText)
            } else {
                VStack(spacing: 8) {
                    ForEach(presets) { preset in
                        HStack(spacing: 12) {
                            Button {
                                onSelectPreset(preset)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(preset.name)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(Color.themeText)
                                            
                                            if connection.hostName == preset.hostname && connection.port == preset.port {
                                                LiquidGlassBadge(text: "Active", tint: .blue)
                                            }
                                        }
                                        
                                        Text("\(preset.hostname):\(String(preset.port))")
                                            .font(.caption)
                                            .foregroundColor(Color.themeSecondaryText)
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Button(role: .destructive) {
                                deletePreset(preset)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                            }
                            .glassButtonStyle(tint: .red)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.themeSurfaceVariant)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.secondary.opacity(0.12), lineWidth: 0.75)
                                )
                        )
                        .contextMenu {
                            Button(role: .destructive) {
                                deletePreset(preset)
                            } label: {
                                Label("Delete Preset", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddPreset) {
            NavigationStack {
                Form {
                    Section("Preset Details") {
                        TextField("Preset Name (e.g. MacBook Pro Tailscale)", text: $nameInput)
                            .focused($focusedPresetField, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focusedPresetField = .host }
                        TextField("Hostname or Tailscale IP", text: $hostInput)
                            .focused($focusedPresetField, equals: .host)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .submitLabel(.next)
                            .onSubmit { focusedPresetField = .port }
                        TextField("Port", text: $portInput)
                            .focused($focusedPresetField, equals: .port)
                            .keyboardType(.numberPad)
                            .submitLabel(.next)
                            .onSubmit { focusedPresetField = .apiKey }
                        HStack(spacing: 8) {
                            if isApiKeyVisible {
                                TextField("API Key (Optional)", text: $apiKeyInput)
                                    .focused($focusedPresetField, equals: .apiKey)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .submitLabel(.done)
                                    .onSubmit { focusedPresetField = nil }
                            } else {
                                SecureField("API Key (Optional)", text: $apiKeyInput)
                                    .focused($focusedPresetField, equals: .apiKey)
                                    .submitLabel(.done)
                                    .onSubmit { focusedPresetField = nil }
                            }
                            Button {
                                isApiKeyVisible.toggle()
                            } label: {
                                Image(systemName: isApiKeyVisible ? "eye.slash" : "eye")
                                    .foregroundColor(Color.themeSecondaryText)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isApiKeyVisible ? "Hide API key" : "Show API key")
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle("New Host Preset")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            focusedPresetField = nil
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .fontWeight(.semibold)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingAddPreset = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let p = Int(portInput) ?? 1234
                            let newPreset = HostPreset(
                                name: nameInput.isEmpty ? "MacBook Pro" : nameInput,
                                hostname: hostInput.isEmpty ? "100.115.195.12" : hostInput,
                                port: p
                            )
                            let keyToSave = apiKeyInput
                            modelContext.insert(newPreset)
                            try? modelContext.save()
                            
                            Task {
                                await newPreset.saveApiKey(keyToSave)
                            }
                            showingAddPreset = false
                        }
                    }
                }
            }
        }
    }
    
    private func deletePreset(_ preset: HostPreset) {
        modelContext.delete(preset)
        try? modelContext.save()
        Task {
            await preset.deleteApiKey()
        }
    }
}
