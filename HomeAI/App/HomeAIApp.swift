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
            fatalError("Could not initialize SwiftData ModelContainer: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(container)
    }
}
