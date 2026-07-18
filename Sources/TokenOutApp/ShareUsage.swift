import SwiftUI
import AppKit
import TokenOutCore
import TokenOutProviders

// MARK: - Data

enum ShareRange: String, CaseIterable, Identifiable {
    case today, week, month
    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: tokenOutLocalized("Today", "Today")
        case .week: tokenOutLocalized("This week", "This week")
        case .month: tokenOutLocalized("Last 30 days", "Last 30 days")
        }
    }

    var days: Int {
        switch self {
        case .today: 1
        case .week: 7
        case .month: 30
        }
    }
}

/// Everything the share card renders, precomputed so the card view is pure
/// and can be rendered offscreen (ImageRenderer) or previewed live.
struct ShareStats {
    struct Entry: Identifiable {
        var id: ProviderID
        var name: String
        var tokens: Int
        var costUSD: Double?
        var costIsEstimated: Bool
    }

    var range: ShareRange
    var dateRangeText: String
    var providers: [Entry]
    /// Daily token totals across selected providers, oldest first, for the bars.
    var bars: [Int]
    /// Insight stats across the selected range.
    var activeDays = 0
    var peakDayText: String?
    var peakDayValue: String?
    /// Models used in the range (pretty names + tokens), heaviest first.
    var models: [(name: String, tokens: Int)] = []

    var totalTokens: Int { providers.reduce(0) { $0 + $1.tokens } }
    var totalCost: Double? {
        let costs = providers.compactMap(\.costUSD)
        return costs.isEmpty ? nil : costs.reduce(0, +)
    }
    var costEstimated: Bool { providers.contains { $0.costIsEstimated } }
    var dailyAvgTokens: Int { totalTokens / max(range.days, 1) }

    /// "claude-opus-4-8" → "Opus 4.8", "gpt-5.6-sol" → "GPT-5.6 Sol".
    static func prettyModel(_ id: String) -> String {
        if id.hasPrefix("claude-") { return ClaudeTranscriptParser.modelFamily(id) }
        if id.hasPrefix("gpt-") {
            let parts = id.split(separator: "-")
            let tail = parts.dropFirst(2).map { $0.prefix(1).uppercased() + $0.dropFirst() }
            return (["GPT-\(parts.count > 1 ? String(parts[1]) : "")"] + tail)
                .joined(separator: " ")
        }
        return id
    }

    static let providerNames: [ProviderID: String] = [
        .claude: "Claude Code", .codex: "Codex", .antigravity: "Antigravity",
    ]

    static func build(snapshots: [UsageSnapshot], selected: Set<ProviderID>,
                      range: ShareRange, now: Date = .now) -> ShareStats {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let rangeStart = calendar.date(byAdding: .day, value: -(range.days - 1), to: startOfToday)!

        var entries: [Entry] = []
        var dailyTotals: [Date: Int] = [:]
        var dailyCosts: [Date: Double] = [:]
        var modelTotals: [String: Int] = [:]
        for snapshot in snapshots where selected.contains(snapshot.providerID) {
            let inRange = snapshot.daily.filter { $0.day >= rangeStart }
            let (tokens, cost, estimated): (Int, Double?, Bool) = switch range {
            case .today:
                (snapshot.tokens?.todayTokens ?? inRange.reduce(0) { $0 + $1.tokens },
                 snapshot.tokens?.todayCostUSD,
                 snapshot.tokens?.costIsEstimated ?? false)
            case .week:
                (snapshot.tokens?.weekTokens ?? inRange.reduce(0) { $0 + $1.tokens },
                 snapshot.tokens?.weekCostUSD,
                 snapshot.tokens?.costIsEstimated ?? false)
            case .month:
                (inRange.reduce(0) { $0 + $1.tokens },
                 inRange.isEmpty ? nil : inRange.reduce(0.0) { $0 + $1.costUSD },
                 inRange.contains { $0.costIsEstimated })
            }
            entries.append(Entry(id: snapshot.providerID,
                                 name: providerNames[snapshot.providerID] ?? snapshot.providerID.rawValue,
                                 tokens: tokens, costUSD: cost, costIsEstimated: estimated))
            for stat in inRange {
                let day = calendar.startOfDay(for: stat.day)
                dailyTotals[day, default: 0] += stat.tokens
                dailyCosts[day, default: 0] += stat.costUSD
                for (model, modelTokens) in stat.byModel ?? [:] where !model.hasPrefix("<") {
                    modelTotals[model, default: 0] += modelTokens
                }
            }
        }

        // Bars always chart the range's days (7 minimum so the card has shape).
        let barDays = max(range.days, 7)
        let bars = (0..<barDays).map { offset -> Int in
            let day = calendar.date(byAdding: .day, value: -(barDays - 1 - offset), to: startOfToday)!
            return dailyTotals[day] ?? 0
        }

        let dayMonth = Date.FormatStyle().month(.abbreviated).day()
        let dateRangeText = range == .today
            ? now.formatted(dayMonth)
            : "\(rangeStart.formatted(dayMonth)) – \(now.formatted(dayMonth))"

        var stats = ShareStats(range: range, dateRangeText: dateRangeText,
                               providers: entries, bars: bars)
        stats.activeDays = dailyTotals.values.filter { $0 > 0 }.count
        if let peak = dailyTotals.max(by: { $0.value < $1.value }), peak.value > 0 {
            stats.peakDayText = peak.key.formatted(dayMonth)
            let peakCost = dailyCosts[peak.key] ?? 0
            stats.peakDayValue = peakCost > 0 ? ShareCardView.money(peakCost)
                                              : Format.tokens(peak.value)
        }
        // Merge dated ids into families ("claude-opus-4-8-20251101" → "Opus 4.8").
        var byPrettyName: [String: Int] = [:]
        for (model, count) in modelTotals {
            byPrettyName[prettyModel(model), default: 0] += count
        }
        stats.models = byPrettyName.sorted { $0.value > $1.value }
            .prefix(4).map { (name: $0.key, tokens: $0.value) }
        return stats
    }
}

// MARK: - Card

/// The shareable image itself. Deliberately theme-independent (always dark,
/// brand orange) so cards look identical wherever they're posted.
struct ShareCardView: View {
    var stats: ShareStats

    private let cardWidth: CGFloat = 480

    /// Card money style: grouped thousands, cents only under $100 — "$29,620",
    /// "$58.31". No approximation marks; this is a presentation piece.
    static func money(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        if value >= 100 {
            formatter.maximumFractionDigits = 0
        } else {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
        }
        return "$" + (formatter.string(from: NSNumber(value: value))
                      ?? String(format: "%.0f", value))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 8) {
                TokenOutMark(size: 22)
                Text("TokenOut")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(stats.range.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(stats.dateRangeText)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Format.tokens(stats.totalTokens))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(tokenOutLocalized("tokens", "tokens"))
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                if let cost = stats.totalCost {
                    Text(String(format: tokenOutLocalized("%@ API-equivalent value",
                                                    "%@ API-equivalent value"),
                                Self.money(cost)))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange)
                }
            }

            insightsRow

            if stats.providers.count > 1 {
                VStack(spacing: 8) {
                    ForEach(stats.providers) { entry in
                        let share = stats.totalTokens > 0
                            ? Double(entry.tokens) / Double(stats.totalTokens) : 0
                        HStack(spacing: 8) {
                            ProviderLogo(providerID: entry.id, size: 16)
                            Text(entry.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("\(Int((share * 100).rounded()))%")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                            Spacer()
                            Text(Format.tokens(entry.tokens))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            if let cost = entry.costUSD {
                                Text(Self.money(cost))
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .frame(minWidth: 64, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(alignment: .bottomLeading) {
                            GeometryReader { geo in
                                Capsule()
                                    .fill(.orange.opacity(0.65))
                                    .frame(width: max(6, geo.size.width * share), height: 3)
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                                    .padding(.leading, 14).padding(.bottom, 4)
                            }
                        }
                    }
                }
            } else if let single = stats.providers.first {
                HStack(spacing: 7) {
                    ProviderLogo(providerID: single.id, size: 15)
                    Text(single.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }

            modelsRow

            chart

            HStack {
                Text(tokenOutLocalized("My AI usage", "My AI usage"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text("tokenout.scrubmac.app")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.orange.opacity(0.9))
            }
        }
        .padding(30)
        .frame(width: cardWidth)
        .background {
            ZStack {
                LinearGradient(colors: [Color(red: 0.09, green: 0.08, blue: 0.10),
                                        Color(red: 0.14, green: 0.09, blue: 0.06)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(.orange.opacity(0.16))
                    .frame(width: 320, height: 320)
                    .blur(radius: 80)
                    .offset(x: 170, y: -130)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .environment(\.colorScheme, .dark)
    }

    private var chart: some View {
        let peak = max(stats.bars.max() ?? 1, 1)
        let peakIndex = stats.bars.firstIndex(of: stats.bars.max() ?? 0)
        let barWidth: CGFloat = stats.bars.count > 10 ? 9 : 26
        return HStack(alignment: .bottom, spacing: stats.bars.count > 10 ? 4 : 8) {
            ForEach(Array(stats.bars.enumerated()), id: \.offset) { index, value in
                RoundedRectangle(cornerRadius: barWidth / 3)
                    .fill(index == peakIndex
                          ? AnyShapeStyle(Color(red: 1.0, green: 0.32, blue: 0.24).gradient)
                          : index == stats.bars.count - 1
                          ? AnyShapeStyle(.orange.gradient)
                          : AnyShapeStyle(.orange.opacity(0.5).gradient))
                    .frame(width: barWidth, height: max(5, 58 * Double(value) / Double(peak)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: 58, alignment: .bottom)
    }

    /// Quick-read insights: daily average, peak day, top model. Only shown for
    /// multi-day ranges where the numbers actually mean something.
    @ViewBuilder
    private var insightsRow: some View {
        if stats.range != .today {
            HStack(spacing: 0) {
                insight(label: tokenOutLocalized("Daily avg", "Daily avg"),
                        value: Format.tokens(stats.dailyAvgTokens),
                        sub: tokenOutLocalized("tokens", "tokens"))
                divider
                insight(label: tokenOutLocalized("Peak day", "Peak day"),
                        value: stats.peakDayValue ?? "—",
                        sub: stats.peakDayText ?? "")
                divider
                insight(label: tokenOutLocalized("Active days", "Active days"),
                        value: "\(stats.activeDays)",
                        sub: String(format: tokenOutLocalized("of %d", "of %d"), stats.range.days))
            }
        }
    }

    /// The most-used models: up to four chips, heaviest first.
    @ViewBuilder
    private var modelsRow: some View {
        if !stats.models.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                Text(tokenOutLocalized("Models", "Models").uppercased())
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(.white.opacity(0.4))
                HStack(spacing: 7) {
                    ForEach(stats.models, id: \.name) { model in
                        HStack(spacing: 5) {
                            Text(model.name)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                            Text(Format.tokens(model.tokens))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.orange.opacity(0.9))
                        }
                        .lineLimit(1)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.white.opacity(0.06), in: Capsule())
                    }
                }
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 34)
            .padding(.horizontal, 16)
    }

    private func insight(label: String, value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.4))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Export

@MainActor
enum ShareCardRenderer {
    static func pngData(for stats: ShareStats) -> Data? {
        let renderer = ImageRenderer(content: ShareCardView(stats: stats))
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    /// Writes the card into a temp file whose name is what recipients will see
    /// in AirDrop/Messages, so it should read well: "TokenOut Usage.png".
    static func temporaryPNGURL(for stats: ShareStats) -> URL? {
        guard let data = pngData(for: stats) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appending(path: "TokenOut Usage \(stats.dateRangeText).png")
        try? data.write(to: url)
        return url
    }
}

// MARK: - Composer window

/// Anchor for NSSharingServicePicker, which needs a real NSView to attach to.
private struct ShareAnchorView: NSViewRepresentable {
    var onReady: (NSView) -> Void
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onReady(view) }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ShareComposerView: View {
    @Environment(AppState.self) private var app
    @State private var selected: Set<ProviderID> = []
    @State private var range: ShareRange = .week
    @State private var shareAnchor: NSView?
    @State private var activePicker: NSSharingServicePicker?
    @State private var copied = false

    /// Providers that actually have data to share.
    private var available: [ProviderID] {
        app.providers.map { type(of: $0).id }.filter { id in
            app.installed.contains(id) && app.store.states[id]?.snapshot != nil
        }
    }

    private var snapshots: [UsageSnapshot] {
        available.compactMap { app.store.states[$0]?.snapshot }
    }

    private var stats: ShareStats {
        ShareStats.build(snapshots: snapshots, selected: selected, range: range)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Live preview, scaled to fit.
            ZStack {
                Color(nsColor: .underPageBackgroundColor)
                ShareCardView(stats: stats)
                    .scaleEffect(0.72)
                    .frame(width: 480 * 0.72)
            }
            .frame(width: 400)
            .clipped()

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                Text(tokenOutLocalized("Share usage", "Share usage"))
                    .tokenOutFont(17, weight: .bold)

                VStack(alignment: .leading, spacing: 8) {
                    Text(tokenOutLocalized("Include", "Include").uppercased())
                        .tokenOutFont(10, weight: .semibold)
                        .foregroundStyle(.tertiary)
                    ForEach(available, id: \.self) { id in
                        Toggle(isOn: providerBinding(id)) {
                            HStack(spacing: 6) {
                                ProviderLogo(providerID: id, size: 14)
                                Text(ShareStats.providerNames[id] ?? id.rawValue)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(tokenOutLocalized("Range", "Range").uppercased())
                        .tokenOutFont(10, weight: .semibold)
                        .foregroundStyle(.tertiary)
                    Picker("", selection: $range) {
                        ForEach(ShareRange.allCases) { r in
                            Text(r.title).tag(r)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }

                Spacer()

                VStack(spacing: 8) {
                    Button {
                        share()
                    } label: {
                        Label(tokenOutLocalized("Share", "Share"), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .disabled(selected.isEmpty)
                    .background(ShareAnchorView { shareAnchor = $0 })

                    HStack(spacing: 8) {
                        Button {
                            copyImage()
                        } label: {
                            Label(copied ? tokenOutLocalized("Copied ✓", "Copied ✓")
                                         : tokenOutLocalized("Copy image", "Copy image"),
                                  systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        Button {
                            savePNG()
                        } label: {
                            Label(tokenOutLocalized("Save as PNG…", "Save as PNG…"),
                                  systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(selected.isEmpty)
                }
            }
            .padding(20)
            .frame(width: 300)
        }
        .frame(width: 700, height: 520)
        .onAppear {
            if selected.isEmpty { selected = Set(available) }
        }
    }

    private func providerBinding(_ id: ProviderID) -> Binding<Bool> {
        Binding(
            get: { selected.contains(id) },
            set: { include in
                if include { selected.insert(id) }
                else if selected.count > 1 { selected.remove(id) }
            }
        )
    }

    private func share() {
        guard let anchor = shareAnchor,
              let url = ShareCardRenderer.temporaryPNGURL(for: stats) else { return }
        let picker = NSSharingServicePicker(items: [url])
        activePicker = picker  // keep alive while the menu is up
        picker.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
    }

    private func copyImage() {
        guard let data = ShareCardRenderer.pngData(for: stats),
              let image = NSImage(data: data) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { copied = false }
    }

    private func savePNG() {
        guard let data = ShareCardRenderer.pngData(for: stats) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "TokenOut Usage \(stats.dateRangeText).png"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }
}

/// Standalone window host, mirroring OnboardingWindow's pattern.
@MainActor
enum ShareWindow {
    private static var window: NSWindow?

    static func show(app: AppState) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(
            rootView: ShareComposerView().environment(app).tokenOutAppearance(app))
        let win = NSWindow(contentViewController: hosting)
        win.title = tokenOutLocalized("Share usage", "Share usage")
        win.styleMask = [.titled, .closable]
        win.appearance = app.theme.nsAppearance
        win.isReleasedWhenClosed = false
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = win
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: win, queue: .main
        ) { _ in
            Task { @MainActor in ShareWindow.window = nil }
        }
    }
}
