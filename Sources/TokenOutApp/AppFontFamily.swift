import SwiftUI
import AppKit

/// Selectable UI font families. "System" uses the platform font (San Francisco);
/// the rest are OFL-licensed Google Fonts bundled under Resources/Fonts and
/// registered at launch by `FontRegistry`. Each entry maps weight -> exact
/// PostScript name, since named instances differ per family (not every family
/// ships a "Medium" or "SemiBold" instance).
enum AppFontFamily: String, CaseIterable, Identifiable {
    case system
    case inter, poppins, montserrat, nunito, lato
    case openSans, raleway, workSans, sourceSans3, dmSans, manrope, spaceGrotesk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: tokenOutLocalized("Font.system", "System")
        case .inter: "Inter"
        case .poppins: "Poppins"
        case .montserrat: "Montserrat"
        case .nunito: "Nunito"
        case .lato: "Lato"
        case .openSans: "Open Sans"
        case .raleway: "Raleway"
        case .workSans: "Work Sans"
        case .sourceSans3: "Source Sans 3"
        case .dmSans: "DM Sans"
        case .manrope: "Manrope"
        case .spaceGrotesk: "Space Grotesk"
        }
    }

    /// Resource subfolder under Resources/Fonts, and the .ttf files it contains.
    fileprivate var resourceFolder: String? {
        self == .system ? nil : folderName
    }

    private var folderName: String {
        switch self {
        case .system: ""
        case .inter: "inter"
        case .poppins: "poppins"
        case .montserrat: "montserrat"
        case .nunito: "nunito"
        case .lato: "lato"
        case .openSans: "opensans"
        case .raleway: "raleway"
        case .workSans: "worksans"
        case .sourceSans3: "sourcesans3"
        case .dmSans: "dmsans"
        case .manrope: "manrope"
        case .spaceGrotesk: "spacegrotesk"
        }
    }

    fileprivate var filenames: [String] {
        switch self {
        case .system: []
        case .inter: ["Inter.ttf"]
        case .poppins: ["Poppins-Regular.ttf", "Poppins-Medium.ttf", "Poppins-SemiBold.ttf", "Poppins-Bold.ttf"]
        case .montserrat: ["Montserrat.ttf"]
        case .nunito: ["Nunito.ttf"]
        case .lato: ["Lato-Regular.ttf", "Lato-Medium.ttf", "Lato-SemiBold.ttf", "Lato-Bold.ttf"]
        case .openSans: ["OpenSans.ttf"]
        case .raleway: ["Raleway.ttf"]
        case .workSans: ["WorkSans.ttf"]
        case .sourceSans3: ["SourceSans3.ttf"]
        case .dmSans: ["DMSans.ttf"]
        case .manrope: ["Manrope.ttf"]
        case .spaceGrotesk: ["SpaceGrotesk.ttf"]
        }
    }

    /// Exact PostScript name to use for a given weight, with graceful fallback
    /// for families that don't ship every named instance.
    fileprivate func postscriptName(for weight: Font.Weight) -> String? {
        let names = Self.postscriptNames[self] ?? [:]
        switch weight {
        case .bold, .heavy, .black:
            return names[.bold] ?? names[.semibold] ?? names[.medium] ?? names[.regular]
        case .semibold:
            return names[.semibold] ?? names[.medium] ?? names[.bold] ?? names[.regular]
        case .medium:
            return names[.medium] ?? names[.semibold] ?? names[.regular]
        default:
            return names[.regular] ?? names[.medium]
        }
    }

    // PostScript names as resolved by CoreText from each font's named
    // instances (variable fonts expose weights as named STAT/fvar instances).
    private static let postscriptNames: [AppFontFamily: [Font.Weight: String]] = [
        .inter: [.regular: "Inter-Regular", .medium: "Inter-Regular_Medium",
                 .semibold: "Inter-Regular_SemiBold", .bold: "Inter-Regular_Bold"],
        .poppins: [.regular: "Poppins-Regular", .medium: "Poppins-Medium",
                   .semibold: "Poppins-SemiBold", .bold: "Poppins-Bold"],
        .montserrat: [.regular: "Montserrat-Regular", .medium: "Montserrat-Medium",
                      .semibold: "Montserrat-SemiBold", .bold: "Montserrat-Bold"],
        .nunito: [.regular: "Nunito-Regular", .medium: "Nunito-Medium",
                  .semibold: "Nunito-SemiBold", .bold: "Nunito-Bold"],
        .lato: [.regular: "Lato-Regular", .medium: "Lato-Medium",
                .semibold: "Lato-SemiBold", .bold: "Lato-Bold"],
        .openSans: [.regular: "OpenSans-Regular", .semibold: "OpenSansRoman-SemiBold",
                    .bold: "OpenSansRoman-Bold"],
        .raleway: [.regular: "RalewayRoman-Regular", .medium: "RalewayRoman-Medium",
                   .semibold: "RalewayRoman-SemiBold", .bold: "RalewayRoman-Bold"],
        .workSans: [.regular: "WorkSans-Regular", .medium: "WorkSansRoman-Medium",
                    .semibold: "WorkSansRoman-SemiBold", .bold: "WorkSansRoman-Bold"],
        .sourceSans3: [.regular: "SourceSans3-Roman_Regular", .medium: "SourceSans3-Roman_Medium",
                       .semibold: "SourceSans3-Roman_SemiBold", .bold: "SourceSans3-Roman_Bold"],
        .dmSans: [.regular: "DMSans-9ptRegular_Regular", .medium: "DMSans-9ptRegular_Medium",
                  .semibold: "DMSans-9ptRegular_SemiBold", .bold: "DMSans-9ptRegular_Bold"],
        .manrope: [.regular: "Manrope-Regular", .medium: "Manrope-Medium",
                   .semibold: "Manrope-SemiBold", .bold: "Manrope-Bold"],
        .spaceGrotesk: [.regular: "SpaceGrotesk-Light_Regular", .medium: "SpaceGrotesk-Light_Medium",
                        .bold: "SpaceGrotesk-Light_Bold"],
    ]
}

/// Registers every bundled Google Font with CoreText once at launch so
/// `Font.custom(postscriptName:)` lookups resolve. Safe to call more than once.
@MainActor
enum FontRegistry {
    private static var didRegister = false

    static func registerBundledFontsIfNeeded() {
        guard !didRegister else { return }
        didRegister = true
        for family in AppFontFamily.allCases where family != .system {
            for filename in family.filenames {
                guard let url = fontURL(family: family, filename: filename) else { continue }
                var error: Unmanaged<CFError>?
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            }
        }
    }

    private static func fontURL(family: AppFontFamily, filename: String) -> URL? {
        guard let folder = family.resourceFolder else { return nil }
        let stem = (filename as NSString).deletingPathExtension
        return Bundle.main.url(forResource: stem, withExtension: "ttf",
                                subdirectory: "Fonts/\(folder)")
            ?? Bundle.module.url(forResource: stem, withExtension: "ttf",
                                  subdirectory: "Fonts/\(folder)")
    }
}

extension Font {
    /// Resolves a family + weight to the correct registered custom font, or
    /// falls back to the system font when `family` is `.system` or the
    /// PostScript name isn't available.
    static func tokenOut(_ family: AppFontFamily, size: CGFloat, weight: Font.Weight) -> Font {
        guard family != .system, let name = family.postscriptName(for: weight) else {
            return .system(size: size, weight: weight)
        }
        return .custom(name, size: size)
    }
}
