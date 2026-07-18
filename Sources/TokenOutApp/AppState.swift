import Foundation
import AppKit
import SwiftUI
import Observation
import TokenOutCore
import TokenOutProviders

enum ChartMetric: String, CaseIterable {
    case cost, tokens
    var title: String { self == .cost ? "$" : "Tok" }
}

/// What the menu bar label is composed of — freely combinable so everyone can
/// build the readout they want (icon-only minimalists to cost-watchers).
struct MenuBarComponents: Equatable {
    var icon = true
    var gauge = true
    var percent = true
    var providerSplit = false
    var todayTokens = false
    var todayCost = false

    /// An entirely empty menu bar item would be unclickable — fall back to icon.
    var resolved: MenuBarComponents {
        var value = self
        if !value.icon && !value.gauge && !value.percent
            && !value.providerSplit && !value.todayTokens && !value.todayCost {
            value.icon = true
        }
        return value
    }

    static func load(from defaults: UserDefaults) -> MenuBarComponents {
        var value = MenuBarComponents()
        // Migrate the old preset picker once, then persist per-component.
        if let legacy = defaults.string(forKey: "menuBarStyle") {
            switch legacy {
            case "iconOnly": value.percent = false
            case "percentOnly": value.icon = false; value.gauge = false
            case "allProviders": value.percent = false; value.providerSplit = true
            default: break
            }
            defaults.removeObject(forKey: "menuBarStyle")
            value.save(to: defaults)
            return value
        }
        func flag(_ key: String, _ fallback: Bool) -> Bool {
            defaults.object(forKey: key) as? Bool ?? fallback
        }
        value.icon = flag("mbIcon", true)
        value.gauge = flag("mbGauge", true)
        value.percent = flag("mbPercent", true)
        value.providerSplit = flag("mbProviderSplit", false)
        value.todayTokens = flag("mbTodayTokens", false)
        value.todayCost = flag("mbTodayCost", false)
        return value
    }

    func save(to defaults: UserDefaults) {
        defaults.set(icon, forKey: "mbIcon")
        defaults.set(gauge, forKey: "mbGauge")
        defaults.set(percent, forKey: "mbPercent")
        defaults.set(providerSplit, forKey: "mbProviderSplit")
        defaults.set(todayTokens, forKey: "mbTodayTokens")
        defaults.set(todayCost, forKey: "mbTodayCost")
    }
}

enum MenuBarMetric: String, CaseIterable {
    case tightest
    case claude, codex

    var title: String {
        switch self {
        case .tightest: tokenOutLocalized("Tightest limit", "Tightest limit")
        case .claude: "Claude Code"
        case .codex: "Codex"
        }
    }

    var providerID: ProviderID? {
        switch self {
        case .tightest: nil
        case .claude: .claude
        case .codex: .codex
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: tokenOutLocalized("Theme.system", "System")
        case .light: tokenOutLocalized("Theme.light", "Light")
        case .dark: tokenOutLocalized("Theme.dark", "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// `.preferredColorScheme` alone doesn't reliably reach a MenuBarExtra's
    /// popover window — it's not a regular WindowGroup/Window scene. Setting
    /// NSApp's appearance directly covers every window/popover app-wide,
    /// menu-bar extra included, and takes effect immediately (no relaunch).
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

enum AppFontSize: String, CaseIterable, Identifiable {
    case small, medium, large, extraLarge
    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: tokenOutLocalized("FontSize.small", "Small")
        case .medium: tokenOutLocalized("FontSize.medium", "Medium")
        case .large: tokenOutLocalized("FontSize.large", "Large")
        case .extraLarge: tokenOutLocalized("FontSize.extraLarge", "Extra Large")
        }
    }

    /// Multiplier applied to every point size in the app via `tokenOutFont`.
    var scale: CGFloat {
        switch self {
        case .small: 0.9
        case .medium: 1.0
        case .large: 1.12
        case .extraLarge: 1.28
        }
    }
}

enum RefreshCadence: String, CaseIterable {
    case fast, normal, relaxed

    var title: String {
        switch self {
        case .fast: tokenOutLocalized("Fast (30 s)", "Fast (30 s)")
        case .normal: tokenOutLocalized("Normal (60 s)", "Normal (60 s)")
        case .relaxed: tokenOutLocalized("Relaxed (5 min)", "Relaxed (5 min)")
        }
    }

    var policy: RefreshPolicy {
        switch self {
        case .fast: RefreshPolicy(hotInterval: 30, coldInterval: 120)
        case .normal: RefreshPolicy()
        case .relaxed: RefreshPolicy(hotInterval: 300, coldInterval: 600)
        }
    }
}

@MainActor
@Observable
final class AppState {
    private static let supportedProviderIDs: Set<ProviderID> = [.claude, .codex]

    let store: UsageStore
    let history: HistoryStore
    let providers: [any UsageProvider] = [ClaudeProvider(), CodexProvider()]
    private(set) var installed: Set<ProviderID> = []
    private var refreshTasks: [ProviderID: Task<Void, Never>] = [:]
    /// Providers with a fetch in flight (drives spinners).
    private(set) var refreshing: Set<ProviderID> = []
    /// Manual-refresh cooldown so the button can't be hammered.
    private(set) var refreshCoolingDown = false
    /// Outcome of the last manual refresh, for honest button feedback.
    enum RefreshOutcome { case idle, succeeded, failed }
    private(set) var lastRefreshOutcome: RefreshOutcome = .idle
    private var failureCounts: [ProviderID: Int] = [:]
    /// After an HTTP 429, no requests to that provider before this moment.
    private var rateLimitedUntil: [ProviderID: Date] = [:]
    private let notifier = Notifier()

    // MARK: Settings (UserDefaults-backed)

    var enabledProviders: Set<ProviderID> {
        didSet {
            UserDefaults.standard.set(enabledProviders.map(\.rawValue).sorted(), forKey: "enabledProviders")
            restartLoops()
        }
    }
    var menuBarMetric: MenuBarMetric {
        didSet { UserDefaults.standard.set(menuBarMetric.rawValue, forKey: "menuBarMetric") }
    }
    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") }
    }
    var fontSize: AppFontSize {
        didSet { UserDefaults.standard.set(fontSize.rawValue, forKey: "fontSize") }
    }
    var fontFamily: AppFontFamily {
        didSet { UserDefaults.standard.set(fontFamily.rawValue, forKey: "fontFamily") }
    }
    var appLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: "appLanguage")
            Self.applyLanguageOverride(appLanguage)
        }
    }
    /// Which Settings tab is showing. Lives here (not @State) so it survives the
    /// full view rebuild that a live language switch triggers.
    var settingsTab: SettingsTab = .general

    /// Takes effect immediately: Bundle.setLanguage redirects string lookups
    /// right now, and AppleLanguages keeps system-provided strings and
    /// formatters consistent from the next launch on.
    static func applyLanguageOverride(_ language: AppLanguage) {
        Bundle.setLanguage(language.localeIdentifier)
        if let identifier = language.localeIdentifier {
            UserDefaults.standard.set([identifier], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }
    var menuBarComponents: MenuBarComponents {
        didSet { menuBarComponents.save(to: UserDefaults.standard) }
    }
    var showRemaining: Bool {
        didSet { UserDefaults.standard.set(showRemaining, forKey: "showRemaining") }
    }
    /// Daily-chart range in days: 7, 30, 60, or 90.
    var dailyRange: Int {
        didSet { UserDefaults.standard.set(dailyRange, forKey: "dailyRange") }
    }
    /// Popover focus: nil = all providers, or a single preferred provider.
    var popoverFocus: ProviderID? {
        didSet { UserDefaults.standard.set(popoverFocus?.rawValue ?? "all", forKey: "popoverFocus") }
    }
    /// What daily charts plot: dollars (default — matches the tiles) or raw tokens.
    var chartMetric: ChartMetric {
        didSet { UserDefaults.standard.set(chartMetric.rawValue, forKey: "chartMetric") }
    }
    var showDailyCharts: Bool {
        didSet { UserDefaults.standard.set(showDailyCharts, forKey: "showDailyCharts") }
    }
    var showBreakdowns: Bool {
        didSet { UserDefaults.standard.set(showBreakdowns, forKey: "showBreakdowns") }
    }
    var cadence: RefreshCadence {
        didSet {
            UserDefaults.standard.set(cadence.rawValue, forKey: "cadence")
            restartLoops()
        }
    }
    var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
            if notificationsEnabled { notifier.requestAuthorization() }
        }
    }
    var warningThreshold: Double {
        didSet { UserDefaults.standard.set(warningThreshold, forKey: "warningThreshold") }
    }
    var criticalThreshold: Double {
        didSet { UserDefaults.standard.set(criticalThreshold, forKey: "criticalThreshold") }
    }
    var refillNotifications: Bool {
        didSet { UserDefaults.standard.set(refillNotifications, forKey: "refillNotifications") }
    }
    var hasOnboarded: Bool {
        didSet { UserDefaults.standard.set(hasOnboarded, forKey: "hasOnboarded") }
    }

    init(previewSnapshots: [UsageSnapshot]? = nil) {
        if previewSnapshots == nil {
            store = UsageStore()
            history = HistoryStore()
        } else {
            let previewRoot = FileManager.default.temporaryDirectory
                .appending(path: "TokenOut-MarketingPreview-\(UUID().uuidString)")
            store = UsageStore(persistenceURL: previewRoot.appending(path: "state.json"))
            history = HistoryStore(url: previewRoot.appending(path: "history.jsonl"))
        }

        let defaults = UserDefaults.standard
        let storedEnabled = defaults.stringArray(forKey: "enabledProviders")?
            .compactMap(ProviderID.init(rawValue:))
        enabledProviders = storedEnabled
            .map { Set($0).intersection(Self.supportedProviderIDs) }
            ?? Self.supportedProviderIDs
        menuBarMetric = defaults.string(forKey: "menuBarMetric")
            .flatMap(MenuBarMetric.init(rawValue:)) ?? .tightest
        menuBarComponents = MenuBarComponents.load(from: defaults)
        theme = defaults.string(forKey: "theme").flatMap(AppTheme.init(rawValue:)) ?? .system
        fontSize = defaults.string(forKey: "fontSize").flatMap(AppFontSize.init(rawValue:)) ?? .medium
        fontFamily = defaults.string(forKey: "fontFamily").flatMap(AppFontFamily.init(rawValue:)) ?? .system
        let resolvedLanguage = defaults.string(forKey: "appLanguage").flatMap(AppLanguage.init(rawValue:)) ?? .system
        appLanguage = resolvedLanguage
        Self.applyLanguageOverride(resolvedLanguage)
        // Default to "what's left" (drains to 0%) — the planning-first mental
        // model. Users who prefer a filling meter can switch in Settings →
        // Display; an existing saved choice is respected.
        showRemaining = defaults.object(forKey: "showRemaining") as? Bool ?? true
        let storedRange = defaults.integer(forKey: "dailyRange")
        dailyRange = [7, 30, 60, 90].contains(storedRange) ? storedRange : 30
        let storedFocus = defaults.string(forKey: "popoverFocus").flatMap(ProviderID.init(rawValue:))
        popoverFocus = storedFocus.flatMap { Self.supportedProviderIDs.contains($0) ? $0 : nil }
        chartMetric = defaults.string(forKey: "chartMetric")
            .flatMap(ChartMetric.init(rawValue:)) ?? .cost
        showDailyCharts = defaults.object(forKey: "showDailyCharts") as? Bool ?? true
        showBreakdowns = defaults.object(forKey: "showBreakdowns") as? Bool ?? true
        cadence = defaults.string(forKey: "cadence")
            .flatMap(RefreshCadence.init(rawValue:)) ?? .normal
        notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        let storedWarning = defaults.double(forKey: "warningThreshold")
        warningThreshold = storedWarning > 0 ? storedWarning : 0.8
        let storedCritical = defaults.double(forKey: "criticalThreshold")
        criticalThreshold = storedCritical > 0 ? storedCritical : 0.95
        refillNotifications = defaults.object(forKey: "refillNotifications") as? Bool ?? true
        hasOnboarded = defaults.bool(forKey: "hasOnboarded")

        if let previewSnapshots {
            let previewIDs = Set(previewSnapshots.map(\.providerID))
            // Set enabled IDs while `installed` is still empty so the didSet does
            // not start provider refresh loops in deterministic marketing previews.
            enabledProviders = previewIDs
            installed = previewIDs
            popoverFocus = nil
            dailyRange = 7
            chartMetric = .cost
            showRemaining = false
            showDailyCharts = true
            showBreakdowns = true
            notificationsEnabled = false
            refillNotifications = false
            hasOnboarded = true
            for snapshot in previewSnapshots {
                store.apply(result: .success(snapshot), for: snapshot.providerID)
                history.record(snapshot: snapshot)
            }
        } else {
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.refreshAll() }
            }

            Task { await detectAndStart() }
        }
    }

    func detectAndStart() async {
        var found: Set<ProviderID> = []
        for provider in providers where await provider.detectInstallation() {
            found.insert(type(of: provider).id)
        }
        installed = found
        restartLoops()
    }

    // MARK: Refresh loops

    var activeProviders: [any UsageProvider] {
        providers.filter { installed.contains(type(of: $0).id) && enabledProviders.contains(type(of: $0).id) }
    }

    func restartLoops() {
        refreshTasks.values.forEach { $0.cancel() }
        refreshTasks = [:]
        for provider in activeProviders { startLoop(provider) }
    }

    private func startLoop(_ provider: any UsageProvider) {
        let id = type(of: provider).id
        refreshTasks[id] = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.fetchOnce(provider)
                let interval = self.nextInterval(for: id)
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    /// No provider fetch may wedge the loop — a blocked Keychain prompt once froze
    /// refreshes overnight while the UI kept showing stale numbers.
    private func withTimeout<T: Sendable>(
        seconds: TimeInterval, _ op: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await op() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw ProviderError.network("timed out — waiting on a system prompt?")
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func fetchOnce(_ provider: any UsageProvider) async {
        let id = type(of: provider).id
        // A manual refresh (or popover open) restarts loops and fetches right
        // away — but a 429 cooldown outranks even the refresh button.
        if let blockedUntil = rateLimitedUntil[id], blockedUntil > .now { return }
        refreshing.insert(id)
        defer { refreshing.remove(id) }
        do {
            let snapshot = try await withTimeout(seconds: 180) { try await provider.fetchUsage() }
            failureCounts[id] = 0
            store.apply(result: .success(snapshot), for: id)
            history.record(snapshot: snapshot)
            if notificationsEnabled {
                notifier.evaluate(
                    snapshot: snapshot,
                    displayName: provider.displayName,
                    warningThreshold: warningThreshold,
                    criticalThreshold: criticalThreshold,
                    refillNotifications: refillNotifications
                )
            }
        } catch {
            failureCounts[id, default: 0] += 1
            if case ProviderError.rateLimited(let retryAfter) = error {
                // Honor Retry-After, and never re-poll a throttled endpoint in
                // under 5 minutes — usage percentages don't move that fast.
                rateLimitedUntil[id] = Date.now.addingTimeInterval(max(retryAfter ?? 0, 300))
            }
            store.apply(result: .failure(error), for: id)
        }
    }

    private func nextInterval(for id: ProviderID) -> TimeInterval {
        let maxUtilization = store.states[id]?.snapshot?.windows
            .map(\.usedFraction).max() ?? 0
        let base = cadence.policy.interval(
            maxUtilization: maxUtilization,
            consecutiveFailures: failureCounts[id] ?? 0)
        let jittered = base * RefreshPolicy.jitter(seed: Date.now.timeIntervalSince1970)
        if let blockedUntil = rateLimitedUntil[id] {
            return max(jittered, blockedUntil.timeIntervalSince(.now))
        }
        return jittered
    }

    func refreshAll() {
        guard !refreshCoolingDown else { return }
        refreshCoolingDown = true
        lastRefreshOutcome = .idle
        restartLoops()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard let self else { return }
            // Judge success by whether every active provider ended in a healthy state.
            let ok = self.activeProviders.allSatisfy {
                self.store.states[type(of: $0).id]?.status == .ok
            }
            self.lastRefreshOutcome = ok ? .succeeded : .failed
            self.refreshCoolingDown = false
        }
    }

    /// Popover-open refresh: only when the newest data is older than 2 min.
    /// Anything tighter turns every popover peek into remote API pressure.
    func refreshIfStale() {
        let newest = store.states.values.compactMap(\.snapshot?.fetchedAt).max()
        guard newest.map({ Date.now.timeIntervalSince($0) > 120 }) ?? true else { return }
        refreshAll()
    }

    /// Compact per-provider readings for the all-providers menu bar style.
    var compactReadings: [(letter: String, fraction: Double)] {
        let letters: [ProviderID: String] = [.claude: "C", .codex: "X"]
        return [ProviderID.claude, .codex].compactMap { id in
            guard enabledProviders.contains(id), installed.contains(id),
                  let snapshot = store.states[id]?.snapshot,
                  let tightest = UsageMath.tightest(in: [snapshot]) else { return nil }
            return (letters[id] ?? "?", tightest.window.usedFraction)
        }
    }

    /// Burn-rate projection for a provider's session window, when meaningful.
    func projection(for id: ProviderID, window: LimitWindow) -> BurnRate.Projection? {
        guard window.kind == .session else { return nil }
        let samples = history.samples(for: id, since: Date.now.addingTimeInterval(-3600))
            .compactMap { sample in sample.fractions[window.label].map { (sample.timestamp, $0) } }
        guard let projection = BurnRate.projection(samples: samples) else { return nil }
        if let resetsAt = window.resetsAt, projection.hitsCapAt >= resetsAt { return nil }
        return projection
    }

    /// 24h sparkline series for a provider's primary window.
    func sparkline(for id: ProviderID) -> [(Date, Double)] {
        let samples = history.samples(for: id, since: Date.now.addingTimeInterval(-24 * 3600))
        guard let label = store.states[id]?.snapshot?.windows.first(where: { $0.kind == .session })?.label
            ?? store.states[id]?.snapshot?.windows.first?.label else { return [] }
        return samples.compactMap { sample in sample.fractions[label].map { (sample.timestamp, $0) } }
    }

    // MARK: Menu bar metric

    /// Combined today totals across enabled providers, for the menu bar text.
    var menuBarTodayTokens: Int {
        store.snapshots(for: enabledProviders.intersection(installed))
            .compactMap(\.tokens?.todayTokens).reduce(0, +)
    }

    var menuBarTodayCost: Double? {
        let costs = store.snapshots(for: enabledProviders.intersection(installed))
            .compactMap(\.tokens?.todayCostUSD)
        return costs.isEmpty ? nil : costs.reduce(0, +)
    }

    struct MenuBarReading {
        var fraction: Double
        var label: String
        var providerName: String
    }

    var menuBarReading: MenuBarReading? {
        let snapshots: [UsageSnapshot]
        if let pinned = menuBarMetric.providerID {
            snapshots = store.snapshots(for: [pinned])
        } else {
            snapshots = store.snapshots(for: enabledProviders.intersection(installed))
        }
        return reading(for: snapshots)
    }

    /// The popover header's small status line: reflects whichever provider tab is
    /// focused, or the same tightest-across-all reading as the menu bar when on "Overview".
    var popoverHeaderReading: MenuBarReading? {
        guard let focus = popoverFocus else { return menuBarReading }
        return reading(for: store.snapshots(for: [focus]))
    }

    private func reading(for snapshots: [UsageSnapshot]) -> MenuBarReading? {
        guard let tightest = UsageMath.tightest(in: snapshots) else { return nil }
        let name = providers.first { type(of: $0).id == tightest.snapshot.providerID }?
            .displayName ?? tightest.snapshot.providerID.rawValue
        return MenuBarReading(fraction: tightest.window.usedFraction,
                              label: tightest.window.label,
                              providerName: name)
    }
}
