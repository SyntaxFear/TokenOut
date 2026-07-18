import SwiftUI
import ServiceManagement
import TokenOutCore

enum SettingsTab: String, Hashable, CaseIterable, Identifiable {
    case general, providers, appearance, display, refresh, alerts, updates, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: tokenOutLocalized("General", "General")
        case .providers: tokenOutLocalized("Providers", "Providers")
        case .appearance: tokenOutLocalized("Appearance", "Appearance")
        case .display: tokenOutLocalized("Display", "Display")
        case .refresh: tokenOutLocalized("Refresh", "Refresh")
        case .alerts: tokenOutLocalized("Alerts", "Alerts")
        case .updates: tokenOutLocalized("Updates", "Updates")
        case .about: tokenOutLocalized("About", "About")
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape.fill"
        case .providers: "square.stack.3d.up.fill"
        case .appearance: "paintbrush.fill"
        case .display: "menubar.rectangle"
        case .refresh: "arrow.clockwise"
        case .alerts: "bell.fill"
        case .updates: "arrow.down.circle.fill"
        case .about: "arrow.up.right"
        }
    }

    /// System Settings-style colored icon badge per section, like iOS/macOS Settings.
    var tint: Color {
        switch self {
        case .general: .gray
        case .providers: .blue
        case .appearance: .pink
        case .display: .indigo
        case .refresh: .green
        case .alerts: .red
        case .updates: .purple
        case .about: .orange
        }
    }
}

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @Environment(UpdateController.self) private var updates
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    /// Marketing screenshots force a specific tab; the normal app keeps the
    /// last selection in AppState so it survives language-switch rebuilds.
    private let forcedInitialTab: SettingsTab?

    init(initialTab: SettingsTab? = nil) {
        let previewMode = MarketingPreviewMode(arguments: CommandLine.arguments)
        forcedInitialTab = initialTab ?? {
            switch previewMode {
            case .displaySettings: return .display
            case .updateSettings: return .updates
            default: return nil
            }
        }()
    }

    var body: some View {
        @Bindable var app = app
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $app.settingsTab) { tab in
                Label {
                    Text(tab.title)
                } icon: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(tab.tint.gradient)
                        .frame(width: 22, height: 22)
                        .overlay {
                            Image(systemName: tab.icon)
                                .tokenOutFont(11, weight: .medium)
                                .foregroundStyle(.white)
                        }
                }
                .tag(tab)
                .padding(.vertical, 2)
            }
            .navigationSplitViewColumnWidth(180)
            .listStyle(.sidebar)
        } detail: {
            content(for: app.settingsTab)
                .navigationTitle(app.settingsTab.title)
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 680, height: 500)
        .onAppear {
            if let forcedInitialTab { app.settingsTab = forcedInitialTab }
        }
    }

    @ViewBuilder
    private func content(for tab: SettingsTab) -> some View {
        switch tab {
        case .general: generalSettings
        case .providers: providerSettings
        case .appearance: appearanceSettings
        case .display: displaySettings
        case .refresh: refreshSettings
        case .alerts: alertSettings
        case .updates: updateSettings
        case .about: aboutSettings
        }
    }

    private var generalSettings: some View {
        settingsForm {
            Section("Startup") {
                Toggle("Launch TokenOut at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enable in
                        do {
                            if enable { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Text("TokenOut stays in the menu bar and has no Dock icon.")
                    .settingsNote()
            }

            Section("First launch") {
                Button("Show onboarding again") {
                    app.hasOnboarded = false
                    OnboardingWindow.showIfNeeded(app: app)
                }
                Text("Useful when reviewing local-data access and the Claude Keychain prompt.")
                    .settingsNote()
            }
        }
    }

    private var providerSettings: some View {
        @Bindable var app = app
        return settingsForm {
            Section("Tracked tools") {
                ForEach(app.providers, id: \.displayName) { provider in
                    let id = type(of: provider).id
                    Toggle(isOn: providerBinding(id)) {
                        HStack {
                            ProviderLogo(providerID: id, size: 15)
                            Text(provider.displayName)
                            Spacer()
                            providerStatus(id)
                        }
                    }
                    .disabled(!app.installed.contains(id))
                }
                Text("TokenOut reads each tool's own local data and uses only its existing sign-in.")
                    .settingsNote()
            }

            Section("Default popover") {
                Picker("Open on", selection: $app.popoverFocus) {
                    Text("All providers").tag(ProviderID?.none)
                    ForEach(app.providers, id: \.displayName) { provider in
                        let id = type(of: provider).id
                        Label {
                            Text(provider.displayName)
                        } icon: {
                            ProviderLogo(providerID: id, size: 13)
                        }
                        .tag(ProviderID?.some(id))
                    }
                }
            }
        }
    }

    private var appearanceSettings: some View {
        @Bindable var app = app
        return settingsForm {
            Section {
                appearancePreview
            }

            Section("Theme") {
                Picker("Appearance", selection: $app.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Text") {
                Picker("Size", selection: $app.fontSize) {
                    ForEach(AppFontSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                Picker("Font", selection: $app.fontFamily) {
                    ForEach(AppFontFamily.allCases) { family in
                        Text(family.title).tag(family)
                    }
                }
                Text("A few Google Fonts, alongside the system font.")
                    .settingsNote()
            }

            Section("Language") {
                Picker("App language", selection: $app.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.nativeName).tag(language)
                    }
                }
            }
        }
    }

    /// A live sample matching the popover's actual typography, so a theme,
    /// font, or size change is visible right here — no need to reopen the
    /// menu-bar popover (which closes anyway once Settings takes focus).
    private var appearancePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ProviderLogo(providerID: .claude, size: 14)
                Text("Claude Code").tokenOutFont(13, weight: .semibold)
                Spacer()
                MetricValueText(value: "67%", size: 13, weight: .semibold, design: .rounded)
            }
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary.opacity(0.6))
                Capsule().fill(.green.gradient).frame(width: 130)
            }
            .frame(height: 5)
            Text("Today").tokenOutFont(10.5, weight: .semibold).foregroundStyle(.tertiary)
            MetricValueText(value: "5.1M tok", size: 15, weight: .semibold, design: .rounded)
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }

    private var displaySettings: some View {
        @Bindable var app = app
        return settingsForm {
            Section("Menu bar") {
                Picker("Primary metric", selection: $app.menuBarMetric) {
                    ForEach(MenuBarMetric.allCases, id: \.self) { metric in
                        Text(metric.title).tag(metric)
                    }
                }
                Toggle("Icon", isOn: $app.menuBarComponents.icon)
                Toggle("Usage gauge", isOn: $app.menuBarComponents.gauge)
                Toggle("Percentage", isOn: $app.menuBarComponents.percent)
                Toggle("Provider split", isOn: $app.menuBarComponents.providerSplit)
                Toggle("Today's tokens", isOn: $app.menuBarComponents.todayTokens)
                Toggle("Today's cost", isOn: $app.menuBarComponents.todayCost)
                Text("Combine any of these — the menu bar shows exactly what you pick.")
                    .settingsNote()
                Picker("Limits show", selection: $app.showRemaining) {
                    Text("What's left — drains to 0%").tag(true)
                    Text("What's used — fills to 100%").tag(false)
                }
            }

            Section("Popover content") {
                Toggle("Daily usage charts", isOn: $app.showDailyCharts)
                Toggle("Model and project breakdowns", isOn: $app.showBreakdowns)
                Picker("Default chart range", selection: $app.dailyRange) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("60 days").tag(60)
                    Text("90 days").tag(90)
                }
                Picker("Chart metric", selection: $app.chartMetric) {
                    Text("API-equivalent cost").tag(ChartMetric.cost)
                    Text("Tokens").tag(ChartMetric.tokens)
                }
            }
        }
    }

    private var refreshSettings: some View {
        @Bindable var app = app
        return settingsForm {
            Section("Automatic refresh") {
                Picker("Cadence", selection: $app.cadence) {
                    ForEach(RefreshCadence.allCases, id: \.self) { cadence in
                        Text(cadence.title).tag(cadence)
                    }
                }
                Text("TokenOut speeds up automatically above 50% usage and backs off after failures.")
                    .settingsNote()
            }

            Section("Now") {
                Button {
                    app.refreshAll()
                } label: {
                    Label(app.refreshing.isEmpty ? "Refresh all providers" : "Refreshing…",
                          systemImage: "arrow.clockwise")
                }
                .disabled(app.refreshCoolingDown || !app.refreshing.isEmpty)
            }
        }
    }

    private var alertSettings: some View {
        @Bindable var app = app
        return settingsForm {
            Section("Notifications") {
                Toggle("Limit notifications", isOn: $app.notificationsEnabled)
                Toggle("Notify when a limit refills", isOn: $app.refillNotifications)
                    .disabled(!app.notificationsEnabled)
            }

            Section("Thresholds") {
                thresholdRow("Warning", value: $app.warningThreshold,
                             range: 0.5...max(0.5, min(0.95, app.criticalThreshold - 0.05)),
                             color: .orange)
                thresholdRow("Critical", value: $app.criticalThreshold,
                             range: min(1.0, max(0.55, app.warningThreshold + 0.05))...1.0,
                             color: .red)
                Text("Each alert is sent once per rate-limit reset cycle.")
                    .settingsNote()
            }
        }
    }

    private var updateSettings: some View {
        settingsForm {
            Section("Sparkle updates") {
                Toggle("Automatically check for updates", isOn: Binding(
                    get: { updates.automaticallyChecksForUpdates },
                    set: { updates.automaticallyChecksForUpdates = $0 }
                ))
                Toggle("Download and install updates automatically", isOn: Binding(
                    get: { updates.automaticallyDownloadsUpdates },
                    set: { updates.automaticallyDownloadsUpdates = $0 }
                ))
                .disabled(!updates.automaticallyChecksForUpdates)
                Picker("Check frequency", selection: Binding(
                    get: { updates.updateCheckInterval },
                    set: { updates.updateCheckInterval = $0 }
                )) {
                    Text("Every hour").tag(TimeInterval(3600))
                    Text("Every 6 hours").tag(TimeInterval(21_600))
                    Text("Daily").tag(TimeInterval(86_400))
                    Text("Weekly").tag(TimeInterval(604_800))
                }
                .disabled(!updates.automaticallyChecksForUpdates)
            }

            Section("Manual update") {
                Button("Check for Updates…") { updates.checkForUpdates() }
                    .disabled(!updates.canCheckForUpdates)
                Text("Updates are signed twice: with Developer ID and TokenOut's Sparkle EdDSA key.")
                    .settingsNote()
            }
        }
    }

    private var aboutSettings: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 92, height: 92)
            VStack(spacing: 4) {
                Text("TokenOut").tokenOutFont(22, weight: .bold, design: .rounded)
                Text("Your AI usage, live in the menu bar.")
                    .tokenOutFont(12).foregroundStyle(.secondary)
            }
            Text("Version \(version) (\(build))")
                .tokenOutFont(11, monospacedDigit: true)
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Link("Website", destination: URL(string: "https://tokenout.scrubmac.app")!)
                Link("Privacy", destination: URL(string: "https://tokenout.scrubmac.app/privacy")!)
                Button("Check for Updates…") { updates.checkForUpdates() }
                    .buttonStyle(.link)
                    .disabled(!updates.canCheckForUpdates)
            }
            Text("All usage data stays on this Mac. No analytics, telemetry, or TokenOut account.")
                .tokenOutFont(10.5)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Spacer()
            Text("© 2026 Levan Parastashvili")
                .tokenOutFont(9.5).foregroundStyle(.tertiary)
        }
        .padding(28)
    }

    /// Grouped Form directly — it scrolls itself; wrapping it in a ScrollView
    /// double-scrolls and breaks the native System Settings inset look.
    private func settingsForm<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Form { content() }
            .formStyle(.grouped)
    }

    private func providerBinding(_ id: ProviderID) -> Binding<Bool> {
        Binding(
            get: { app.enabledProviders.contains(id) },
            set: { enabled in
                if enabled { app.enabledProviders.insert(id) }
                else { app.enabledProviders.remove(id) }
            }
        )
    }

    @ViewBuilder
    private func providerStatus(_ id: ProviderID) -> some View {
        if !app.installed.contains(id) {
            Text("Not detected").foregroundStyle(.tertiary)
        } else if app.store.states[id]?.status == .ok {
            Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        } else {
            Text("Detected").foregroundStyle(.secondary)
        }
    }

    private func thresholdRow(_ title: LocalizedStringKey, value: Binding<Double>,
                              range: ClosedRange<Double>, color: Color) -> some View {
        HStack {
            Text(title).frame(width: 58, alignment: .leading)
            Slider(value: value, in: range, step: 0.05)
            Text(Format.pct(value.wrappedValue))
                .tokenOutFont(11, weight: .semibold, monospacedDigit: true)
                .foregroundStyle(color)
                .frame(width: 38, alignment: .trailing)
        }
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "local"
    }
}

private extension View {
    func settingsNote() -> some View {
        font(.caption).foregroundStyle(.secondary)
    }
}
