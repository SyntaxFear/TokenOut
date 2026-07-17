import SwiftUI
import BurnBarCore

struct PopoverView: View {
    @Environment(AppState.self) private var app

    private var visibleProviders: [(id: ProviderID, name: String)] {
        app.providers.compactMap { provider in
            let id = type(of: provider).id
            guard app.installed.contains(id), app.enabledProviders.contains(id) else { return nil }
            return (id, provider.displayName)
        }
    }

    var body: some View {
        @Bindable var app = app
        VStack(alignment: .leading, spacing: 10) {
            header
            if visibleProviders.count > 1 {
                Picker("", selection: $app.popoverFocus) {
                    Text("All").tag(ProviderID?.none)
                    ForEach(visibleProviders, id: \.id) { entry in
                        Text(entry.name).tag(ProviderID?.some(entry.id))
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
            }
            let shown = visibleProviders.filter { app.popoverFocus == nil || $0.id == app.popoverFocus }
            if visibleProviders.isEmpty {
                emptyState
            } else {
                ForEach(shown, id: \.id) { entry in
                    ProviderCard(providerID: entry.id,
                                 displayName: entry.name,
                                 state: app.store.states[entry.id] ?? ProviderState(),
                                 focused: app.popoverFocus == entry.id)
                }
            }
            footer
        }
        .padding(12)
        .frame(width: 340)
        .onAppear { app.refreshIfStale() }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange.gradient)
            Text("BurnBar").font(.system(size: 14, weight: .bold))
            Spacer()
            if let reading = app.menuBarReading {
                Text("\(reading.providerName) · \(reading.label)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "binoculars").font(.title2).foregroundStyle(.secondary)
            Text("No AI coding tools detected")
                .font(.system(size: 12, weight: .medium))
            Text("BurnBar looks for Claude Code, Codex, and Antigravity.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var footer: some View {
        HStack {
            Button {
                app.refreshAll()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise").font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            Spacer()
            SettingsLink {
                Image(systemName: "gearshape").font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .help("Settings")
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power").font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .help("Quit BurnBar")
        }
        .foregroundStyle(.secondary)
    }
}
