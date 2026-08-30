# HomeAI 🏠✨

> **Private, On-Device & Local Intelligence for iOS — Powered by oMLX & Apple Silicon**

HomeAI is a modern, privacy-first native iOS application built with SwiftUI and SwiftData. It connects directly to your local **oMLX** or OpenAI-compatible LLM inference server (running locally or securely across your private Tailscale mesh VPN) to provide fast, uncensored, and private conversational AI right on your iPhone and iPad.

---

## 🌟 Key Features

### 🧠 On-Device & Local LLM Inference
- **oMLX Native Integration**: First-class support for oMLX server endpoints, with dynamic model discovery, state tracking, and streaming token delivery via Server-Sent Events (SSE).
- **In-App Model Lifecycle Management**: Load, unload (eject), inspect, switch, and delete models directly from the iOS interface without touching a terminal.
- **Per-Chat Model Switching**: Switch the active LLM on a per-conversation basis or set global defaults seamlessly.
- **Multimodal Support**: Attach images and documents (PDF, TXT, Markdown) directly into conversations with real-time text extraction and vision embeddings.

### 🌐 Augmented Real-Time Web Grounding & Weather
- **Intelligent Intent Detection**: Distinguishes between conversational chat and queries requiring real-time facts or live weather.
- **Live Weather Fetching**: Automatically detects location and ZIP codes to fetch current forecasts and conditions.
- **DuckDuckGo Web Search Integration**: Grounds model responses with real-time web search summaries and cited sources.

### 🎨 State-of-the-Art Adaptive UI & Design
- **Adaptive Layout**: Engineered with a responsive `NavigationSplitView` that transitions between multi-column landscape and compact single-column portrait modes.
- **Smooth Gesture Navigation**: Native left-edge swipe-to-back gesture with haptic feedback.
- **Rich Markdown & Code Rendering**: Full markdown formatting with code block syntax highlighting, math notation, tables, and one-tap copy actions.
- **Curated Themes**: Includes custom-crafted **Warm Navy** dark aesthetic, System Standard, Pure Dark, and Light modes.
- **Privacy Shield**: Automatically conceals conversation content behind a security shield when the app is backgrounded or inactive.

### ⚡ Offline-First Persistence & Full-Text Search
- **SwiftData Storage**: Locally stored conversation history with zero cloud lock-in.
- **Instant Full-Text Search**: In-memory debounced search engine across all chat titles, message contents, and attached file texts with term highlighting.
- **Document Exporting**: Securely export conversation transcripts in encrypted temporary sandbox files.

---

## 🛠️ Architecture & Tech Stack

- **Framework**: SwiftUI + SwiftData (iOS 17+)
- **Architecture**: MVVM with reactive `@Observable` / `ObservableObject` pipelines
- **Networking**: `URLSession` async/await streaming with custom `SSEParser`
- **Security**: Keychain Services for API token storage and sandbox cleanup routines
- **Target Devices**: iPhone & iPad (Optimized for iPhone 17 Pro / Pro Max & Apple Silicon iPads)

```
HomeAI/
├── App/                # App entry point, lifecycle, and shared model container
├── Models/             # SwiftData schema (ChatSession, ChatMessage, MessageAttachment) & Theme models
├── Services/           # HomeAIClient (oMLX/OpenAI REST API), ConnectionManager, WebSearchService
├── ViewModels/         # ChatViewModel, SettingsViewModel, ConversationSearchViewModel
└── Views/
    ├── MainView.swift          # Root NavigationSplitView & Privacy Shield
    ├── Sidebar/                # Conversation list, search, status badge, and rows
    ├── Chat/                   # Chat detail, message bubbles, markdown, attachments, input bar
    └── Settings/               # Server config, Tailscale presets, model cards, theme switcher
```

---

## 🚀 Getting Started

### Prerequisites
1. **Xcode 16+** (iOS 17.0+ deployment target)
2. **Local oMLX or OpenAI-compatible server** running on your Mac or local network (e.g. `http://localhost:8000` or `http://100.x.y.z:1234` via Tailscale).

### Build & Run
1. Clone the repository:
   ```bash
   git clone https://github.com/tavella/HomeAI.git
   cd HomeAI
   ```
2. Open `HomeAI.xcodeproj` in Xcode or generate the project using `create_xcodeproj.py`.
3. Select your physical iOS device (or Simulator) and click **Run** (`⌘R`).

### Connecting to your Server
1. Open the app and tap the **Gear** icon (or access **Settings**).
2. Enter your host IP/Hostname (e.g. `127.0.0.1` or your Tailscale IP) and Port (`8000` or `1234`).
3. Tap **Test Connection & Fetch Models**.
4. Select your desired active model and start chatting!

---

## 🧪 Testing

HomeAI includes a comprehensive suite of unit and integration tests covering navigation state machines, SSE parsing, client error handling, model lifecycle endpoints, and search intent detection:

```bash
xcodebuild test -project HomeAI.xcodeproj -scheme HomeAI -destination "platform=iOS Simulator,name=iPhone 17 Pro Max"
```

---

## 📄 License

This project is licensed under the MIT License.
