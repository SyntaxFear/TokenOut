import SwiftUI
import Charts
import TokenOutCore

/// Day-by-day usage bars with a selectable range, so users see when usage peaks.
struct DailyChartView: View {
    @Environment(AppState.self) private var app
    var daily: [DayStat]
    /// Provider token totals, folded into the tile grid (Today / This week).
    var tokens: TokenTotals?
    @State private var expanded = true
    @State private var hovered: DayStat?

    private var visible: [DayStat] {
        let cutoff = Calendar.current.startOfDay(
            for: Date.now.addingTimeInterval(-Double(app.dailyRange - 1) * 86400))
        return daily.filter { $0.day >= cutoff }
    }

    private var totals: (tokens: Int, cost: Double, estimated: Bool) {
        (visible.reduce(0) { $0 + $1.tokens },
         visible.reduce(0) { $0 + $1.costUSD },
         visible.contains { $0.costIsEstimated })
    }

    private var hasCostData: Bool { visible.contains { $0.costUSD > 0 } }
    private var effectiveMetric: ChartMetric { hasCostData ? app.chartMetric : .tokens }

    /// Chart value, highlight, and peak all follow the SAME selected metric —
    /// mixing token-peaks with dollar-labels is exactly what confused users.
    private func value(_ stat: DayStat) -> Double {
        effectiveMetric == .cost ? stat.costUSD : Double(stat.tokens)
    }
    private var peakDay: DayStat? { visible.max { value($0) < value($1) } }
    private var priciestDay: DayStat? { visible.max { $0.costUSD < $1.costUSD } }

    private var todayStat: DayStat? {
        visible.first { Calendar.current.isDateInToday($0.day) }
    }

    private func compactValue(_ raw: Double) -> String {
        effectiveMetric == .cost
            ? (raw >= 1000 ? String(format: "$%.1fK", raw / 1000) : String(format: "$%.0f", raw))
            : Format.tokens(Int(raw))
    }

    var body: some View {
        @Bindable var app = app
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Picker("", selection: $app.dailyRange) {
                        Text("7d").tag(7)
                        Text("30d").tag(30)
                        Text("60d").tag(60)
                        Text("90d").tag(90)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.mini)
                    if hasCostData {
                        Picker("", selection: $app.chartMetric) {
                            ForEach(ChartMetric.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .controlSize(.mini)
                        .fixedSize()
                        .help("Plot charts by dollars or tokens")
                    } else {
                        Text("TOKENS")
                            .tokenOutFont(8.5, weight: .semibold)
                            .tracking(0.5)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.quaternary.opacity(0.45), in: Capsule())
                    }
                }

                if visible.isEmpty {
                    Text("No usage recorded in this range.")
                        .tokenOutFont(10).foregroundStyle(.tertiary)
                } else {
                    statTiles
                    chart
                    infoLine
                }
            }
            .padding(.top, 4)
        } label: {
            Label("Daily usage", systemImage: "chart.bar.fill")
                .tokenOutFont(10.5, weight: .medium)
                .foregroundStyle(.secondary)
        }
        .disclosureGroupStyle(RowDisclosureStyle())
    }

    private struct Tile {
        var title: String
        var value: String
        var secondary: String?
        var accent = false
    }

    /// One combined grid: the provider's Today / This-week token totals plus
    /// the range-dependent chart stats — six tiles in one place.
    private var statTiles: some View {
        var tiles: [Tile] = []
        if let tokens {
            let estimatedMark = tokens.costIsEstimated ? "~" : ""
            tiles.append(Tile(title: "Today",
                              value: "\(Format.tokens(tokens.todayTokens)) tok",
                              secondary: tokens.todayCostUSD.map { "\(estimatedMark)\(Format.usd($0)) value" },
                              accent: true))
            tiles.append(Tile(title: "This week",
                              value: "\(Format.tokens(tokens.weekTokens)) tok",
                              secondary: tokens.weekCostUSD.map { "\(estimatedMark)\(Format.usd($0)) value" }))
        }
        if hasCostData {
            tiles += [
                Tile(title: "Today", value: Format.usd(todayStat?.costUSD ?? 0),
                     accent: tokens == nil),
                Tile(title: "\(app.dailyRange)d cost", value: Format.usd(totals.cost)),
                Tile(title: "\(app.dailyRange)d tokens", value: Format.tokens(totals.tokens)),
                Tile(title: "Peak day", value: Format.usd(priciestDay?.costUSD ?? 0)),
            ]
        } else {
            tiles += [
                Tile(title: "Today", value: Format.tokens(todayStat?.tokens ?? 0),
                     accent: tokens == nil),
                Tile(title: "\(app.dailyRange)d tokens", value: Format.tokens(totals.tokens)),
                Tile(title: "Active days", value: "\(visible.count)"),
                Tile(title: "Peak day", value: Format.tokens(peakDay?.tokens ?? 0)),
            ]
        }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible())],
                         spacing: 6) {
            ForEach(Array(tiles.enumerated()), id: \.offset) { _, tile in
                VStack(alignment: .leading, spacing: 2) {
                    Text(tile.title.uppercased())
                        .tokenOutFont(8.5, weight: .semibold)
                        .tracking(0.6)
                        .foregroundStyle(.tertiary)
                    MetricValueText(value: tile.value)
                        .foregroundStyle(tile.accent ? AnyShapeStyle(.orange.gradient)
                                                     : AnyShapeStyle(.primary))
                    if let secondary = tile.secondary {
                        MetricValueText(value: secondary, size: 9, weight: .regular, design: .default)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 9))
            }
        }
        .padding(.vertical, 2)
    }

    /// Hovering a bar swaps the totals line for that day's detail.
    @ViewBuilder
    private var infoLine: some View {
        HStack {
            if let day = hovered {
                Text("\(day.day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))) · \(Format.tokens(day.tokens)) tok")
                if hasCostData {
                    Text("·")
                    MetricValueText(value: Format.usd(day.costUSD), size: 9.5,
                                    weight: .regular, design: .default)
                }
                if let topModel = day.topModelText {
                    Text("· \(topModel)")
                }
            } else {
                Text("\(Format.tokens(totals.tokens)) tokens")
                Text("·")
                if hasCostData {
                    MetricValueText(value: Format.usd(totals.cost), size: 9.5,
                                    weight: .regular, design: .default)
                } else {
                    Text("estimated locally")
                }
                Spacer()
                if let peak = peakDay {
                    Text("peak \(peak.day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))")
                }
            }
        }
        .tokenOutFont(9.5, monospacedDigit: true)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .frame(minHeight: 12)
    }

    private var chart: some View {
        Chart(visible, id: \.day) { stat in
            BarMark(
                x: .value("Day", stat.day, unit: .day),
                y: .value(effectiveMetric == .cost ? "Cost" : "Tokens", value(stat))
            )
            .foregroundStyle(
                stat.day == hovered?.day ? AnyShapeStyle(.yellow.gradient)
                : stat.day == peakDay?.day ? AnyShapeStyle(.red.gradient)
                : AnyShapeStyle(.orange.gradient))
            .cornerRadius(app.dailyRange <= 30 ? 2 : 1)
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let point):
                            let origin = geo[proxy.plotFrame!].origin
                            if let date: Date = proxy.value(atX: point.x - origin.x) {
                                let day = Calendar.current.startOfDay(for: date)
                                hovered = visible.first { $0.day == day }
                            }
                        case .ended:
                            hovered = nil
                        }
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, app.dailyRange / 6))) {
                AxisValueLabel(format: app.dailyRange <= 7
                               ? .dateTime.weekday(.narrow)
                               : .dateTime.day().month(.defaultDigits),
                               centered: true, anchor: .top)
                    .font(Font.tokenOut(app.fontFamily, size: 7.5 * app.fontSize.scale, weight: .regular))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel {
                    if let raw = value.as(Double.self) {
                        Text(compactValue(raw)).tokenOutFont(7.5)
                    }
                }
            }
        }
        .frame(height: 74)
    }
}
