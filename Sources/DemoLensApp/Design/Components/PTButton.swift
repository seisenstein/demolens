import SwiftUI

public enum PTButtonVariant: String, CaseIterable {
    case `default`
    case destructive
    case outline
    case secondary
    case ghost
    case link

    var usesSurface: Bool {
        switch self {
        case .default, .destructive, .outline, .secondary:
            true
        case .ghost, .link:
            false
        }
    }

    func foregroundColor(isHovered: Bool) -> Color {
        switch self {
        case .default:
            PromptableTheme.Colors.primaryForeground
        case .destructive:
            PromptableTheme.Colors.destructiveForeground
        case .outline:
            PromptableTheme.Colors.foreground
        case .secondary:
            PromptableTheme.Colors.secondaryForeground
        case .ghost:
            isHovered ? PromptableTheme.Colors.accentForeground : PromptableTheme.Colors.foreground
        case .link:
            PromptableTheme.Colors.primary
        }
    }

    func backgroundColor(isHovered: Bool) -> Color {
        switch self {
        case .default:
            isHovered ? PromptableTheme.Colors.primaryButtonHover : PromptableTheme.Colors.primaryButton
        case .destructive:
            isHovered ? PromptableTheme.Colors.destructiveSolidHover : PromptableTheme.Colors.destructiveSolid
        case .outline:
            PromptableTheme.Colors.card
        case .secondary:
            isHovered ? PromptableTheme.Colors.secondary80 : PromptableTheme.Colors.secondary
        case .ghost:
            isHovered ? PromptableTheme.Colors.accent : .clear
        case .link:
            .clear
        }
    }

    func borderColor(isHovered: Bool) -> Color {
        switch self {
        case .default:
            isHovered ? PromptableTheme.Colors.primary30 : .clear
        case .outline:
            isHovered ? PromptableTheme.Colors.primary : PromptableTheme.Colors.border
        case .destructive, .secondary, .ghost, .link:
            .clear
        }
    }

    func shadow(isHovered: Bool) -> PromptableTheme.ShadowRecipe {
        switch self {
        case .default:
            isHovered ? PromptableTheme.Shadows.primaryButtonHover : PromptableTheme.Shadows.button
        case .destructive:
            PromptableTheme.Shadows.button
        case .outline, .secondary:
            PromptableTheme.Shadows.xs
        case .ghost, .link:
            PromptableTheme.ShadowRecipe()
        }
    }
}

public enum PTButtonSize: String, CaseIterable {
    case sm
    case md
    case lg
    case icon

    var height: CGFloat {
        switch self {
        case .sm:
            32
        case .md, .icon:
            36
        case .lg:
            40
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .sm:
            12
        case .md:
            16
        case .lg:
            32
        case .icon:
            0
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .sm:
            12
        case .md, .lg, .icon:
            14
        }
    }
}

public struct PTButtonTitleLabel: View {
    public var title: LocalizedStringKey
    public var systemImage: String?

    public init(_ title: LocalizedStringKey, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
            }

            Text(title)
        }
    }
}

public struct PTButton<Label: View>: View {
    private var action: () -> Void
    private var variant: PTButtonVariant
    private var size: PTButtonSize
    private var label: Label

    public init(
        variant: PTButtonVariant = .default,
        size: PTButtonSize = .md,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.action = action
        self.variant = variant
        self.size = size
        self.label = label()
    }

    public var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(PTButtonStyle(variant: variant, size: size))
    }
}

public extension PTButton where Label == PTButtonTitleLabel {
    init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        variant: PTButtonVariant = .default,
        size: PTButtonSize = .md,
        action: @escaping () -> Void
    ) {
        self.init(variant: variant, size: size, action: action) {
            PTButtonTitleLabel(title, systemImage: systemImage)
        }
    }
}

public struct PTButtonStyle: ButtonStyle {
    public var variant: PTButtonVariant
    public var size: PTButtonSize

    public init(variant: PTButtonVariant = .default, size: PTButtonSize = .md) {
        self.variant = variant
        self.size = size
    }

    public func makeBody(configuration: Configuration) -> some View {
        PTButtonStyleBody(configuration: configuration, variant: variant, size: size)
    }
}

public extension ButtonStyle where Self == PTButtonStyle {
    static func promptable(
        variant: PTButtonVariant = .default,
        size: PTButtonSize = .md
    ) -> PTButtonStyle {
        PTButtonStyle(variant: variant, size: size)
    }
}

private struct PTButtonStyleBody: View {
    let configuration: ButtonStyle.Configuration
    let variant: PTButtonVariant
    let size: PTButtonSize

    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool
    @State private var isHovered = false

    private var isVisuallyHovered: Bool {
        isEnabled && isHovered
    }

    var body: some View {
        sizedLabel
            .font(.manrope(size: size.fontSize, weight: .medium))
            .lineLimit(1)
            .foregroundStyle(variant.foregroundColor(isHovered: isVisuallyHovered))
            .background(buttonBackground)
            .overlay(alignment: .bottom) {
                if variant == .link, isVisuallyHovered {
                    Rectangle()
                        .fill(PromptableTheme.Colors.primary)
                        .frame(height: 1)
                        .padding(.horizontal, size.horizontalPadding)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: PromptableTheme.Radius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(isEnabled ? 1 : 0.5)
            .ptFocusRing(isFocused, cornerRadius: PromptableTheme.Radius.md)
            .focusable(isEnabled && variant != .link)
            .focused($isFocused)
            .allowsHitTesting(isEnabled)
            .onHover { isHovered = isEnabled && $0 }
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isVisuallyHovered)
    }

    @ViewBuilder
    private var sizedLabel: some View {
        if size == .icon {
            configuration.label
                .frame(width: size.height, height: size.height)
        } else {
            configuration.label
                .frame(height: size.height)
                .padding(.horizontal, size.horizontalPadding)
        }
    }

    @ViewBuilder
    private var buttonBackground: some View {
        if variant.usesSurface {
            PTRoundedSurface(
                fill: variant.backgroundColor(isHovered: isVisuallyHovered),
                border: variant.borderColor(isHovered: isVisuallyHovered),
                cornerRadius: PromptableTheme.Radius.md,
                shadow: variant.shadow(isHovered: isVisuallyHovered),
                hairline: variant.shadow(isHovered: isVisuallyHovered).insetHairline
            )
        } else if variant == .ghost, isVisuallyHovered {
            RoundedRectangle(cornerRadius: PromptableTheme.Radius.md, style: .continuous)
                .fill(variant.backgroundColor(isHovered: true))
        } else {
            Color.clear
        }
    }
}
