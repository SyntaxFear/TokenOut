import Foundation

/// Localized lookup that goes through Bundle.main's NSBundle path — which the
/// language override below swizzles. `String(localized:)` resolves through
/// CFBundle directly and would ignore a mid-session language switch.
func tokenOutLocalized(_ key: String, _ fallback: String) -> String {
    Bundle.main.localizedString(forKey: key, value: fallback, table: "Localizable")
}

/// UI language override. ".system" follows macOS's own language/region setting;
/// the rest force a specific locale regardless of system language, matching each
/// bundled localization in Resources/Localizable.xcstrings.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en, es, zh, hi, ar, pt, ru, ja, de, fr

    var id: String { rawValue }

    /// Name shown in its OWN language, so users can find their language even if
    /// the current UI language isn't one they read.
    var nativeName: String {
        switch self {
        case .system: tokenOutLocalized("Language.system", "System")
        case .en: "English"
        case .es: "Español"
        case .zh: "中文（简体）"
        case .hi: "हिन्दी"
        case .ar: "العربية"
        case .pt: "Português"
        case .ru: "Русский"
        case .ja: "日本語"
        case .de: "Deutsch"
        case .fr: "Français"
        }
    }

    /// Locale identifiers this maps to, for `Bundle.setLanguage` / environment override.
    var localeIdentifier: String? {
        switch self {
        case .system: nil
        case .zh: "zh-Hans"
        default: rawValue
        }
    }

    /// Locale for SwiftUI's environment, so date/number formatting follows the
    /// chosen language too.
    var locale: Locale {
        localeIdentifier.map(Locale.init(identifier:)) ?? .autoupdatingCurrent
    }
}

// MARK: - Live language switching

private nonisolated(unsafe) var languageBundleKey: UInt8 = 0

/// Redirects `Bundle.main` string lookups to the selected language's .lproj at
/// runtime. AppleLanguages is only read once at process start, so without this
/// a language change needs a relaunch; with it, rebuilt views re-resolve their
/// strings through the override immediately.
private final class LanguageOverrideBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table: String?) -> String {
        let override = objc_getAssociatedObject(self, &languageBundleKey)
        if override is NSNull {
            // Forced development language (English): keys ARE the English strings.
            if let value, !value.isEmpty { return value }
            return key
        }
        if let path = override as? String, let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: value, table: table)
        }
        return super.localizedString(forKey: key, value: value, table: table)
    }
}

extension Bundle {
    /// nil → follow the process-start language. "en" (no .lproj of its own) →
    /// force development-language keys. Anything else → that language's .lproj.
    @MainActor
    static func setLanguage(_ identifier: String?) {
        object_setClass(Bundle.main, LanguageOverrideBundle.self)
        let override: Any?
        if let identifier {
            // "zh-Hans" ships as zh.lproj — try the exact id, then its prefix.
            let candidates = [identifier, String(identifier.prefix(while: { $0 != "-" }))]
            override = candidates.compactMap { Bundle.main.path(forResource: $0, ofType: "lproj") }.first
                ?? NSNull()
        } else {
            override = nil
        }
        objc_setAssociatedObject(Bundle.main, &languageBundleKey, override,
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
