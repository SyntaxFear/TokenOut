import SwiftUI
import Charts
import BurnBarCore

/// Day-by-day usage bars with a selectable range, so users see when they burn most.
struct DailyChartView: View {
    @Environment(AppState.self) private var app
    var daily: [DayStat]
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

    private var busiestDay: DayStat? { visible.max { $0.tokens < $1.tokens } }

    var body: some View {
        @Bindable var app = app
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 6) {
                Picker("", selection: $app.dailyRange) {
                    Text("7d").tag(7)
                    Text("30d").tag(30)
                    Text("60d").tag(60)
                    Text("90d").tag(90)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.mini)

                if visible.isEmpty {
                    Text("No usage recorded in this range.")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                } else {
                    statTiles
                    chart
                    infoLine
                }
            }
            .padding(.top, 4)
        } label: {
            Label("Daily usage", systemImage: "chart.bar.fill")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .clickable()
                .help(expanded ? "Collapse daily usage" : "Expand daily usage")
                .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { expanded.toggle() } }
        }
    }

    private var todayStat: DayStat? {
        visible.first { Calendar.current.isDateInToday($0.day) }
    }

    private var statTiles: some View {
        let est = totals.estimated ? "~" : ""
        let tiles: [(String, String)] = [
            ("Today", "\(est)\(Format.usd(todayStat?.costUSD ?? 0))"),
            ("\(app.dailyRange)d cost", "\(est)\(Format.usd(totals.cost))"),
            ("\(app.dailyRange)d tokens", Format.tokens(totals.tokens)),
            ("Peak day", "\(est)\(Format.usd(busiestDay?.costUSD ?? 0))"),
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible())],
                         spacing: 6) {
            ForEach(tiles, id: \.0) { tile in
                VStack(alignment: .leading, spacing: 2) {
                    Text(tile.0.uppercased())
                        .font(.system(size: 8.5, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(.tertiary)
                    Text(tile.1)
                        .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText())
                        .foregroundStyle(tile.0 == "Today" ? AnyShapeStyle(.orange.gradient)
                                                           : AnyShapeStyle(.primary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
                Text("\(day.day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))) · \(Format.tokens(day.tokens)) tok · \(day.costIsEstimated ? "~" : "")\(Format.usd(day.costUSD))\(day.topModelText.map { " · \($0)" } ?? "")")
                    .foregroundStyle(.primary)
            } else {
                Text("\(Format.tokens(totals.tokens)) tokens · \(totals.estimated ? "~" : "")\(Format.usd(totals.cost))")
                Spacer()
                if let busiest = busiestDay {
                    Text("peak \(busiest.day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))")
                }
            }
        }
        .font(.system(size: 9.5).monospacedDigit())
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .frame(minHeight: 12)
    }

    private var chart: some View {
        Chart(visible, id: \.day) { stat in
            BarMark(
                x: .value("Day", stat.day, unit: .day),
                y: .value("Tokens", stat.tokens)
            )
            .foregroundStyle(
                stat.day == hovered?.day ? AnyShapeStyle(.yellow.gradient)
                : stat.day == busiestDay?.day ? AnyShapeStyle(.red.gradient)
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
                               centered: false)
                    .font(.system(size: 7.5))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel {
                    if let tokens = value.as(Int.self) {
                        Text(Format.tokens(tokens)).font(.system(size: 7.5))
                    }
                }
            }
        }
        .frame(height: 74)
        .overlay(alignment: .topTrailing) {
            if hovered == nil, let busiest = busiestDay, busiest.costUSD > 0 {
                Text("\(totals.estimated ? "~" : "")\(Format.usd(busiest.costUSD))")
                    .font(.system(size: 8.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 2)
            }
        }
    }
}
