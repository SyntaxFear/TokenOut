import SwiftUI
import Charts
import BurnBarCore

struct ProviderCard: View {
    @Environment(AppState.self) private var app
    var providerID: ProviderID
    var displayName: String
    var state: ProviderState
    /// Single-provider focus mode: show extra rows the compact list omits.
    var focused: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            switch state.status {
            case .signedOut(let help):
                statusMessage(icon: "person.crop.circle.badge.exclamationmark",
                              text: help.isEmpty ? "Signed out." : help)
            case .unsupported(let reason):
                statusMessage(icon: "info.circle", text: reason)
            default:
                if let snapshot = state.snapshot {
                    content(snapshot)
                } else {
                    statusMessage(icon: "hourglass", text: "Waiting for first fetch…")
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(displayName).font(.system(size: 13, weight: .semibold))
            if let account = state.snapshot?.accountLabel {
                Text(account)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 5).padding(.vertical, 1.5)
                    .background(.tertiary.opacity(0.5), in: Capsule())
            }
            Spacer()
            statusBadge
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch state.status {
        case .ok:
            EmptyView()
        case .stale(let since) where since > .distantPast:
            Label("Stale", systemImage: "wifi.exclamationmark")
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .help("Last update \(since.formatted(.relative(presentation: .named)))")
        case .stale:
            EmptyView()
        case .signedOut:
            Label("Signed out", systemImage: "lock").font(.system(size: 10)).foregroundStyle(.orange)
        case .unsupported:
            EmptyView()
        }
    }

    @ViewBuilder
    private func content(_ snapshot: UsageSnapshot) -> some View {
        ForEach(snapshot.windows, id: \.label) { window in
            WindowRow(window: window)
            if let projection = app.projection(for: providerID, window: window) {
                Label {
                    Text("on pace to hit the cap ≈ \(projection.hitsCapAt.formatted(date: .omitted, time: .shortened)) (+\(Int((projection.perHour * 100).rounded()))%/h)")
                } icon: {
                    Image(systemName: "speedometer")
                }
                .font(.system(size: 10))
                .foregroundStyle(.orange)
            }
        }
        sparkline
        if let tokens = snapshot.tokens {
            tokenRow(tokens)
        }
        ForEach(snapshot.detail, id: \.title) { line in
            HStack {
                Text(line.title).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text(line.value).font(.system(size: 11, weight: .medium))
                    .multilineTextAlignment(.trailing)
            }
        }
        ForEach(snapshot.breakdowns, id: \.title) { breakdown in
            BreakdownView(breakdown: breakdown)
        }
        if !snapshot.daily.isEmpty {
            DailyChartView(daily: snapshot.daily)
        }
        if focused {
            if let tokens = snapshot.tokens {
                HStack {
                    Text("This week").font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Format.tokens(tokens.weekTokens))\(tokens.weekCostUSD.map { " · \(tokens.costIsEstimated ? "~" : "")\(Format.usd($0))" } ?? "")")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                }
            }
            HStack {
                Text("Updated").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text(snapshot.fetchedAt.formatted(.relative(presentation: .named)))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    @State private var sparkHover: (Date, Double)?

    @ViewBuilder
    private var sparkline: some View {
        @Bindable var app = app
        let raw = app.sparkline(for: providerID)
        if raw.count >= 5 {
            let series = raw.map { ($0.0, app.sparkShowsRemaining ? 1 - $0.1 : $0.1) }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    if let hover = sparkHover {
                        Text("\(hover.0.formatted(date: .omitted, time: .shortened)) · \(Format.pct(hover.1)) \(app.sparkShowsRemaining ? "left" : "used")")
                            .font(.system(size: 9, weight: .medium).monospacedDigit())
                            .foregroundStyle(.primary)
                    } else {
                        Text("SESSION WINDOW · LAST 24H")
                            .font(.system(size: 8, weight: .semibold)).tracking(0.5)
                            .foregroundStyle(.tertiary)
                            .help("How full your 5-hour session window has been through the day. Drops mean the window refilled.")
                    }
                    Spacer()
                    Picker("", selection: $app.sparkShowsRemaining) {
                        Text("Left").tag(true)
                        Text("Used").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.mini)
                    .fixedSize()
                    .help("Plot what's left (drains to 0%) or what's used (fills to 100%)")
                }
                Chart(Array(series.enumerated()), id: \.offset) { _, point in
                    AreaMark(x: .value("t", point.0), y: .value("v", point.1))
                        .foregroundStyle(.orange.opacity(0.18))
                    LineMark(x: .value("t", point.0), y: .value("v", point.1))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    if let hover = sparkHover {
                        RuleMark(x: .value("t", hover.0))
                            .foregroundStyle(.yellow.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }
                .chartYScale(domain: 0...1)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(values: [0.0, 1.0]) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(v == 0 ? "0" : "100%").font(.system(size: 7))
                            }
                        }
                    }
                }
                .frame(height: 30)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let point):
                                    let origin = geo[proxy.plotFrame!].origin
                                    if let date: Date = proxy.value(atX: point.x - origin.x) {
                                        sparkHover = series.min {
                                            abs($0.0.timeIntervalSince(date)) < abs($1.0.timeIntervalSince(date))
                                        }
                                    }
                                case .ended: sparkHover = nil
                                }
                            }
                    }
                }
            }
        }
    }

    private func tokenRow(_ tokens: TokenTotals) -> some View {
        HStack {
            Text("Tokens").font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Text(tokenSummary(tokens))
                .font(.system(size: 11, weight: .medium).monospacedDigit())
        }
    }

    private func tokenSummary(_ tokens: TokenTotals) -> String {
        var text = "\(Format.tokens(tokens.todayTokens)) today"
        if let cost = tokens.todayCostUSD, cost > 0 {
            text += " · \(tokens.costIsEstimated ? "~" : "")\(Format.usd(cost))"
        } else if tokens.costIsEstimated && tokens.todayCostUSD == nil {
            text = "~" + text
        }
        return text
    }

    private func statusMessage(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon).foregroundStyle(.secondary)
            Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct BreakdownView: View {
    var breakdown: Breakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(breakdown.title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
            ForEach(breakdown.rows, id: \.name) { row in
                HStack(spacing: 6) {
                    Text(row.name)
                        .font(.system(size: 10.5, weight: .medium))
                        .lineLimit(1)
                        .frame(width: 92, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.quaternary.opacity(0.6))
                            Capsule().fill(.orange.gradient.opacity(0.75))
                                .frame(width: max(2, geo.size.width * row.fraction))
                        }
                    }
                    .frame(height: 4)
                    Text(row.valueText)
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
            }
        }
        .padding(.top, 2)
    }
}

struct WindowRow: View {
    var window: LimitWindow

    private var barColor: Color {
        switch window.usedFraction {
        case 0.95...: .red
        case 0.8...: .orange
        default: .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(window.label).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text(Format.pct(window.usedFraction))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(window.usedFraction >= 0.8 ? barColor : .primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(barColor.gradient)
                        .frame(width: max(3, geo.size.width * window.usedFraction))
                }
            }
            .frame(height: 5)
            if let resetsAt = window.resetsAt {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text("refills in \(Format.countdown(until: resetsAt, from: context.date))")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
