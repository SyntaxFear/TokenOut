import SwiftUI
import ServiceManagement
import BurnBarCore

private enum SettingsTab: Hashable {
    case general, providers, display, refresh, alerts, updates, about
}

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @Environment(UpdateController.self) private var updates
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            generalSettings
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            providerSettings
                .tabItem { Label("Providers", systemImage: "square.stack.3d.up") }
                .tag(SettingsTab.providers)
            displaySettings
                .tabItem { Label("Display", systemImage: "menubar.rectangle") }
                .tag(SettingsTab.display)
            refreshSettings
                .tabItem { Label("Refresh", systemImage: "arrow.clockwise") }
                .tag(SettingsTab.refresh)
            alertSettings
                .tabItem { Label("Alerts", systemImage: "bell") }
                .tag(SettingsTab.alerts)
            updateSettings
                .tabItem { Label("Updates", systemImage: "arrow.down.circle") }
                .tag(SettingsTab.updates)
            aboutSettings
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(width: 570, height: 485)
    }

    private var generalSettings: some View {
        settingsForm {
            Section("Startup") {
                Toggle("Launch BurnBar at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enable in
                        do {
                            if enable { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Text("BurnBar stays in the menu bar and has no Dock icon.")
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
                            Text(provider.displayName)
                            Spacer()
                            providerStatus(id)
                        }
                    }
                    .disabled(!app.installed.contains(id))
                }
                Text("BurnBar reads each tool's own local data and uses only its existing sign-in.")
                    .settingsNote()
            }

            Section("Default popover") {
                Picker("Open on", selection: $app.popoverFocus) {
                    Text("All providers").tag(ProviderID?.none)
                    ForEach(app.providers, id: \.displayName) { provider in
                        let id = type(of: provider).id
                        Text(provider.displayName).tag(ProviderID?.some(id))
                    }
                }
            }
        }
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
                Picker("Style", selection: $app.menuBarStyle) {
                    ForEach(MenuBarStyle.allCases, id: \.self) { style in
                        Text(style.title).tag(style)
                    }
                }
                Picker("Limits show", selection: $app.showRemaining) {
                    Text("What's left — drains to 0%").tag(true)
                    Text("What's used — fills to 100%").tag(false)
                }
            }

            Section("Popover content") {
                Toggle("Combined all-tools overview", isOn: $app.showCombinedOverview)
                Toggle("Daily usage charts", isOn: $app.showDailyCharts)
                Toggle("Model and project breakdowns", isOn: $app.showBreakdowns)
                Toggle("Provider detail tiles", isOn: $app.showProviderDetails)
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
                Text("BurnBar speeds up automatically above 50% usage and backs off after failures.")
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
                Text("Updates are signed twice: with Developer ID and BurnBar's Sparkle EdDSA key.")
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
                Text("BurnBar").font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Your AI token burn, live in the menu bar.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Text("Version \(version) (\(build))")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Link("Website", destination: URL(string: "https://burnbar.scrubmac.app")!)
                Link("Privacy", destination: URL(string: "https://burnbar.scrubmac.app/privacy")!)
                Button("Check for Updates…") { updates.checkForUpdates() }
                    .buttonStyle(.link)
                    .disabled(!updates.canCheckForUpdates)
            }
            Text("All usage data stays on this Mac. No analytics, telemetry, or BurnBar account.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Spacer()
            Text("© 2026 Levan Parastashvili")
                .font(.system(size: 9.5)).foregroundStyle(.tertiary)
        }
        .padding(28)
    }

    private func settingsForm<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            Form { content() }
                .formStyle(.grouped)
                .padding(.horizontal, 8)
        }
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

    private func thresholdRow(_ title: String, value: Binding<Double>,
                              range: ClosedRange<Double>, color: Color) -> some View {
        HStack {
            Text(title).frame(width: 58, alignment: .leading)
            Slider(value: value, in: range, step: 0.05)
            Text(Format.pct(value.wrappedValue))
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
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
