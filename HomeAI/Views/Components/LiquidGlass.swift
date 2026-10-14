import SwiftUI

// MARK: - Liquid Glass Design System (iOS 27.x Compatible)

/// A view modifier providing an optical liquid glass appearance with frosted translucency,
/// multi-stop specular edge reflections, and subtle ambient shadows.
public struct LiquidGlassModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var connection = ConnectionManager.shared
    
    public var cornerRadius: CGFloat
    public var strokeOpacity: Double
    public var isInteractive: Bool
    public var tint: Color?
    
    public init(
        cornerRadius: CGFloat = 18,
        strokeOpacity: Double = 0.35,
        isInteractive: Bool = false,
        tint: Color? = nil
    ) {
        self.cornerRadius = cornerRadius
        self.strokeOpacity = strokeOpacity
        self.isInteractive = isInteractive
        self.tint = tint
    }
    
    public func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let baseGlass: Glass = {
                var g = Glass.regular
                if let tint = tint {
                    g = g.tint(tint)
                }
                if isInteractive {
                    g = g.interactive(true)
                }
                return g
            }()
            content
                .glassEffect(baseGlass, in: shape)
        } else {
            content
                .background(
                    glassBackground
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                )
                .overlay(
                    specularBorder
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                )
                .shadow(
                    color: shadowColor,
                    radius: isInteractive ? 12 : 8,
                    x: 0,
                    y: isInteractive ? 5 : 3
                )
        }
    }
    
    @ViewBuilder
    private var glassBackground: some View {
        if connection.appTheme == "warm_navy" {
            ZStack {
                Color(red: 22/255, green: 32/255, blue: 51/255).opacity(0.85)
                if let tint = tint {
                    tint.opacity(0.15)
                }
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.06),
                                Color.clear,
                                Color.blue.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        } else {
            if #available(iOS 26.0, *) {
                let glassShape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                let baseGlass: Glass = {
                    var g = Glass.regular
                    if let tint = tint {
                        g = g.tint(tint)
                    }
                    if isInteractive {
                        g = g.interactive(true)
                    }
                    return g
                }()
                glassShape
                    .glassEffect(baseGlass, in: glassShape)
            } else {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    
                    if let tint = tint {
                        tint.opacity(colorScheme == .dark ? 0.12 : 0.08)
                    }
                    
                    if colorScheme == .light {
                        Color.white.opacity(0.35)
                    }
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.4),
                                    Color.clear,
                                    Color.blue.opacity(colorScheme == .dark ? 0.06 : 0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
        }
    }
    
    private var specularBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(specularTopOpacity),
                        Color.white.opacity(0.12),
                        Color.clear,
                        (tint ?? Color.blue).opacity(specularBottomOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
    
    private var specularTopOpacity: Double {
        if connection.appTheme == "warm_navy" {
            return 0.28 * strokeOpacity
        } else if colorScheme == .dark {
            return 0.32 * strokeOpacity
        } else {
            return 0.75 * strokeOpacity
        }
    }
    
    private var specularBottomOpacity: Double {
        return (colorScheme == .dark ? 0.22 : 0.15) * strokeOpacity
    }
    
    private var shadowColor: Color {
        if connection.appTheme == "warm_navy" {
            return Color.black.opacity(0.35)
        } else if colorScheme == .dark {
            return Color.black.opacity(0.3)
        } else {
            return Color.black.opacity(0.06)
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies the signature iOS 27.x Liquid Glass visual styling.
    public func liquidGlass(
        cornerRadius: CGFloat = 18,
        strokeOpacity: Double = 1.0,
        isInteractive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        self.modifier(
            LiquidGlassModifier(
                cornerRadius: cornerRadius,
                strokeOpacity: strokeOpacity,
                isInteractive: isInteractive,
                tint: tint
            )
        )
    }
}

// MARK: - Liquid Glass Card Container

public struct LiquidGlassCard<Content: View, HeaderTrailing: View>: View {
    public let icon: String?
    public let title: String?
    public let subtitle: String?
    public let headerTrailing: HeaderTrailing
    public let content: Content
    public let cornerRadius: CGFloat
    public let tint: Color?
    
    public init(
        icon: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        cornerRadius: CGFloat = 18,
        tint: Color? = nil,
        @ViewBuilder headerTrailing: () -> HeaderTrailing,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.headerTrailing = headerTrailing()
        self.content = content()
        self.cornerRadius = cornerRadius
        self.tint = tint
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || icon != nil {
                HStack(alignment: .center, spacing: 8) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(tint ?? Color.blue)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill((tint ?? Color.blue).opacity(0.15))
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let title = title {
                            Text(title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color.themeText)
                        }
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.caption2)
                                .foregroundColor(Color.themeSecondaryText)
                        }
                    }
                    
                    Spacer()
                    
                    headerTrailing
                }
                .padding(.bottom, 2)
            }
            
            content
        }
        .padding(14)
        .liquidGlass(cornerRadius: cornerRadius, strokeOpacity: 1.0, isInteractive: false, tint: tint)
    }
}

extension LiquidGlassCard where HeaderTrailing == EmptyView {
    public init(
        icon: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        cornerRadius: CGFloat = 18,
        tint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            icon: icon,
            title: title,
            subtitle: subtitle,
            cornerRadius: cornerRadius,
            tint: tint,
            headerTrailing: { EmptyView() },
            content: content
        )
    }
}

// MARK: - Liquid Glass Segmented Pill Bar

public struct LiquidGlassSegmentedPicker<Tab: Hashable & Identifiable>: View {
    public let tabs: [Tab]
    @Binding public var selection: Tab
    public let titleForTab: (Tab) -> String
    public let iconForTab: (Tab) -> String
    public let badgeForTab: ((Tab) -> String?)?
    
    @Namespace private var pillNamespace
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var connection = ConnectionManager.shared
    
    public init(
        tabs: [Tab],
        selection: Binding<Tab>,
        titleForTab: @escaping (Tab) -> String,
        iconForTab: @escaping (Tab) -> String,
        badgeForTab: ((Tab) -> String?)? = nil
    ) {
        self.tabs = tabs
        self._selection = selection
        self.titleForTab = titleForTab
        self.iconForTab = iconForTab
        self.badgeForTab = badgeForTab
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs) { tab in
                let isSelected = selection == tab
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        selection = tab
                    }
                    let generator = UISelectionFeedbackGenerator()
                    generator.selectionChanged()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: iconForTab(tab))
                            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        
                        Text(titleForTab(tab))
                            .font(.caption)
                            .fontWeight(isSelected ? .semibold : .medium)
                            .lineLimit(1)
                        
                        if let badge = badgeForTab?(tab) {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(isSelected ? Color.blue : Color.secondary.opacity(0.2)))
                                .foregroundColor(isSelected ? .white : .secondary)
                        }
                    }
                    .foregroundColor(isSelected ? (connection.appTheme == "warm_navy" ? .white : Color.themeText) : Color.themeSecondaryText)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selectedPillFill)
                                .matchedGeometryEffect(id: "ActiveTabPill", in: pillNamespace)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.4),
                                                    Color.white.opacity(0.1),
                                                    Color.blue.opacity(0.2)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("SettingsTab_\(titleForTab(tab))")
            }
        }
        .padding(4)
        .liquidGlass(cornerRadius: 16, strokeOpacity: 0.8, isInteractive: true)
    }
    
    private var selectedPillFill: some ShapeStyle {
        if connection.appTheme == "warm_navy" {
            return AnyShapeStyle(Color.blue.opacity(0.28))
        } else if colorScheme == .dark {
            return AnyShapeStyle(Color.white.opacity(0.15))
        } else {
            return AnyShapeStyle(Color.white.opacity(0.85))
        }
    }
}

// MARK: - Liquid Glass Badge

public struct LiquidGlassBadge: View {
    public let text: String
    public let icon: String?
    public let tint: Color
    
    public init(text: String, icon: String? = nil, tint: Color = .blue) {
        self.text = text
        self.icon = icon
        self.tint = tint
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(
            Group {
                if #available(iOS 26.0, *) {
                    Capsule()
                        .glassEffect(Glass.regular.tint(tint), in: Capsule())
                } else {
                    Capsule()
                        .fill(tint.opacity(0.16))
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            tint.opacity(0.4)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.75
                                )
                        )
                }
            }
        )
        .foregroundColor(tint)
    }
}

// MARK: - Floating Glass Bottom Island Navigation (Option 4)

public struct LiquidGlassFloatingBottomBar<Tab: Hashable & Identifiable>: View {
    public let tabs: [Tab]
    @Binding public var selection: Tab
    public let titleForTab: (Tab) -> String
    public let iconForTab: (Tab) -> String
    public let badgeForTab: ((Tab) -> String?)?
    public let badgeColorForTab: ((Tab) -> Color)?
    
    @Namespace private var islandPillNamespace
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var connection = ConnectionManager.shared
    @State private var barWidth: CGFloat = 0
    @State private var isInteracting: Bool = false
    
    public init(
        tabs: [Tab],
        selection: Binding<Tab>,
        titleForTab: @escaping (Tab) -> String,
        iconForTab: @escaping (Tab) -> String,
        badgeForTab: ((Tab) -> String?)? = nil,
        badgeColorForTab: ((Tab) -> Color)? = nil
    ) {
        self.tabs = tabs
        self._selection = selection
        self.titleForTab = titleForTab
        self.iconForTab = iconForTab
        self.badgeForTab = badgeForTab
        self.badgeColorForTab = badgeColorForTab
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            ForEach(tabs) { tab in
                let isSelected = selection == tab
                Button {
                    selectTabDirectly(tab)
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            Image(systemName: iconForTab(tab))
                                .font(.system(size: 17, weight: isSelected ? .bold : .medium))
                            
                            if let badge = badgeForTab?(tab) {
                                let badgeColor = badgeColorForTab?(tab) ?? Color.cyan
                                if badge == "●" {
                                    Circle()
                                        .fill(badgeColor)
                                        .frame(width: 7, height: 7)
                                        .shadow(color: badgeColor.opacity(0.8), radius: 3)
                                        .offset(x: 10, y: -7)
                                } else {
                                    Text(badge)
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(badgeColor))
                                        .offset(x: 12, y: -8)
                                }
                            }
                        }
                        
                        Text(titleForTab(tab))
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(isSelected ? activeTextColor : Color.themeSecondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                    .background {
                        if isSelected {
                            activePillView
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("FloatingIslandTab_\(titleForTab(tab))")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            ZStack {
                if #available(iOS 26.0, *) {
                    Capsule()
                        .glassEffect(Glass.regular.interactive(true), in: Capsule())
                } else {
                    Capsule()
                        .fill(islandBackgroundFill)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.35),
                                    Color.clear,
                                    Color.blue.opacity(colorScheme == .dark ? 0.05 : 0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                GeometryReader { geo in
                    Color.clear
                        .onAppear { barWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, newWidth in barWidth = newWidth }
                }
            }
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? (isInteracting ? 0.6 : 0.4) : 0.8),
                            Color.white.opacity(0.12),
                            Color.cyan.opacity(isInteracting ? 0.45 : 0.25),
                            Color.blue.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.14), radius: 18, x: 0, y: 8)
        .shadow(color: Color.blue.opacity(colorScheme == .dark ? (isInteracting ? 0.25 : 0.15) : 0.05), radius: 24, x: 0, y: 10)
        .contentShape(Capsule())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isInteracting = true
                    selectTab(at: value.location.x)
                }
                .onEnded { _ in
                    isInteracting = false
                }
        )
    }
    
    @ViewBuilder
    private var activePillView: some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .glassEffect(Glass.regular.tint(.blue), in: Capsule())
                .matchedGeometryEffect(id: "FloatingIslandActivePill", in: islandPillNamespace)
        } else {
            Capsule()
                .fill(activePillFill)
                .matchedGeometryEffect(id: "FloatingIslandActivePill", in: islandPillNamespace)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? (isInteracting ? 0.6 : 0.45) : 0.7),
                                    Color.cyan.opacity(isInteracting ? 0.5 : 0.3),
                                    Color.blue.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: Color.blue.opacity(colorScheme == .dark ? (isInteracting ? 0.45 : 0.35) : 0.2), radius: 8, x: 0, y: 2)
        }
    }
    
    private func selectTab(at locationX: CGFloat) {
        guard !tabs.isEmpty, barWidth > 0 else { return }
        let horizontalPadding: CGFloat = 8
        let usableWidth = max(1, barWidth - (horizontalPadding * 2))
        let tabWidth = usableWidth / CGFloat(tabs.count)
        let relativeX = locationX - horizontalPadding
        let rawIndex = Int(floor(relativeX / tabWidth))
        let clampedIndex = max(0, min(tabs.count - 1, rawIndex))
        let targetTab = tabs[clampedIndex]
        
        if targetTab != selection {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                selection = targetTab
            }
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }
    
    private func selectTabDirectly(_ tab: Tab) {
        if selection != tab {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                selection = tab
            }
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }
    
    private var activeTextColor: Color {
        if connection.appTheme == "warm_navy" {
            return .cyan
        } else if colorScheme == .dark {
            return Color(red: 0.4, green: 0.8, blue: 1.0)
        } else {
            return .blue
        }
    }
    
    private var activeGlassTint: Color {
        if connection.appTheme == "warm_navy" {
            return .cyan
        } else if colorScheme == .dark {
            return Color(red: 0.2, green: 0.6, blue: 1.0)
        } else {
            return .blue
        }
    }
    
    private var activePillFill: some ShapeStyle {
        if connection.appTheme == "warm_navy" {
            return AnyShapeStyle(Color.cyan.opacity(0.25))
        } else if colorScheme == .dark {
            return AnyShapeStyle(Color.blue.opacity(0.25))
        } else {
            return AnyShapeStyle(Color.white.opacity(0.85))
        }
    }
    
    private var islandBackgroundFill: some ShapeStyle {
        if connection.appTheme == "warm_navy" {
            return AnyShapeStyle(Color(red: 18/255, green: 26/255, blue: 44/255).opacity(0.88))
        } else {
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }
}

// MARK: - Floating Island Container Modifier

public struct LiquidGlassFloatingIslandModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var connection = ConnectionManager.shared
    
    public var cornerRadius: CGFloat
    public var tint: Color?
    
    public init(cornerRadius: CGFloat = 24, tint: Color? = nil) {
        self.cornerRadius = cornerRadius
        self.tint = tint
    }
    
    public func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let glass = tint != nil ? Glass.regular.tint(tint) : Glass.regular
            content
                .glassEffect(glass, in: shape)
        } else {
            content
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(backgroundMaterial)
                        
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.07 : 0.3),
                                        Color.clear,
                                        (tint ?? Color.blue).opacity(colorScheme == .dark ? 0.05 : 0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.38 : 0.75),
                                    Color.white.opacity(0.1),
                                    (tint ?? Color.blue).opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.1
                        )
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.1), radius: 14, x: 0, y: 6)
        }
    }
    
    private var backgroundMaterial: some ShapeStyle {
        if connection.appTheme == "warm_navy" {
            return AnyShapeStyle(Color(red: 22/255, green: 32/255, blue: 51/255).opacity(0.85))
        } else {
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }
}

// MARK: - Floating Capsule Pill Button

public struct LiquidGlassCapsulePill: View {
    public let title: String
    public let icon: String?
    public let isSelected: Bool
    public let tint: Color
    public let action: () -> Void
    
    public init(
        title: String,
        icon: String? = nil,
        isSelected: Bool = false,
        tint: Color = .blue,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.tint = tint
        self.action = action
    }
       public var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                HStack(spacing: 6) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    }
                    Text(title)
                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundColor(isSelected ? tint : Color.themeText)
            }
            .glassButtonStyle(tint: isSelected ? tint : nil)
        } else {
            Button(action: action) {
                HStack(spacing: 6) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    }
                    Text(title)
                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? tint.opacity(0.22) : Color.primary.opacity(0.06))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isSelected ? 0.5 : 0.2),
                                    isSelected ? tint.opacity(0.4) : Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .foregroundColor(isSelected ? tint : Color.themeText)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Message Bubble Liquid Glass Modifier

public struct LiquidGlassMessageBubbleModifier: ViewModifier {
    public let isUser: Bool
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var connection = ConnectionManager.shared
    
    public init(isUser: Bool) {
        self.isUser = isUser
    }
    
    public func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            let shape = RoundedRectangle(cornerRadius: 19, style: .continuous)
            if isUser {
                content
                    .glassEffect(Glass.regular.tint(.blue), in: shape)
            } else {
                content
                    .glassEffect(Glass.regular, in: shape)
            }
        } else {
            if isUser {
                content
                    .background(
                        ZStack {
                            LinearGradient(
                                colors: [
                                    Color(red: 0.12, green: 0.52, blue: 0.98),
                                    Color(red: 0.05, green: 0.40, blue: 0.92)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.55),
                                        Color.white.opacity(0.15),
                                        Color.blue.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 3)
            } else {
                content
                    .background(
                        ZStack {
                            if connection.appTheme == "warm_navy" {
                                Color(red: 24/255, green: 34/255, blue: 54/255).opacity(0.85)
                            } else {
                                Rectangle().fill(.ultraThinMaterial)
                            }
                            
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.06 : 0.35),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.28 : 0.6),
                                        Color.white.opacity(0.08),
                                        Color.blue.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06), radius: 6, x: 0, y: 2)
            }
        }
    }
}

extension View {
    /// Styles a chat message bubble with signature iOS 27 Liquid Glass optics.
    public func liquidGlassMessageBubble(isUser: Bool) -> some View {
        self.modifier(LiquidGlassMessageBubbleModifier(isUser: isUser))
    }
    
    /// Wraps the view in a floating detached liquid glass island.
    public func liquidGlassFloatingIsland(cornerRadius: CGFloat = 24, tint: Color? = nil) -> some View {
        self.modifier(LiquidGlassFloatingIslandModifier(cornerRadius: cornerRadius, tint: tint))
    }
    
    /// Applies native Apple Liquid Glass button style on iOS 26+ with standard fallback.
    @ViewBuilder
    public func glassButtonStyle(tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            if let tint = tint {
                self.buttonStyle(.glass(.regular.tint(tint)))
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            self.buttonStyle(.bordered)
        }
    }
    
    /// Applies native Apple Liquid Glass prominent button style on iOS 26+ with standard fallback.
    @ViewBuilder
    public func glassProminentButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}

