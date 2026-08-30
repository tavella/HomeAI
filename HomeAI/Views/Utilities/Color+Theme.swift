import SwiftUI

extension Color {
    public static var themeBackground: Color {
        let theme = ConnectionManager.shared.appTheme
        if theme == "warm_navy" {
            return Color(red: 15/255, green: 23/255, blue: 42/255) // Slate 900
        }
        return Color(UIColor.systemGroupedBackground)
    }
    
    public static var themeSurface: Color {
        let theme = ConnectionManager.shared.appTheme
        if theme == "warm_navy" {
            return Color(red: 30/255, green: 41/255, blue: 59/255) // Slate 800
        }
        return Color(UIColor.secondarySystemGroupedBackground)
    }
    
    public static var themeSurfaceVariant: Color {
        let theme = ConnectionManager.shared.appTheme
        if theme == "warm_navy" {
            return Color(red: 51/255, green: 65/255, blue: 85/255) // Slate 700
        }
        return Color(UIColor.tertiarySystemGroupedBackground)
    }
    
    public static var themeText: Color {
        let theme = ConnectionManager.shared.appTheme
        if theme == "warm_navy" {
            return Color(red: 248/255, green: 250/255, blue: 252/255) // Slate 50
        }
        return Color.primary
    }
    
    public static var themeSecondaryText: Color {
        let theme = ConnectionManager.shared.appTheme
        if theme == "warm_navy" {
            return Color(red: 148/255, green: 163/255, blue: 184/255) // Slate 400
        }
        return Color.secondary
    }
}
