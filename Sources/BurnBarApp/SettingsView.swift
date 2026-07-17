import SwiftUI
import ServiceManagement
import BurnBarCore

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        @Bindable var app = app
        Form {
            Section("Providers") {
                ForEach(app.providers, id: \.displayName) { provider in
                    let id = type(of: provider).id
                    Toggle(isOn: Binding(
                        get: { app.enabledProviders.contains(id) },
                        set: { on in
                            if on { app.enabledProviders.insert(id) }
                            else { app.enabledProviders.remove(id) }
                        }
                    )) {
                        HStack {
                            Text(provider.displayName)
                            if !app.installed.contains(id) {
                                Text("not detected")
                                    .font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .disabled(!app.installed.contains(id))
                }
            }

            Section("Menu bar") {
                Picker("Show", selection: $app.menuBarMetric) {
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
                    Text("What's left (drains to 0%)").tag(true)
                    Text("What's used (fills to 100%)").tag(false)
                }
                Text("Applies to every limit — 5-hour, weekly, monthly — in cards and the menu bar.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Refresh") {
                Picker("Cadence", selection: $app.cadence) {
                    ForEach(RefreshCadence.allCases, id: \.self) { cadence in
                        Text(cadence.title).tag(cadence)
                    }
                }
                Text("BurnBar refreshes faster automatically when any window is above 50%.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Alerts") {
                Toggle("Notify at 80% and 95% of any limit", isOn: $app.notificationsEnabled)
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enable in
                        do {
                            if enable { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize()
    }
}
