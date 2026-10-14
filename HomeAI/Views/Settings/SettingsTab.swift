import SwiftUI

public enum AppSettingsTab: String, CaseIterable, Identifiable {
    case server
    case models
    case prompts
    case general
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .server: return "Server"
        case .models: return "Models"
        case .prompts: return "Prompts"
        case .general: return "General"
        }
    }
    
    public var icon: String {
        switch self {
        case .server: return "antenna.radiowaves.left.and.right"
        case .models: return "cpu"
        case .prompts: return "text.quote"
        case .general: return "gearshape"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .server: return "Host & Connection"
        case .models: return "oMLX Model Management"
        case .prompts: return "System Instructions"
        case .general: return "Theme & Diagnostics"
        }
    }
}
