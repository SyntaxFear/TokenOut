import SwiftUI
import BurnBarCore

struct ProviderCard: View {
    var displayName: String
    var state: ProviderState

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
        }
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
