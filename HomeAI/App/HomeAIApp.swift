import SwiftUI
import SwiftData

@main
struct HomeAIApp: App {
    let container: ModelContainer
    
    init() {
        // Perform security cleanup on startup
        DocumentExporter.shared.cleanupTemporaryFiles()
        
        do {
            let schema = Schema([
                ChatSession.self,
                ChatMessage.self,
                MessageAttachment.self,
                HostPreset.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            AppLogger.storage.error("Failed to initialize persistent ModelContainer: \(error.localizedDescription, privacy: .private). Falling back to in-memory store.")
            do {
                let schema = Schema([
                    ChatSession.self,
                    ChatMessage.self,
                    MessageAttachment.self,
                    HostPreset.self
                ])
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                fatalError("Fatal: Could not initialize fallback in-memory ModelContainer: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(container)
    }
}
