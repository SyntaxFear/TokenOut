import SwiftUI
import Charts
import BurnBarCore

/// The all-tools overview: total burn across providers, stacked day-by-day,
/// so planning happens against the WHOLE spend, not one tool at a time.
struct CombinedCard: View {
    @Environment(AppState.self) private var app
    @State private var hoveredDay: Date?

    static let providerColors: KeyValuePairs<String, Color> = [
        "Claude Code": .orange, "Codex": .teal, "Antigravity": .purple,
    ]

    private var visible: [CombinedPoint] {
        let cutoff = Calendar.current.date(
            byAdding: .day, value: -(app.dailyRange - 1),
            to: Calendar.current.startOfDay(for: .now)) ?? .distantPast
        return app.combinedDaily.filter { $0.day >= cutoff }
    }

    private func value(_ point: CombinedPoint) -> Double {
        app.chartMetric == .cost ? point.cost : Double(point.tokens)
    }

    private var todayCost: Double {
        visible.filter { Calendar.current.isDateInToday($0.day) }.reduce(0) { $0 + $1.cost }
    }
    private var rangeCost: Double { visible.reduce(0) { $0 + $1.cost } }
    private var rangeTokens: Int { visible.reduce(0) { $0 + $1.tokens } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange.gradient)
                Text("All tools combined").font(.system(size: 13, weight: .semibold))
                Spacer()
                if let hovered = hoveredDay {
                    Text(hovered.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 6) {
                tile("Today", "~" + Format.usd(todayCost), accent: true)
                tile("\(app.dailyRange)d spend", "~" + Format.usd(rangeCost))
                tile("\(app.dailyRange)d tokens", Format.tokens(rangeTokens))
            }

            if visible.count >= 2 {
                chart
                legend
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func tile(_ caption: String, _ text: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(caption.uppercased())
                .font(.system(size: 8, weight: .semibold)).tracking(0.5)
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
                .foregroundStyle(accent ? AnyShapeStyle(.orange.gradient) : AnyShapeStyle(.primary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private var chart: some View {
        Chart(visible) { point in
            BarMark(
                x: .value("Day", point.day, unit: .day),
                y: .value(app.chartMetric == .cost ? "Cost" : "Tokens", value(point))
            )
            .foregroundStyle(by: .value("Tool", point.provider))
            .opacity(hoveredDay == nil || hoveredDay == point.day ? 1 : 0.35)
            .cornerRadius(1.5)
        }
        .chartForegroundStyleScale(Self.providerColors)
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, app.dailyRange / 6))) {
                AxisValueLabel(format: .dateTime.day().month(.defaultDigits))
                    .font(.system(size: 7.5))
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 64)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let point):
                            let origin = geo[proxy.plotFrame!].origin
                            if let date: Date = proxy.value(atX: point.x - origin.x) {
                                hoveredDay = Calendar.current.startOfDay(for: date)
                            }
                        case .ended: hoveredDay = nil
                        }
                    }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 10) {
            ForEach(Array(Self.providerColors), id: \.key) { name, color in
                if visible.contains(where: { $0.provider == name }) {
                    let slice = visible.filter {
                        $0.provider == name && (hoveredDay == nil || $0.day == hoveredDay)
                    }
                    Label {
                        Text("\(name) ~\(Format.usd(slice.reduce(0) { $0 + $1.cost }))")
                            .font(.system(size: 9).monospacedDigit())
                    } icon: {
                        Circle().fill(color).frame(width: 6, height: 6)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}
