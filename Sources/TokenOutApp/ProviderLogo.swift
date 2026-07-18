import SwiftUI
import AppKit
import TokenOutCore

/// The TokenOut brand mark (token ring + escaping arrow), rendered from the
/// generated master so it matches the app icon exactly.
struct TokenOutMark: View {
    var size: CGFloat = 16

    private static let image: NSImage? = {
        let url = Bundle.main.url(forResource: "tokenout-mark", withExtension: "png",
                                  subdirectory: "BrandMark")
            ?? Bundle.module.url(forResource: "tokenout-mark", withExtension: "png",
                                 subdirectory: "BrandMark")
        return url.flatMap { NSImage(contentsOf: $0) }
    }()

    var body: some View {
        if let image = Self.image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "arrow.up.right.circle.fill")
                .font(.system(size: size * 0.9))
                .foregroundStyle(.orange.gradient)
        }
    }
}

/// Brand marks for supported providers (vendored from CodexBar, MIT licensed).
struct ProviderLogo: View {
    var providerID: ProviderID
    var size: CGFloat = 14

    /// The packaged .app flattens the SwiftPM resource bundle into
    /// Contents/Resources/ProviderLogos (see scripts/bundle.sh) so codesign's
    /// resource seal covers it; `swift run` / tests still find them via
    /// Bundle.module. Check both so this works packaged and unpackaged.
    private static func resourceURL(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "pdf", subdirectory: "ProviderLogos")
            ?? Bundle.module.url(forResource: name, withExtension: "pdf")
    }

    private static let cache: [ProviderID: NSImage] = {
        var result: [ProviderID: NSImage] = [:]
        for (id, resource) in [
            (ProviderID.claude, "claude"),
            (.codex, "codex"),
            (.antigravity, "antigravity"),
        ] {
            guard let url = resourceURL(resource),
                  let image = NSImage(contentsOf: url) else { continue }
            result[id] = image
        }
        return result
    }()

    var body: some View {
        if let image = Self.cache[providerID] {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        }
    }
}
