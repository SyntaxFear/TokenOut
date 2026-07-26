import SwiftUI
import TokenOutCore

struct ProviderCard: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    var providerID: ProviderID
    var displayName: String
    var state: ProviderState
    /// Single-provider focus mode: show extra rows the compact list omits.
    var focused: Bool = false
    @State private var expanded = false

    private var canExpand: Bool {
        guard state.snapshot != nil else { return false }
        switch state.status {
        case .signedOut, .unsupported: return false
        default: return true
        }
    }

    private var expansionAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : .spring(response: 0.32, dampingFraction: 1.0)
    }

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
                    if expanded {
                        expandedContent(snapshot)
                    } else {
                        compactContent(snapshot)
                    }
                } else {
                    statusMessage(icon: "hourglass", text: "Waiting for first fetch…")
                }
            }
        }
        .padding(expanded ? 12 : 11)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(cardStroke, lineWidth: 0.75)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.16 : 0.10),
                        radius: expanded ? 12 : 8, y: 3)
        }
        .onAppear { expanded = focused }
        .onChange(of: focused) { _, isFocused in
            withAnimation(expansionAnimation) { expanded = isFocused }
        }
    }

    @ViewBuilder
    private var header: some View {
        if canExpand {
            Button {
                withAnimation(expansionAnimation) { expanded.toggle() }
            } label: {
                headerContents
            }
            .buttonStyle(TokenOutPressButtonStyle())
            .clickable()
            .help(expanded ? "Collapse" : "Expand")
            .accessibilityLabel(expanded
                                ? "Collapse \(displayName) details"
                                : "Expand \(displayName) details")
        } else {
            headerContents
        }
    }

    private var headerContents: some View {
        HStack(spacing: 6) {
            ProviderLogo(providerID: providerID, size: 14)
            Text(displayName).tokenOutFont(13, weight: .semibold)
            if let account = state.snapshot?.accountLabel {
                Text(account)
                    .tokenOutFont(10, weight: .medium)
                    .padding(.horizontal, 5).padding(.vertical, 1.5)
                    .background(Color.primary.opacity(0.09), in: Capsule())
            }
            Spacer()
            if app.refreshing.contains(providerID) {
                ProgressView().controlSize(.small).scaleEffect(0.5)
                    .help("Fetching fresh data…")
            }
            statusBadge
            if canExpand {
                Image(systemName: "chevron.right")
                    .tokenOutFont(9, weight: .semibold)
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .frame(width: 12, height: 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(expanded ? 0.075 : 0.055)
            : Color.black.opacity(expanded ? 0.050 : 0.035)
    }

    private var cardStroke: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.13 : 0.72),
                Color.primary.opacity(0.035),
                Color.primary.opacity(0.08),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch state.status {
        case .ok:
            EmptyView()
        case .stale(let since) where since > .distantPast:
            Label("Stale", systemImage: "wifi.exclamationmark")
                .tokenOutFont(10).foregroundStyle(.secondary)
                .help("Last update \(since.formatted(.relative(presentation: .named)))")
        case .stale:
            EmptyView()
        case .signedOut:
            Label("Signed out", systemImage: "lock").tokenOutFont(10).foregroundStyle(.orange)
        case .unsupported:
            EmptyView()
        }
    }

    @ViewBuilder
    private func compactContent(_ snapshot: UsageSnapshot) -> some View {
        let windows = UsageMath.compactWindows(in: snapshot)
        if !windows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(windows, id: \.label) { window in
                    CompactWindowRow(window: window)
                }
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "gauge.with.dots.needle.0percent")
                    .foregroundStyle(.secondary)
                Text("Quota unavailable")
                    .tokenOutFont(11, weight: .medium)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }

        if let tokens = snapshot.tokens {
            CompactTodayUsage(tokens: tokens)
        }
    }

    @ViewBuilder
    private func expandedContent(_ snapshot: UsageSnapshot) -> some View {
        if Date.now.timeIntervalSince(snapshot.fetchedAt) > 15 * 60 {
            Label {
                Text("Data from \(snapshot.fetchedAt.formatted(.relative(presentation: .named))) — numbers below may be outdated. Hit Refresh (and answer any Keychain prompt).")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "clock.badge.exclamationmark")
            }
            .tokenOutFont(10)
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
                    .tokenOutFont(10)
                    .foregroundStyle(.orange)
                }
            }
        }
        // Totals live inside the Daily-usage tile grid; the standalone tiles
        // only appear when that section is hidden or has no data.
        let showsChart = app.showDailyCharts && !snapshot.daily.isEmpty
        if !showsChart, let tokens = snapshot.tokens {
            UsageSummaryTiles(tokens: tokens)
        }
        if app.showBreakdowns {
            ForEach(snapshot.breakdowns, id: \.title) { breakdown in
                BreakdownView(breakdown: breakdown)
            }
        }
        if showsChart {
            DailyChartView(daily: snapshot.daily, tokens: snapshot.tokens)
        }
        if focused {
            HStack {
                Text("Updated").tokenOutFont(11).foregroundStyle(.secondary)
                Spacer()
                Text(snapshot.fetchedAt.formatted(.relative(presentation: .named)))
                    .tokenOutFont(11).foregroundStyle(.secondary)
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
            Text(text).tokenOutFont(11).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CompactTodayUsage: View {
    @Environment(\.colorScheme) private var colorScheme
    var tokens: TokenTotals

    private var estimatedTokenMark: String {
        tokens.costIsEstimated && tokens.todayCostUSD == nil ? "~" : ""
    }

    private var estimatedCostMark: String {
        tokens.costIsEstimated ? "~" : ""
    }

    var body: some View {
        HStack(spacing: 9) {
            CompactMetricIcon(systemName: "chart.bar.xaxis")
            VStack(alignment: .leading, spacing: 1) {
                Text("Today")
                    .tokenOutFont(11, weight: .semibold)
                Text("Local usage")
                    .tokenOutFont(9.5, weight: .medium)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                MetricValueText(value: "\(estimatedTokenMark)\(Format.tokens(tokens.todayTokens)) tokens",
                                size: 11.5, weight: .semibold, design: .rounded)
                if let cost = tokens.todayCostUSD, cost > 0 {
                    MetricValueText(value: "\(estimatedCostMark)\(Format.usd(cost)) value",
                                    size: 9.5, weight: .medium, design: .default)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 7.5)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.055)
                                           : Color.black.opacity(0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.60),
                                      lineWidth: 0.5)
                }
        }
    }
}

private enum LimitVisualStyle {
    static func fill(for usedFraction: Double) -> Color {
        switch usedFraction {
        case 0.95...: .red
        case 0.80...: .orange
        default: Color.primary.opacity(0.56)
        }
    }

    static func value(for usedFraction: Double) -> Color {
        switch usedFraction {
        case 0.95...: .red
        case 0.80...: .orange
        default: .primary
        }
    }

    static func pace(for window: LimitWindow, delta: Double) -> Color {
        guard delta >= 0.02 else { return .secondary }
        return window.usedFraction >= 0.95 ? .red : .orange
    }
}

private struct CompactWindowRow: View {
    @Environment(AppState.self) private var app
    var window: LimitWindow

    private var displayedFraction: Double {
        app.showRemaining ? 1 - window.usedFraction : window.usedFraction
    }

    private var iconName: String {
        switch window.kind {
        case .session: "timer"
        case .weekly: "calendar"
        case .credits: "circle.grid.2x2"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            CompactMetricIcon(systemName: iconName,
                              attention: window.usedFraction >= 0.80)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(window.label)
                        .tokenOutFont(11, weight: .semibold)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("\(Format.pct(displayedFraction))\(app.showRemaining ? " left" : " used")")
                        .tokenOutFont(11.5, weight: .semibold, monospacedDigit: true)
                        .foregroundStyle(LimitVisualStyle.value(for: window.usedFraction))
                }
                limitBar(fraction: displayedFraction, usedFraction: window.usedFraction)
                if let resetsAt = window.resetsAt {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        HStack(spacing: 6) {
                            if resetsAt > context.date {
                                Text(String(format: tokenOutLocalized("refills in %1$@ · at %2$@",
                                                                "refills in %1$@ · at %2$@"),
                                            Format.humanCountdown(until: resetsAt, from: context.date),
                                            Format.resetClock(resetsAt, now: context.date)))
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 4)
                                PaceText(window: window, now: context.date)
                            } else {
                                Text(tokenOutLocalized("refilled · refreshing…", "refilled · refreshing…"))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tokenOutFont(9.5, weight: .medium, monospacedDigit: true)
                        .lineLimit(1)
                    }
                }
            }
        }
    }
}

private struct CompactMetricIcon: View {
    @Environment(\.colorScheme) private var colorScheme
    var systemName: String
    var attention = false

    var body: some View {
        Image(systemName: systemName)
            .symbolRenderingMode(.monochrome)
            .tokenOutFont(11.5, weight: .semibold)
            .foregroundStyle(attention ? Color.orange : Color.secondary)
            .frame(width: 27, height: 27)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.065)
                                               : Color.black.opacity(0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.64),
                                          lineWidth: 0.5)
                    }
            }
            .accessibilityHidden(true)
    }
}

private struct PaceText: View {
    var window: LimitWindow
    var now: Date

    var body: some View {
        if window.usedFraction > 0.02, let delta = window.paceDelta(now: now) {
            let deltaText = Format.pct(abs(delta))
            Group {
                if delta >= 0.02 {
                    Text(String(format: tokenOutLocalized("%@ over pace", "%@ over pace"), deltaText))
                } else if delta <= -0.02 {
                    Text(String(format: tokenOutLocalized("%@ in reserve", "%@ in reserve"), deltaText))
                } else {
                    Text(tokenOutLocalized("on pace", "on pace"))
                }
            }
            .foregroundStyle(LimitVisualStyle.pace(for: window, delta: delta))
            .help(String(format: tokenOutLocalized("Used %1$@ of the quota with %2$@ of the window elapsed",
                                             "Used %1$@ of the quota with %2$@ of the window elapsed"),
                         Format.pct(window.usedFraction),
                         Format.pct(window.elapsedFraction(now: now) ?? 0)))
        }
    }
}

private func limitBar(fraction: Double, usedFraction: Double) -> some View {
    GeometryReader { geo in
        ZStack(alignment: .leading) {
            Capsule().fill(Color.primary.opacity(0.10))
            Capsule()
                .fill(LimitVisualStyle.fill(for: usedFraction))
                .frame(width: max(fraction > 0 ? 3 : 0, geo.size.width * fraction))
        }
    }
    .frame(height: 4)
    .accessibilityHidden(true)
}

struct BreakdownView: View {
    var breakdown: Breakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(breakdown.title)
                .tokenOutFont(9.5, weight: .semibold)
                .foregroundStyle(.secondary)
            ForEach(breakdown.rows, id: \.name) { row in
                HStack(spacing: 6) {
                    Text(row.name)
                        .tokenOutFont(10.5, weight: .medium)
                        .lineLimit(1)
                        .frame(width: 92, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.09))
                            Capsule().fill(Color.primary.opacity(0.42))
                                .frame(width: max(2, geo.size.width * row.fraction))
                        }
                    }
                    .frame(height: 4)
                    Text(row.valueText)
                        .tokenOutFont(10, monospacedDigit: true)
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

    /// Global display logic: "left" drains to 0% (default), "used" fills to 100%.
    private var displayedFraction: Double {
        app.showRemaining ? 1 - window.usedFraction : window.usedFraction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.label).tokenOutFont(11, weight: .medium).foregroundStyle(.secondary)
                Spacer()
                Text("\(Format.pct(displayedFraction))\(app.showRemaining ? " left" : "")")
                    .tokenOutFont(11.5, weight: .semibold, monospacedDigit: true)
                    .foregroundStyle(LimitVisualStyle.value(for: window.usedFraction))
            }
            limitBar(fraction: displayedFraction, usedFraction: window.usedFraction)
            if let resetsAt = window.resetsAt {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    HStack(spacing: 6) {
                        if resetsAt > context.date {
                            Text(String(format: tokenOutLocalized("refills in %1$@ · at %2$@",
                                                            "refills in %1$@ · at %2$@"),
                                        Format.humanCountdown(until: resetsAt, from: context.date),
                                        Format.resetClock(resetsAt, now: context.date)))
                                .foregroundStyle(.tertiary)
                            Spacer(minLength: 4)
                            PaceText(window: window, now: context.date)
                        } else {
                            Text(tokenOutLocalized("refilled · refreshing…", "refilled · refreshing…"))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .tokenOutFont(10, weight: .medium, monospacedDigit: true)
                    .lineLimit(1)
                }
            }
        }
    }

}
