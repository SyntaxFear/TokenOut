import SwiftUI
import AppKit
import TokenOutCore

struct PopoverView: View {
    @Environment(AppState.self) private var app

    private var visibleProviders: [(id: ProviderID, name: String)] {
        app.providers.compactMap { provider in
            let id = type(of: provider).id
            guard app.installed.contains(id), app.enabledProviders.contains(id) else { return nil }
            return (id, provider.displayName)
        }
    }

    private var showsScrollableOverview: Bool {
        app.popoverFocus == nil && visibleProviders.count > 1
    }

    /// Fill the active display while leaving room for the pinned header, provider
    /// picker, footer, window shadow, and menu-bar anchor.
    private var overviewViewportHeight: CGFloat {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        let screenHeight = screen?.visibleFrame.height ?? 900
        return max(320, screenHeight - 150)
    }

    var body: some View {
        @Bindable var app = app
        VStack(alignment: .leading, spacing: 10) {
            header
            if visibleProviders.count > 1 {
                tabBar
            }
            if showsScrollableOverview {
                ThinTracklessScrollView(maxHeight: overviewViewportHeight) {
                    providerContent
                }
                Divider()
            } else {
                providerContent
            }
            footer
        }
        .padding(12)
        .frame(width: 340)
        // MenuBarExtra(.window) grows its host window to fit content but does not
        // reliably shrink it back down afterward. Forcing an exact ideal size on
        // every layout pass (instead of only proposing a max) fixes that.
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { app.refreshIfStale() }
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            tabButton(label: Text("Overview"), logo: nil, isSelected: app.popoverFocus == nil) {
                app.popoverFocus = nil
            }
            ForEach(visibleProviders, id: \.id) { entry in
                tabButton(label: Text(entry.name), logo: entry.id, isSelected: app.popoverFocus == entry.id) {
                    app.popoverFocus = entry.id
                }
            }
        }
        .padding(2)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 7))
    }

    private func tabButton(label: Text, logo: ProviderID?, isSelected: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let logo {
                    ProviderLogo(providerID: logo, size: 11)
                }
                label.tokenOutFont(11, weight: .medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 5))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .clickable()
    }

    @ViewBuilder
    private var providerContent: some View {
        let shown = visibleProviders.filter { app.popoverFocus == nil || $0.id == app.popoverFocus }
        if visibleProviders.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(shown, id: \.id) { entry in
                    ProviderCard(providerID: entry.id,
                                 displayName: entry.name,
                                 state: app.store.states[entry.id] ?? ProviderState(),
                                 focused: app.popoverFocus == entry.id)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            TokenOutMark(size: 16)
            Text("TokenOut").tokenOutFont(14, weight: .bold)
            Spacer()
            if let reading = app.popoverHeaderReading {
                Text("\(reading.providerName) · \(reading.label)")
                    .tokenOutFont(10)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "binoculars").font(.title2).foregroundStyle(.secondary)
            Text("No AI coding tools detected")
                .tokenOutFont(12, weight: .medium)
            Text("TokenOut looks for Claude Code and Codex.")
                .tokenOutFont(11).foregroundStyle(.secondary)
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
                if !app.refreshing.isEmpty {
                    HStack(spacing: 5) {
                        ProgressView().controlSize(.small).scaleEffect(0.6)
                        Text("Refreshing…").tokenOutFont(11)
                    }
                } else if app.refreshCoolingDown {
                    Label("Updating…", systemImage: "clock").tokenOutFont(11)
                } else if app.lastRefreshOutcome == .failed {
                    Label("Some updates failed", systemImage: "exclamationmark.triangle")
                        .tokenOutFont(11).foregroundStyle(.orange)
                } else {
                    Label("Refresh", systemImage: "arrow.clockwise").tokenOutFont(11)
                }
            }
            .buttonStyle(.borderless)
            .disabled(app.refreshCoolingDown || !app.refreshing.isEmpty)
            .clickable()
            .help("Refresh all providers now (15 s cooldown)")
            Spacer()
            Button {
                ShareWindow.show(app: app)
            } label: {
                Image(systemName: "square.and.arrow.up").tokenOutFont(11)
            }
            .buttonStyle(.borderless)
            .clickable()
            .help("Share usage")
            Button {
                SettingsOpener.open()
            } label: {
                Image(systemName: "gearshape").tokenOutFont(11)
            }
            .buttonStyle(.borderless)
            .clickable()
            .help("Settings")
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power").tokenOutFont(11)
            }
            .buttonStyle(.borderless)
            .clickable()
            .help("Quit TokenOut")
        }
        .foregroundStyle(.secondary)
    }
}
