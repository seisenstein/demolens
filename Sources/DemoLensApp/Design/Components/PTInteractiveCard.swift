import SwiftUI

public struct PTInteractiveCard<Content: View>: View {
    public var padding: CGFloat
    public var cornerRadius: CGFloat
    private var action: () -> Void
    private var content: Content

    public init(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = PromptableTheme.Radius.lg,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.action = action
        self.content = content()
    }

    public var body: some View {
        Button(action: action) {
            content
                .padding(padding)
        }
        .buttonStyle(PTInteractiveCardStyle(cornerRadius: cornerRadius))
    }
}

public struct PTInteractiveCardStyle: ButtonStyle {
    public var cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = PromptableTheme.Radius.lg) {
        self.cornerRadius = cornerRadius
    }

    public func makeBody(configuration: Configuration) -> some View {
        PTInteractiveCardStyleBody(configuration: configuration, cornerRadius: cornerRadius)
    }
}

public extension ButtonStyle where Self == PTInteractiveCardStyle {
    static func promptableInteractiveCard(
        cornerRadius: CGFloat = PromptableTheme.Radius.lg
    ) -> PTInteractiveCardStyle {
        PTInteractiveCardStyle(cornerRadius: cornerRadius)
    }
}

private struct PTInteractiveCardStyleBody: View {
    let configuration: ButtonStyle.Configuration
    let cornerRadius: CGFloat

    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool
    @State private var isHovered = false

    private var isVisuallyHovered: Bool {
        isEnabled && isHovered
    }

    var body: some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(PromptableTheme.Colors.cardForeground)
            .background {
                PTRoundedSurface(
                    fill: PromptableTheme.Colors.card,
                    border: isVisuallyHovered ? PromptableTheme.Colors.primary30 : PromptableTheme.Colors.border,
                    cornerRadius: cornerRadius,
                    shadow: isVisuallyHovered ? PromptableTheme.Shadows.md : PromptableTheme.Shadows.sm,
                    hairline: PromptableTheme.Colors.hairline
                )
            }
            .overlay {
                if isVisuallyHovered {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(PromptableTheme.Colors.primary5)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .offset(y: isVisuallyHovered ? -1 : 0)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(isEnabled ? 1 : 0.5)
            .ptFocusRing(isFocused, cornerRadius: cornerRadius)
            .focusable(isEnabled)
            .focused($isFocused)
            .allowsHitTesting(isEnabled)
            .onHover { isHovered = isEnabled && $0 }
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isVisuallyHovered)
    }
}
