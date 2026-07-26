import SwiftUI
import TokenOutCore

/// Shared token summary used by every provider so partial providers do not fall back
/// to a visually weaker list of labels and values.
struct UsageSummaryTiles: View {
    var tokens: TokenTotals

    var body: some View {
        HStack(spacing: 6) {
            tile(title: "Today",
                 value: tokenText(tokens.todayTokens, estimated: tokenCountIsEstimated),
                 secondary: costText(tokens.todayCostUSD))
            tile(title: "This week",
                 value: tokenText(tokens.weekTokens, estimated: tokenCountIsEstimated),
                 secondary: costText(tokens.weekCostUSD))
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

    private func tile(title: String, value: String, secondary: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .tokenOutFont(9.5, weight: .semibold)
                .foregroundStyle(.secondary)
            MetricValueText(value: value)
                .foregroundStyle(.primary)
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
                .tokenOutFont(12, weight: .medium)
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(Color.primary.opacity(0.06), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Quota unavailable")
                    .tokenOutFont(10.5, weight: .semibold)
                Text(message)
                    .tokenOutFont(9.5)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
        }
    }
}
