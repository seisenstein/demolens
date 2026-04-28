import SwiftUI

public struct PTCard<Content: View>: View {
    public var padding: CGFloat
    public var cornerRadius: CGFloat
    private var content: Content

    public init(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = PromptableTheme.Radius.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .foregroundStyle(PromptableTheme.Colors.cardForeground)
            .background {
                PTRoundedSurface(
                    fill: PromptableTheme.Colors.card,
                    border: PromptableTheme.Colors.border,
                    cornerRadius: cornerRadius,
                    shadow: PromptableTheme.Shadows.sm,
                    hairline: PromptableTheme.Colors.hairline
                )
            }
    }
}

public struct PTCardBackground: ViewModifier {
    public var cornerRadius: CGFloat
    public var shadow: PromptableTheme.ShadowRecipe

    public init(
        cornerRadius: CGFloat = PromptableTheme.Radius.lg,
        shadow: PromptableTheme.ShadowRecipe = PromptableTheme.Shadows.sm
    ) {
        self.cornerRadius = cornerRadius
        self.shadow = shadow
    }

    public func body(content: Content) -> some View {
        content
            .foregroundStyle(PromptableTheme.Colors.cardForeground)
            .background {
                PTRoundedSurface(
                    fill: PromptableTheme.Colors.card,
                    border: PromptableTheme.Colors.border,
                    cornerRadius: cornerRadius,
                    shadow: shadow,
                    hairline: shadow.insetHairline
                )
            }
    }
}

public extension View {
    func ptCardBackground(
        cornerRadius: CGFloat = PromptableTheme.Radius.lg,
        shadow: PromptableTheme.ShadowRecipe = PromptableTheme.Shadows.sm
    ) -> some View {
        modifier(PTCardBackground(cornerRadius: cornerRadius, shadow: shadow))
    }
}
