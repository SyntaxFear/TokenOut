import AppKit
import SwiftUI

enum MarketingPreviewMode: Equatable {
    case none
    case popover
    case displaySettings
    case updateSettings

    init(arguments: [String]) {
        if arguments.contains("--marketing-popover") {
            self = .popover
        } else if arguments.contains("--marketing-settings-display") {
            self = .displaySettings
        } else if arguments.contains("--marketing-settings-updates") {
            self = .updateSettings
        } else {
            self = .none
        }
    }

    var isEnabled: Bool { self != .none }
}

@MainActor
final class MarketingPreviewDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var previewApp: AppState?
    private var previewUpdates: UpdateController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let mode = MarketingPreviewMode(arguments: CommandLine.arguments)
        guard mode.isEnabled else { return }

        let app = AppState(previewSnapshots: MarketingPreviewData.snapshots)
        let updates = UpdateController(startingUpdater: false)
        previewApp = app
        previewUpdates = updates

        let rootView: AnyView
        let size: NSSize
        let title: String

        switch mode {
        case .popover:
            rootView = AnyView(
                PopoverView()
                    .environment(app)
                    .background(.ultraThinMaterial)
            )
            size = NSSize(width: 340, height: 820)
            title = "BurnBar Usage Preview"
        case .displaySettings:
            rootView = AnyView(
                SettingsView(initialTab: .display)
                    .environment(app)
                    .environment(updates)
            )
            size = NSSize(width: 680, height: 500)
            title = "BurnBar Settings"
        case .updateSettings:
            rootView = AnyView(
                SettingsView(initialTab: .updates)
                    .environment(app)
                    .environment(updates)
            )
            size = NSSize(width: 680, height: 500)
            title = "BurnBar Settings"
        case .none:
            return
        }

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: size)

        let styleMask: NSWindow.StyleMask = mode == .popover
            ? [.titled, .closable, .miniaturizable, .fullSizeContentView]
            : [.titled, .closable, .miniaturizable]
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.titlebarAppearsTransparent = mode == .popover
        window.isMovableByWindowBackground = true
        window.contentView = hostingView
        window.setContentSize(size)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct BurnBarApp: App {
    @NSApplicationDelegateAdaptor(MarketingPreviewDelegate.self) private var previewDelegate
    @State private var app: AppState
    @State private var updates: UpdateController

    init() {
        let previewMode = MarketingPreviewMode(arguments: CommandLine.arguments)
        _app = State(initialValue: previewMode.isEnabled
            ? AppState(previewSnapshots: MarketingPreviewData.snapshots)
            : AppState())
        _updates = State(initialValue: UpdateController(startingUpdater: !previewMode.isEnabled))
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environment(app)
                .onAppear { OnboardingWindow.showIfNeeded(app: app) }
        } label: {
            MenuBarLabel(reading: app.menuBarReading,
                         style: app.menuBarStyle,
                         showRemaining: app.showRemaining,
                         compact: app.compactReadings)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(app)
                .environment(updates)
        }
    }
}
