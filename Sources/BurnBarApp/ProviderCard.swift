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
            if app.refreshing.contains(providerID) {
                ProgressView().controlSize(.small).scaleEffect(0.5)
                    .help("Fetching fresh data…")
            }
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
        if Date.now.timeIntervalSince(snapshot.fetchedAt) > 15 * 60 {
            Label {
                Text("Data from \(snapshot.fetchedAt.formatted(.relative(presentation: .named))) — numbers below may be outdated. Hit Refresh (and answer any Keychain prompt).")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "clock.badge.exclamationmark")
            }
            .font(.system(size: 10))
            .foregroundStyle(.orange)
        }
        if snapshot.windows.isEmpty {
            LimitUnavailableView(message: limitMessage(in: snapshot))
        } else {
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
        }
        if let tokens = snapshot.tokens {
            UsageSummaryTiles(tokens: tokens)
        }
        let visibleDetails = snapshot.detail.filter { $0.title != "Limits" }
        if app.showProviderDetails, !visibleDetails.isEmpty {
            DetailGridView(lines: visibleDetails)
        }
        if app.showBreakdowns {
            ForEach(snapshot.breakdowns, id: \.title) { breakdown in
                BreakdownView(breakdown: breakdown)
            }
        }
        if app.showDailyCharts, !snapshot.daily.isEmpty {
            DailyChartView(daily: snapshot.daily)
        }
        if focused {
            HStack {
                Text("Updated").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text(snapshot.fetchedAt.formatted(.relative(presentation: .named)))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    private func limitMessage(in snapshot: UsageSnapshot) -> String {
        snapshot.detail.first { $0.title == "Limits" }?.value
            ?? "This provider does not expose a local quota signal."
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
    @Environment(AppState.self) private var app
    var window: LimitWindow

    /// Danger colors always key off USED fraction, whatever the display mode.
    private var barColor: Color {
        switch window.usedFraction {
        case 0.95...: .red
        case 0.8...: .orange
        default: .green
        }
    }

    /// Global display logic: "left" drains to 0% (default), "used" fills to 100%.
    private var displayedFraction: Double {
        app.showRemaining ? 1 - window.usedFraction : window.usedFraction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(window.label).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text("\(Format.pct(displayedFraction))\(app.showRemaining ? " left" : "")")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(window.usedFraction >= 0.8 ? barColor : .primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(barColor.gradient)
                        .frame(width: max(3, geo.size.width * displayedFraction))
                }
            }
            .frame(height: 5)
            if let resetsAt = window.resetsAt {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(resetsAt > context.date
                         ? "refills in \(Format.countdown(until: resetsAt, from: context.date))"
                         : "refilled · refreshing…")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
