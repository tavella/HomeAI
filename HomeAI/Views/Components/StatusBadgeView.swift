import SwiftUI

public struct StatusBadgeView: View {
    public let isConnected: Bool
    public let isTesting: Bool
    @ObservedObject private var connection = ConnectionManager.shared
    
    public init(isConnected: Bool, isTesting: Bool) {
        self.isConnected = isConnected
        self.isTesting = isTesting
    }
    
    private var statusColor: Color {
        isTesting ? Color.orange : (isConnected ? Color(red: 10/255, green: 65/255, blue: 30/255) : Color.red)
    }
    
    private var iconColor: Color {
        if isTesting {
            return Color.orange
        } else if isConnected {
            return Color(red: 10/255, green: 65/255, blue: 30/255) // Deep pine green
        } else {
            return Color.red
        }
    }
    
    private var iconGlowColor: Color {
        if isTesting {
            return Color.orange.opacity(0.35)
        } else if isConnected {
            return Color(red: 10/255, green: 65/255, blue: 30/255).opacity(0.25)
        } else {
            return Color.red.opacity(0.35)
        }
    }
    
    private var textColor: Color {
        if isTesting {
            return Color.themeText
        } else if isConnected {
            return Color(red: 12/255, green: 24/255, blue: 28/255) // Deep dark charcoal slate (#0C181C)
        } else {
            return Color.themeSecondaryText
        }
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            // Glowing status indicator orb
            ZStack {
                Circle()
                    .fill(iconGlowColor)
                    .frame(width: 12, height: 12)
                
                Circle()
                    .fill(iconColor)
                    .frame(width: 7, height: 7)
            }
            
            Text(isTesting ? "Testing..." : (isConnected ? "Connected" : "Disconnected"))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(textColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Group {
                if isConnected {
                    Capsule()
                        .fill(Color(red: 135/255, green: 210/255, blue: 155/255)) // Rich soft green (darker & more green than pale mint)
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.6),
                                            Color(red: 60/255, green: 140/255, blue: 80/255).opacity(0.4)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
                } else if #available(iOS 26.0, *) {
                    Capsule()
                        .glassEffect(Glass.regular.tint(statusColor), in: Capsule())
                } else {
                    Capsule()
                        .fill(connection.appTheme == "warm_navy" ? Color(red: 30/255, green: 41/255, blue: 59/255).opacity(0.8) : Color.white.opacity(0.15))
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.4),
                                            Color.white.opacity(0.1),
                                            statusColor.opacity(0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 1.5)
                }
            }
        )
        .fixedSize(horizontal: true, vertical: false)
    }
}
