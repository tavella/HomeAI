import SwiftUI

public struct StatusBadgeView: View {
    public let isConnected: Bool
    public let isTesting: Bool
    @ObservedObject private var connection = ConnectionManager.shared
    
    public init(isConnected: Bool, isTesting: Bool) {
        self.isConnected = isConnected
        self.isTesting = isTesting
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isTesting ? Color.orange : (isConnected ? Color.green : Color.red))
                .frame(width: 8, height: 8)
            
            Text(isTesting ? "Testing..." : (isConnected ? "Connected" : "Disconnected"))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color.themeSecondaryText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(connection.appTheme == "warm_navy" ? Color.themeSurfaceVariant : Color(.tertiarySystemFill)))
        .fixedSize(horizontal: true, vertical: false)
    }
}
