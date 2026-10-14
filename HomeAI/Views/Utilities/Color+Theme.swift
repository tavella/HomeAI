import SwiftUI

@MainActor
extension Color {
    public static var themeBackground: Color {
        let theme = ConnectionManager.shared.appTheme
        if theme == "warm_navy" {
            return Color(red: 13/255, green: 20/255, blue: 36/255) // Deep refined midnight navy
        } else if theme == "dark" {
            return Color(red: 18/255, green: 18/255, blue: 20/255) // Rich graphite dark
        } else if theme == "light" {
            return Color(red: 246/255, green: 247/255, blue: 251/255) // Crisp soft light
        }
        return Color(UIColor.systemGroupedBackground)
    }
    
    public static var themeSurface: Color {
        let theme = ConnectionManager.shared.appTheme
        if theme == "warm_navy" {
            return Color(red: 23/255, green: 34/255, blue: 58/255) // Elevated midnight slate
        } else if theme == "dark" {
            return Color(red: 30/255, green: 30/255, blue: 34/255) // Elevated dark card
        } else if theme == "light" {
            return Color.white
        }
        return Color(UIColor.secondarySystemGroupedBackground)
    }
    
    public static var themeSurfaceVariant: Color {
        let theme = ConnectionManager.shared.appTheme
        if theme == "warm_navy" {
            return Color(red: 33/255, green: 48/255, blue: 78/255) // Interactive navy cell surface
        } else if theme == "dark" {
            return Color(red: 42/255, green: 42/255, blue: 48/255) // Interactive dark cell surface
        } else if theme == "light" {
            return Color(red: 238/255, green: 241/255, blue: 246/255) // Clean contrasting light cell surface
        }
        return Color(UIColor.tertiarySystemGroupedBackground)
    }
    
    public static var themeText: Color {
        let theme = ConnectionManager.shared.appTheme
        if theme == "warm_navy" {
            return Color(red: 248/255, green: 250/255, blue: 255/255) // High contrast clean crisp white
        } else if theme == "dark" {
            return Color.white
        } else if theme == "light" {
            return Color(red: 15/255, green: 23/255, blue: 42/255) // High contrast rich dark slate
        }
        return Color.primary
    }
    
    public static var themeSecondaryText: Color {
        let theme = ConnectionManager.shared.appTheme
        if theme == "warm_navy" {
            return Color(red: 165/255, green: 180/255, blue: 206/255) // High-readability soft cyan-slate
        } else if theme == "dark" {
            return Color(red: 170/255, green: 173/255, blue: 182/255) // High-readability secondary silver
        } else if theme == "light" {
            return Color(red: 88/255, green: 98/255, blue: 118/255) // Balanced accessible slate grey
        }
        return Color.secondary
    }
}
