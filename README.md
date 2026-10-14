# HomeAI

Private, on-device and local intelligence client for iOS, built for oMLX and OpenAI-compatible inference servers.

HomeAI is a native iOS client written in Swift using SwiftUI and SwiftData. It connects directly to local or private network inference backends, such as oMLX instances running on Apple Silicon Macs or Linux workstations accessible over local subnets or Tailscale mesh VPNs. The application provides streaming inference, multimodal context attachment, model lifecycle controls, and local-first persistence without third-party analytics or external cloud dependencies.

## Key Capabilities

### Inference and Server Integration
- Direct integration with oMLX and OpenAI-compatible server APIs.
- Real-time token streaming using Server-Sent Events (SSE) with structured cancellation handling.
- In-app model management for inspecting, loading, unloading, and switching active models.
- Per-conversation model selection and custom system prompt presets.
- Multimodal attachment support for images and documents (PDF, plain text, Markdown) with context parsing.

### Real-Time Search and Grounding
- Search intent classification to differentiate between conversational queries and live informational requests.
- Live weather retrieval via structured location parsing.
- Web search grounding with citation links and source attribution.

### User Interface and Interaction
- Adaptive interface utilizing NavigationSplitView for seamless transitions between compact phone layouts and multi-column iPad or landscape views.
- Native Liquid Glass material styling designed to Apple Human Interface Guidelines.
- Full Markdown rendering with syntax-highlighted code blocks, tables, and copy utilities.
- Privacy Shield overlay that automatically redacts conversation contents when the application enters background or inactive states.
- Support for Dynamic Type scaling and VoiceOver accessibility labels.

### Persistence and Data Protection
- Local persistence backed by SwiftData with error recovery and external storage optimization for large attachments.
- Secure API key and credential management via Apple Keychain Services.
- Offline-first architecture with debounced full-text search across titles and message bodies.
- Clean App Store readiness configuration, including PrivacyInfo.xcprivacy declaration and scoped network configuration.

## Architecture

- Frameworks: SwiftUI, SwiftData, Combine, Security
- Target Platforms: iOS 17.0 and later (iPhone and iPad)
- Concurrency: Swift Concurrency with actor isolation
- Storage: SwiftData SQLite store with in-memory fallback protection

```
HomeAI/
  App/          Application entry point, configuration, and lifecycle
  Models/       SwiftData persistent schemas and domain data models
  Services/     Client API networking, connection manager, web grounding, keychain
  ViewModels/   MainActor view models coordinating state and actions
  Views/
    MainView.swift  Root navigation structure and privacy shield overlay
    Sidebar/        Conversation list, search, and navigation rows
    Chat/           Message views, streaming display, input controls, attachments
    Settings/       Host connection, model management, system prompt presets
```

## Getting Started

### Requirements
- Xcode 16.0 or later
- iOS 17.0+ deployment target
- A running oMLX server or OpenAI-compatible endpoint accessible via local LAN or Tailscale

### Build and Run
1. Clone the repository:
   ```bash
   git clone https://github.com/tavella/HomeAI.git
   cd HomeAI
   ```
2. Open `HomeAI.xcodeproj` in Xcode.
3. Select your target device or simulator and run the project.

### Connecting to an Inference Host
1. Navigate to Settings within the app.
2. Enter the host IP address or hostname (for example, a Tailscale IP such as `100.x.y.z` or a local IP) and the listening port (default `8000`).
3. If your server requires authentication, enter the API key.
4. Select Test Connection to verify the endpoint and retrieve available models.

## Testing

HomeAI includes unit and integration tests covering navigation state machines, SSE parsing, client error handling, model lifecycle endpoints, and search intent detection.

Run the test suite via xcodebuild:
```bash
xcodebuild test -project HomeAI.xcodeproj -scheme HomeAI -destination "generic/platform=iOS Simulator"
```

## License

This project is licensed under the MIT License.
