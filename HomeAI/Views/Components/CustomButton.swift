import SwiftUI

public struct PrimaryButton: View {
    public let title: String
    public let icon: String?
    public let isLoading: Bool
    public let action: () -> Void
    
    public init(title: String, icon: String? = nil, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                } else if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .glassProminentButtonStyle()
        .disabled(isLoading)
    }
}
