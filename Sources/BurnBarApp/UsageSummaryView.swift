import SwiftUI
import BurnBarCore

/// Shared token summary used by every provider so partial providers do not fall back
/// to a visually weaker list of labels and values.
struct UsageSummaryTiles: View {
    var tokens: TokenTotals

    var body: some View {
        HStack(spacing: 6) {
            tile(title: "Today",
                 value: tokenText(tokens.todayTokens, estimated: tokenCountIsEstimated),
                 secondary: costText(tokens.todayCostUSD),
                 accent: true)
            tile(title: "This week",
                 value: tokenText(tokens.weekTokens, estimated: tokenCountIsEstimated),
                 secondary: costText(tokens.weekCostUSD),
                 accent: false)
        }
    }

    private var tokenCountIsEstimated: Bool {
        tokens.costIsEstimated && tokens.todayCostUSD == nil && tokens.weekCostUSD == nil
    }

    private func tokenText(_ count: Int, estimated: Bool) -> String {
        "\(estimated ? "~" : "")\(Format.tokens(count)) tok"
    }

    private func costText(_ cost: Double?) -> String {
        if let cost, cost > 0 {
            return "\(tokens.costIsEstimated ? "~" : "")\(Format.usd(cost)) value"
        }
        return tokenCountIsEstimated ? "Estimated locally" : "Local usage"
    }

    private func tile(title: String, value: String, secondary: String,
                      accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 8.5, weight: .semibold))
                .tracking(0.55)
                .foregroundStyle(.tertiary)
            MetricValueText(value: value)
                .foregroundStyle(accent ? AnyShapeStyle(.orange.gradient)
                                        : AnyShapeStyle(.primary))
            MetricValueText(value: secondary, size: 9, weight: .regular, design: .default)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 9))
    }
}

struct LimitUnavailableView: View {
    var message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "gauge.with.dots.needle.0percent")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.orange)
                .frame(width: 24, height: 24)
                .background(.orange.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Quota unavailable")
                    .font(.system(size: 10.5, weight: .semibold))
                Text(message)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(.orange.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(.orange.opacity(0.14), lineWidth: 0.5)
        }
    }
}

struct DetailGridView: View {
    var lines: [DetailLine]

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.title.uppercased())
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(0.45)
                        .foregroundStyle(.tertiary)
                    Text(line.value)
                        .font(.system(size: 10.5, weight: .medium))
                        .lineLimit(2)
                        .help(line.value)
                }
                .frame(maxWidth: .infinity, minHeight: 31, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.26), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
