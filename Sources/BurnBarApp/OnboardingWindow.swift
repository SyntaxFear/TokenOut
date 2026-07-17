import SwiftUI
import AppKit
import BurnBarCore

/// First-launch explainer, shown as a standalone window from the menu bar app.
@MainActor
enum OnboardingWindow {
    private static var window: NSWindow?

    static func showIfNeeded(app: AppState) {
        guard !app.hasOnboarded, window == nil else { return }
        let hosting = NSHostingController(rootView: OnboardingView().environment(app))
        let win = NSWindow(contentViewController: hosting)
        win.title = "Welcome to BurnBar"
        win.styleMask = [.titled, .closable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.isReleasedWhenClosed = false
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = win
    }

    static func close() {
        window?.close()
        window = nil
    }
}

struct OnboardingView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "flame.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange.gradient)
                .padding(.top, 26)
            Text("BurnBar").font(.system(size: 24, weight: .bold))
            Text("Your token burn, live in the menu bar.")
                .font(.system(size: 13)).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                explainer(icon: "gauge.with.needle",
                          title: "Live limits",
                          text: "5-hour and weekly windows for your AI coding tools, with refill countdowns.")
                explainer(icon: "internaldrive",
                          title: "Everything stays on this Mac",
                          text: "BurnBar reads each tool's local data and talks only to that tool's own API. Nothing is sent anywhere else.")
                explainer(icon: "key",
                          title: "One Keychain prompt",
                          text: "macOS will ask once so BurnBar can read Claude Code's sign-in. Click “Always Allow”.")
            }
            .padding(.horizontal, 30)

            detectedRow

            Button {
                app.hasOnboarded = true
                OnboardingWindow.close()
                app.refreshAll()
            } label: {
                Text("Start tracking").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.horizontal, 30)
            .padding(.bottom, 24)
        }
        .frame(width: 400)
    }

    private var detectedRow: some View {
        HStack(spacing: 14) {
            ForEach(app.providers, id: \.displayName) { provider in
                let found = app.installed.contains(type(of: provider).id)
                Label(provider.displayName,
                      systemImage: found ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(found ? Color.primary : Color.secondary)
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 14)
        .background(.quaternary.opacity(0.4), in: Capsule())
    }

    private func explainer(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.orange)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
