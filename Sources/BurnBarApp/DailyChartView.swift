import SwiftUI
import Charts
import BurnBarCore

/// Day-by-day usage bars with a selectable range, so users see when they burn most.
struct DailyChartView: View {
    @Environment(AppState.self) private var app
    var daily: [DayStat]
    @State private var expanded = false

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
                    chart
                    HStack {
                        Text("\(Format.tokens(totals.tokens)) tokens · \(totals.estimated ? "~" : "")\(Format.usd(totals.cost))")
                        Spacer()
                        if let busiest = busiestDay {
                            Text("peak \(busiest.day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))")
                        }
                    }
                    .font(.system(size: 9.5).monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        } label: {
            Label("Daily usage", systemImage: "chart.bar.fill")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var chart: some View {
        Chart(visible, id: \.day) { stat in
            BarMark(
                x: .value("Day", stat.day, unit: .day),
                y: .value("Tokens", stat.tokens)
            )
            .foregroundStyle(
                stat.day == busiestDay?.day ? AnyShapeStyle(.red.gradient)
                                            : AnyShapeStyle(.orange.gradient))
            .cornerRadius(app.dailyRange <= 30 ? 2 : 1)
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
    }
}
