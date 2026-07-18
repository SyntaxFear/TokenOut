import SwiftUI

private struct FontScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

private struct FontFamilyKey: EnvironmentKey {
    static let defaultValue: AppFontFamily = .system
}

extension EnvironmentValues {
    var tokenOutFontScale: CGFloat {
        get { self[FontScaleKey.self] }
        set { self[FontScaleKey.self] = newValue }
    }
    var tokenOutFontFamily: AppFontFamily {
        get { self[FontFamilyKey.self] }
        set { self[FontFamilyKey.self] = newValue }
    }
}

private struct TokenOutFontModifier: ViewModifier {
    @Environment(\.tokenOutFontScale) private var scale
    @Environment(\.tokenOutFontFamily) private var family
    var size: CGFloat
    var weight: Font.Weight
    var design: Font.Design
    var monospacedDigit: Bool

    func body(content: Content) -> some View {
        let base = family == .system
            ? Font.system(size: size * scale, weight: weight, design: design)
            : .tokenOut(family, size: size * scale, weight: weight)
        content.font(monospacedDigit ? base.monospacedDigit() : base)
    }
}

extension View {
    /// The app-wide replacement for `.font(.system(size:weight:))` — resolves
    /// the user's font-size scale and chosen font family (Settings > Appearance).
    func tokenOutFont(_ size: CGFloat, weight: Font.Weight = .regular,
                      design: Font.Design = .default,
                      monospacedDigit: Bool = false) -> some View {
        modifier(TokenOutFontModifier(size: size, weight: weight, design: design, monospacedDigit: monospacedDigit))
    }

    /// Applies theme, font scale, font family, and language from AppState.
    /// Call once at each window/scene root (popover, settings, onboarding).
    /// `.id(app.appLanguage)` rebuilds the whole subtree on a language switch
    /// so every Text re-resolves through the swizzled bundle immediately.
    func tokenOutAppearance(_ app: AppState) -> some View {
        self
            .preferredColorScheme(app.theme.colorScheme)
            .environment(\.tokenOutFontScale, app.fontSize.scale)
            .environment(\.tokenOutFontFamily, app.fontFamily)
            .environment(\.locale, app.appLanguage.locale)
            .id(app.appLanguage)
    }
}
