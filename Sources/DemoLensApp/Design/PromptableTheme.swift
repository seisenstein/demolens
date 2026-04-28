import CoreText
import Foundation
import SwiftUI

public enum PromptableTheme {
    public enum Colors {
        public static var background: Color { rgb(1, 3, 3) }
        public static var background50: Color { rgb(1, 3, 3, 0.50) }
        public static var background60: Color { rgb(1, 3, 3, 0.60) }
        public static var background80: Color { rgb(1, 3, 3, 0.80) }
        public static var background90: Color { rgb(1, 3, 3, 0.90) }

        public static var foreground: Color { rgb(194, 193, 189) }
        public static var card: Color { rgb(4, 10, 12) }
        public static var card50: Color { rgb(4, 10, 12, 0.50) }
        public static var cardForeground: Color { rgb(249, 248, 245) }
        public static var surfaceElevated: Color { rgb(8, 17, 19) }
        public static var popover: Color { rgb(8, 17, 19) }
        public static var popoverForeground: Color { rgb(228, 228, 228) }

        public static var hairline: Color { rgb(255, 255, 255, 0.05) }
        public static var hairlineStrong: Color { rgb(255, 255, 255, 0.08) }

        public static var primary: Color { rgb(44, 138, 157) }
        public static var primaryForeground: Color { rgb(248, 248, 248) }
        public static var primaryHover: Color { rgb(0, 112, 130) }
        public static var primaryActive: Color { rgb(12, 14, 15) }
        public static var primaryButton: Color { rgb(21, 124, 142) }
        public static var primaryButtonHover: Color { rgb(0, 103, 121) }
        public static var primary5: Color { rgb(44, 138, 157, 0.05) }
        public static var primary8: Color { rgb(44, 138, 157, 0.08) }
        public static var primary10: Color { rgb(44, 138, 157, 0.10) }
        public static var primary20: Color { rgb(44, 138, 157, 0.20) }
        public static var primary30: Color { rgb(44, 138, 157, 0.30) }
        public static var primary40: Color { rgb(44, 138, 157, 0.40) }
        public static var primary50: Color { rgb(44, 138, 157, 0.50) }
        public static var primary80: Color { rgb(44, 138, 157, 0.80) }
        public static var primary90: Color { rgb(44, 138, 157, 0.90) }
        public static var primaryBackgroundSubtle: Color { primary8 }
        public static var primaryBorderSubtle: Color { primary30 }

        public static var secondary: Color { rgb(8, 22, 25) }
        public static var secondary80: Color { rgb(8, 22, 25, 0.80) }
        public static var secondaryForeground: Color { primary }

        public static var muted: Color { rgb(27, 27, 27) }
        public static var muted10: Color { rgb(27, 27, 27, 0.10) }
        public static var muted20: Color { rgb(27, 27, 27, 0.20) }
        public static var muted30: Color { rgb(27, 27, 27, 0.30) }
        public static var muted50: Color { rgb(27, 27, 27, 0.50) }
        public static var mutedForeground: Color { rgb(181, 180, 173) }
        public static var mutedForegroundDisabled: Color { rgb(129, 128, 125) }
        public static var mutedSubtle: Color { rgb(103, 103, 103) }

        public static var accent: Color { rgb(18, 18, 18) }
        public static var accentForeground: Color { rgb(246, 245, 241) }
        public static var accent5: Color { rgb(18, 18, 18, 0.05) }
        public static var accent10: Color { rgb(18, 18, 18, 0.10) }
        public static var accent50: Color { rgb(18, 18, 18, 0.50) }

        public static var destructive: Color { rgb(248, 85, 76) }
        public static var destructiveForeground: Color { rgb(245, 245, 245) }
        public static var destructive5: Color { rgb(248, 85, 76, 0.05) }
        public static var destructive10: Color { rgb(248, 85, 76, 0.10) }
        public static var destructive20: Color { rgb(248, 85, 76, 0.20) }
        public static var destructive30: Color { rgb(248, 85, 76, 0.30) }
        public static var destructive40: Color { rgb(248, 85, 76, 0.40) }
        public static var destructive50: Color { rgb(248, 85, 76, 0.50) }
        public static var destructive80: Color { rgb(248, 85, 76, 0.80) }
        public static var destructive90: Color { rgb(248, 85, 76, 0.90) }
        public static var destructiveSolid: Color { rgb(212, 12, 25) }
        public static var destructiveSolidHover: Color { rgb(194, 0, 0) }

        public static var border: Color { rgb(58, 58, 58) }
        public static var border30: Color { rgb(58, 58, 58, 0.30) }
        public static var border40: Color { rgb(58, 58, 58, 0.40) }
        public static var border50: Color { rgb(58, 58, 58, 0.50) }
        public static var border60: Color { rgb(58, 58, 58, 0.60) }

        public static var input: Color { border }
        public static var input30: Color { border30 }
        public static var input50: Color { border50 }

        public static var ring: Color { primary }
        public static var ring50: Color { primary50 }

        public static var chart1: Color { rgb(50, 159, 180) }
        public static var chart2: Color { rgb(42, 123, 139) }
        public static var chart3: Color { rgb(36, 91, 102) }
        public static var chart4: Color { rgb(24, 56, 63) }
        public static var chart5: Color { rgb(8, 22, 25) }

        public static var sidebar: Color { rgb(31, 31, 31) }
        public static var sidebarForeground: Color { rgb(194, 193, 189) }
        public static var sidebarPrimary: Color { rgb(53, 53, 53) }
        public static var sidebarPrimaryForeground: Color { rgb(252, 252, 252) }
        public static var sidebarAccent: Color { rgb(15, 15, 15) }
        public static var sidebarAccentForeground: Color { rgb(194, 193, 189) }
        public static var sidebarBorder: Color { rgb(235, 235, 235) }
        public static var sidebarRing: Color { rgb(180, 180, 180) }

        public static func rgb(_ red: Int, _ green: Int, _ blue: Int, _ opacity: Double = 1) -> Color {
            Color(
                .sRGB,
                red: Double(red) / 255,
                green: Double(green) / 255,
                blue: Double(blue) / 255,
                opacity: opacity
            )
        }
    }

    public enum Radius {
        public static let sm: CGFloat = 4
        public static let md: CGFloat = 6
        public static let base: CGFloat = 8
        public static let lg: CGFloat = 12
        public static let pill = Capsule()
    }

    public struct DropShadow {
        public var color: Color
        public var x: CGFloat
        public var y: CGFloat
        public var blur: CGFloat
        public var spread: CGFloat

        public init(color: Color, x: CGFloat, y: CGFloat, blur: CGFloat, spread: CGFloat = 0) {
            self.color = color
            self.x = x
            self.y = y
            self.blur = blur
            self.spread = spread
        }
    }

    public struct ShadowRecipe {
        public var insetHairline: Color?
        public var dropShadow: DropShadow?

        public init(insetHairline: Color? = nil, dropShadow: DropShadow? = nil) {
            self.insetHairline = insetHairline
            self.dropShadow = dropShadow
        }
    }

    public enum Shadows {
        public static var twoXS: ShadowRecipe {
            ShadowRecipe(insetHairline: Colors.rgb(255, 255, 255, 0.04))
        }

        public static var xs: ShadowRecipe {
            ShadowRecipe(insetHairline: Colors.hairline)
        }

        public static var sm: ShadowRecipe {
            ShadowRecipe(
                insetHairline: Colors.hairline,
                dropShadow: DropShadow(color: Colors.rgb(0, 0, 0, 0.35), x: 0, y: 1, blur: 2)
            )
        }

        public static var base: ShadowRecipe {
            ShadowRecipe(
                insetHairline: Colors.hairline,
                dropShadow: DropShadow(color: Colors.rgb(0, 0, 0, 0.40), x: 0, y: 2, blur: 4, spread: -1)
            )
        }

        public static var md: ShadowRecipe {
            ShadowRecipe(
                insetHairline: Colors.hairline,
                dropShadow: DropShadow(color: Colors.rgb(0, 0, 0, 0.45), x: 0, y: 4, blur: 8, spread: -2)
            )
        }

        public static var lg: ShadowRecipe {
            ShadowRecipe(
                insetHairline: Colors.rgb(255, 255, 255, 0.06),
                dropShadow: DropShadow(color: Colors.rgb(0, 0, 0, 0.50), x: 0, y: 12, blur: 24, spread: -4)
            )
        }

        public static var xl: ShadowRecipe {
            ShadowRecipe(
                insetHairline: Colors.rgb(255, 255, 255, 0.06),
                dropShadow: DropShadow(color: Colors.rgb(0, 0, 0, 0.55), x: 0, y: 24, blur: 48, spread: -8)
            )
        }

        public static var twoXL: ShadowRecipe {
            ShadowRecipe(
                insetHairline: Colors.hairlineStrong,
                dropShadow: DropShadow(color: Colors.rgb(0, 0, 0, 0.65), x: 0, y: 40, blur: 80, spread: -16)
            )
        }

        public static var button: ShadowRecipe {
            ShadowRecipe(
                insetHairline: Colors.hairlineStrong,
                dropShadow: DropShadow(color: Colors.rgb(0, 0, 0, 0.35), x: 0, y: 1, blur: 2)
            )
        }

        public static var primaryButtonHover: ShadowRecipe {
            ShadowRecipe(
                insetHairline: Colors.hairlineStrong,
                dropShadow: DropShadow(color: Colors.primary40, x: 0, y: 4, blur: 12, spread: -2)
            )
        }
    }
}

public struct PromptableFontRegistrationFailure {
    public var url: URL
    public var error: NSError?

    public init(url: URL, error: NSError?) {
        self.url = url
        self.error = error
    }
}

public struct PromptableFontRegistrationReport {
    public var registeredURLs: [URL]
    public var alreadyRegisteredURLs: [URL]
    public var failedFonts: [PromptableFontRegistrationFailure]
    public var missingPostScriptNames: [String]

    public var isComplete: Bool {
        failedFonts.isEmpty && missingPostScriptNames.isEmpty
    }

    public init(
        registeredURLs: [URL],
        alreadyRegisteredURLs: [URL],
        failedFonts: [PromptableFontRegistrationFailure],
        missingPostScriptNames: [String]
    ) {
        self.registeredURLs = registeredURLs
        self.alreadyRegisteredURLs = alreadyRegisteredURLs
        self.failedFonts = failedFonts
        self.missingPostScriptNames = missingPostScriptNames
    }
}

public enum PromptableFonts {
    public static let manropeRegular = "Manrope-Regular"
    public static let manropeMedium = "Manrope-Medium"
    public static let manropeSemiBold = "Manrope-SemiBold"
    public static let manropeBold = "Manrope-Bold"
    public static let jetBrainsMonoRegular = "JetBrainsMono-Regular"
    public static let jetBrainsMonoMedium = "JetBrainsMono-Medium"

    public static let expectedPostScriptNames: Set<String> = [
        manropeRegular,
        manropeMedium,
        manropeSemiBold,
        manropeBold,
        jetBrainsMonoRegular,
        jetBrainsMonoMedium
    ]

    @discardableResult
    public static func registerBundledFonts(
        in bundle: Bundle = .main,
        fontsDirectory: String = "Fonts"
    ) -> PromptableFontRegistrationReport {
        let fontURLs = ["ttf", "otf"]
            .flatMap { bundle.urls(forResourcesWithExtension: $0, subdirectory: fontsDirectory) ?? [] }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var registeredURLs: [URL] = []
        var alreadyRegisteredURLs: [URL] = []
        var failedFonts: [PromptableFontRegistrationFailure] = []

        for url in fontURLs {
            var unmanagedError: Unmanaged<CFError>?
            let didRegister = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &unmanagedError)

            if didRegister {
                registeredURLs.append(url)
                continue
            }

            let error: NSError?
            if let unmanagedError {
                error = unmanagedError.takeRetainedValue() as Error as NSError
            } else {
                error = nil
            }
            if error?.domain == kCTFontManagerErrorDomain as String, error?.code == 105 {
                alreadyRegisteredURLs.append(url)
            } else {
                failedFonts.append(PromptableFontRegistrationFailure(url: url, error: error))
            }
        }

        let missing = expectedPostScriptNames
            .subtracting(availablePostScriptNames())
            .sorted()

        return PromptableFontRegistrationReport(
            registeredURLs: registeredURLs,
            alreadyRegisteredURLs: alreadyRegisteredURLs,
            failedFonts: failedFonts,
            missingPostScriptNames: missing
        )
    }

    public static func availablePostScriptNames() -> Set<String> {
        let names = CTFontManagerCopyAvailablePostScriptNames() as? [String] ?? []
        return Set(names)
    }

    public static func manropePostScriptName(for weight: Font.Weight) -> String {
        if weight == .bold {
            return manropeBold
        }

        if weight == .semibold {
            return manropeSemiBold
        }

        if weight == .medium {
            return manropeMedium
        }

        return manropeRegular
    }

    public static func jetBrainsMonoPostScriptName(for weight: Font.Weight) -> String {
        weight == .medium ? jetBrainsMonoMedium : jetBrainsMonoRegular
    }
}

public extension Font {
    static func manrope(
        size: CGFloat = 14,
        weight: Font.Weight = .regular,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        .custom(PromptableFonts.manropePostScriptName(for: weight), size: size, relativeTo: textStyle)
    }

    static func jetbrainsMono(
        size: CGFloat = 14,
        weight: Font.Weight = .regular,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        .custom(PromptableFonts.jetBrainsMonoPostScriptName(for: weight), size: size, relativeTo: textStyle)
    }
}

public struct PTRoundedSurface: View {
    public var fill: Color
    public var border: Color
    public var borderWidth: CGFloat
    public var cornerRadius: CGFloat
    public var shadow: PromptableTheme.ShadowRecipe
    public var hairline: Color?

    public init(
        fill: Color,
        border: Color = PromptableTheme.Colors.border,
        borderWidth: CGFloat = 1,
        cornerRadius: CGFloat = PromptableTheme.Radius.lg,
        shadow: PromptableTheme.ShadowRecipe = PromptableTheme.Shadows.sm,
        hairline: Color? = PromptableTheme.Colors.hairline
    ) {
        self.fill = fill
        self.border = border
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.hairline = hairline
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        shape
            .fill(fill)
            .ptDropShadow(shadow)
            .overlay {
                shape.strokeBorder(border, lineWidth: borderWidth)
            }
            .overlay(alignment: .top) {
                if let hairline {
                    Rectangle()
                        .fill(hairline)
                        .frame(height: 1)
                        .clipShape(shape)
                        .allowsHitTesting(false)
                }
            }
    }
}

public extension View {
    func ptDropShadow(_ recipe: PromptableTheme.ShadowRecipe) -> some View {
        modifier(PTDropShadowModifier(recipe: recipe))
    }

    func ptFocusRing(
        _ isFocused: Bool,
        cornerRadius: CGFloat = PromptableTheme.Radius.md,
        color: Color = PromptableTheme.Colors.ring
    ) -> some View {
        overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(color, lineWidth: 1)
            }
        }
    }
}

private struct PTDropShadowModifier: ViewModifier {
    var recipe: PromptableTheme.ShadowRecipe

    @ViewBuilder
    func body(content: Content) -> some View {
        if let shadow = recipe.dropShadow {
            content.shadow(
                color: shadow.color,
                radius: max(0, shadow.blur + shadow.spread),
                x: shadow.x,
                y: shadow.y
            )
        } else {
            content
        }
    }
}
