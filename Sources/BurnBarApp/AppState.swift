import Foundation
import AppKit
import Observation
import BurnBarCore
import BurnBarProviders

enum ChartMetric: String, CaseIterable {
    case cost, tokens
    var title: String { self == .cost ? "$" : "Tok" }
}

/// One provider's slice of one day, for the combined stacked chart.
struct CombinedPoint: Identifiable {
    var id: String { "\(provider)-\(day.timeIntervalSince1970)" }
    var day: Date
    var provider: String
    var tokens: Int
    var cost: Double
}

enum MenuBarStyle: String, CaseIterable {
    case iconPercent, iconOnly, percentOnly, allProviders

    var title: String {
        switch self {
        case .iconPercent: "Flame + percent"
        case .iconOnly: "Flame only"
        case .percentOnly: "Percent only"
        case .allProviders: "All providers"
        }
    }
}

enum MenuBarMetric: String, CaseIterable {
    case tightest
    case claude, codex, antigravity

    var title: String {
        switch self {
        case .tightest: "Tightest limit"
        case .claude: "Claude Code"
        case .codex: "Codex"
        case .antigravity: "Antigravity"
        }
    }

    var providerID: ProviderID? {
        switch self {
        case .tightest: nil
        case .claude: .claude
        case .codex: .codex
        case .antigravity: .antigravity
        }
    }
}

enum RefreshCadence: String, CaseIterable {
    case fast, normal, relaxed

    var title: String {
        switch self {
        case .fast: "Fast (30 s)"
        case .normal: "Normal (60 s)"
        case .relaxed: "Relaxed (5 min)"
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
    let store = UsageStore()
    let history = HistoryStore()
    let providers: [any UsageProvider] = [ClaudeProvider(), CodexProvider(), AntigravityProvider()]
    private(set) var installed: Set<ProviderID> = []
    private var refreshTasks: [ProviderID: Task<Void, Never>] = [:]
    /// Providers with a fetch in flight (drives spinners).
    private(set) var refreshing: Set<ProviderID> = []
    /// Manual-refresh cooldown so the button can't be hammered.
    private(set) var refreshCoolingDown = false
    private var failureCounts: [ProviderID: Int] = [:]
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
    var menuBarStyle: MenuBarStyle {
        didSet { UserDefaults.standard.set(menuBarStyle.rawValue, forKey: "menuBarStyle") }
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
    var hasOnboarded: Bool {
        didSet { UserDefaults.standard.set(hasOnboarded, forKey: "hasOnboarded") }
    }

    init() {
        let defaults = UserDefaults.standard
        let storedEnabled = defaults.stringArray(forKey: "enabledProviders")?
            .compactMap(ProviderID.init(rawValue:))
        enabledProviders = storedEnabled.map(Set.init) ?? Set(ProviderID.allCases)
        menuBarMetric = defaults.string(forKey: "menuBarMetric")
            .flatMap(MenuBarMetric.init(rawValue:)) ?? .tightest
        menuBarStyle = defaults.string(forKey: "menuBarStyle")
            .flatMap(MenuBarStyle.init(rawValue:)) ?? .iconPercent
        // Default to "what's left" — the planning-first mental model.
        showRemaining = defaults.object(forKey: "showRemaining") as? Bool ?? true
        let storedRange = defaults.integer(forKey: "dailyRange")
        dailyRange = [7, 30, 60, 90].contains(storedRange) ? storedRange : 30
        popoverFocus = defaults.string(forKey: "popoverFocus").flatMap(ProviderID.init(rawValue:))
        chartMetric = defaults.string(forKey: "chartMetric")
            .flatMap(ChartMetric.init(rawValue:)) ?? .cost
        cadence = defaults.string(forKey: "cadence")
            .flatMap(RefreshCadence.init(rawValue:)) ?? .normal
        notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        hasOnboarded = defaults.bool(forKey: "hasOnboarded")

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshAll() }
        }

        Task { await detectAndStart() }
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
        refreshing.insert(id)
        defer { refreshing.remove(id) }
        do {
            let snapshot = try await withTimeout(seconds: 180) { try await provider.fetchUsage() }
            failureCounts[id] = 0
            store.apply(result: .success(snapshot), for: id)
            history.record(snapshot: snapshot)
            if notificationsEnabled {
                notifier.evaluate(snapshot: snapshot, displayName: provider.displayName)
            }
        } catch {
            failureCounts[id, default: 0] += 1
            store.apply(result: .failure(error), for: id)
        }
    }

    private func nextInterval(for id: ProviderID) -> TimeInterval {
        let maxUtilization = store.states[id]?.snapshot?.windows
            .map(\.usedFraction).max() ?? 0
        let base = cadence.policy.interval(
            maxUtilization: maxUtilization,
            consecutiveFailures: failureCounts[id] ?? 0)
        return base * RefreshPolicy.jitter(seed: Date.now.timeIntervalSince1970)
    }

    func refreshAll() {
        guard !refreshCoolingDown else { return }
        refreshCoolingDown = true
        restartLoops()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            self?.refreshCoolingDown = false
        }
    }

    /// Popover-open refresh: only when the newest data is older than 45 s.
    func refreshIfStale() {
        let newest = store.states.values.compactMap(\.snapshot?.fetchedAt).max()
        guard newest.map({ Date.now.timeIntervalSince($0) > 45 }) ?? true else { return }
        refreshAll()
    }

    /// Compact per-provider readings for the all-providers menu bar style.
    var compactReadings: [(letter: String, fraction: Double)] {
        let letters: [ProviderID: String] = [.claude: "C", .codex: "X", .antigravity: "A"]
        return ProviderID.allCases.compactMap { id in
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

    /// Every enabled provider's daily stats flattened for the combined stacked chart.
    var combinedDaily: [CombinedPoint] {
        providers.flatMap { provider -> [CombinedPoint] in
            let id = type(of: provider).id
            guard enabledProviders.contains(id), installed.contains(id),
                  let daily = store.states[id]?.snapshot?.daily else { return [] }
            return daily.map {
                CombinedPoint(day: $0.day, provider: provider.displayName,
                              tokens: $0.tokens, cost: $0.costUSD)
            }
        }
    }

    /// 24h sparkline series for a provider's primary window.
    func sparkline(for id: ProviderID) -> [(Date, Double)] {
        let samples = history.samples(for: id, since: Date.now.addingTimeInterval(-24 * 3600))
        guard let label = store.states[id]?.snapshot?.windows.first(where: { $0.kind == .session })?.label
            ?? store.states[id]?.snapshot?.windows.first?.label else { return [] }
        return samples.compactMap { sample in sample.fractions[label].map { (sample.timestamp, $0) } }
    }

    // MARK: Menu bar metric

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
        guard let tightest = UsageMath.tightest(in: snapshots) else { return nil }
        let name = providers.first { type(of: $0).id == tightest.snapshot.providerID }?
            .displayName ?? tightest.snapshot.providerID.rawValue
        return MenuBarReading(fraction: tightest.window.usedFraction,
                              label: tightest.window.label,
                              providerName: name)
    }
}
