import SwiftUI

/// Currency typography: keep the meaningful whole value prominent while reducing
/// cents visually ("$5125.33" → large $5125 + smaller .33). Non-currency decimals,
/// such as token abbreviations ("5.1M"), stay at one consistent size.
struct MetricValueText: View {
    @Environment(\.tokenOutFontScale) private var scale
    @Environment(\.tokenOutFontFamily) private var family
    var value: String
    var size: CGFloat = 14
    var weight: Font.Weight = .semibold
    var design: Font.Design = .rounded

    private let currencyMarkers = "$€£¥₹₾₽₩₺₴₦₫฿₱₪₡₲₵₸"

    private func font(_ pointSize: CGFloat) -> Font {
        family == .system ? .system(size: pointSize * scale, weight: weight, design: design)
                           : .tokenOut(family, size: pointSize * scale, weight: weight)
    }

    private var isCurrency: Bool {
        value.contains { currencyMarkers.contains($0) }
    }

    private var parts: (whole: String, fraction: String?, suffix: String) {
        guard isCurrency, let decimal = value.firstIndex(of: ".") else {
            return (value, nil, "")
        }
        var end = value.index(after: decimal)
        while end < value.endIndex, value[end].isNumber {
            end = value.index(after: end)
        }
        guard end > value.index(after: decimal) else {
            return (value, nil, "")
        }
        return (
            String(value[..<decimal]),
            String(value[decimal..<end]),
            String(value[end...])
        )
    }

    var body: some View {
        let parts = parts
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(parts.whole)
                .font(font(size))
            if let fraction = parts.fraction {
                Text(fraction)
                    .font(font(size * 0.72))
                    .opacity(0.78)
            }
            if !parts.suffix.isEmpty {
                Text(parts.suffix)
                    .font(font(size))
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .contentTransition(.numericText())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value)
    }
}
