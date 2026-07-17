import SwiftUI

/// Dashboard-number typography: keep the meaningful whole value prominent while
/// reducing decimal precision visually ("5125.33" → large 5125 + smaller .33).
struct MetricValueText: View {
    var value: String
    var size: CGFloat = 14
    var weight: Font.Weight = .semibold
    var design: Font.Design = .rounded

    private var parts: (whole: String, fraction: String?, suffix: String) {
        guard let decimal = value.firstIndex(of: ".") else {
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
                .font(.system(size: size, weight: weight, design: design))
            if let fraction = parts.fraction {
                Text(fraction)
                    .font(.system(size: size * 0.72, weight: weight, design: design))
                    .opacity(0.78)
            }
            if !parts.suffix.isEmpty {
                Text(parts.suffix)
                    .font(.system(size: size, weight: weight, design: design))
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .contentTransition(.numericText())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value)
    }
}
