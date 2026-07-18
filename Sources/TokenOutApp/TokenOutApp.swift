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
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let previewMode = MarketingPreviewMode(arguments: CommandLine.arguments)
    lazy var app: AppState = previewMode.isEnabled
        ? AppState(previewSnapshots: MarketingPreviewData.snapshots)
        : AppState()
    lazy var updates = UpdateController(startingUpdater: !previewMode.isEnabled)
    private var statusController: StatusItemController?
    private var previewWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        FontRegistry.registerBundledFontsIfNeeded()
        SettingsOpener.configure(app: app, updates: updates)
        // Headless share-card render for QA/marketing:
        //   TokenOut --render-share-card /path/out.png
        if let flagIndex = CommandLine.arguments.firstIndex(of: "--render-share-card"),
           CommandLine.arguments.indices.contains(flagIndex + 1) {
            let snapshots = MarketingPreviewData.snapshots
            let stats = ShareStats.build(snapshots: snapshots,
                                         selected: Set(snapshots.map(\.providerID)),
                                         range: .week)
            let outputPath = CommandLine.arguments[flagIndex + 1]
            if let data = ShareCardRenderer.pngData(for: stats) {
                try? data.write(to: URL(fileURLWithPath: outputPath))
            }
            NSApp.terminate(nil)
            return
        }
        if previewMode.isEnabled {
            openMarketingPreviewWindow()
        } else {
            statusController = StatusItemController(app: app)
            OnboardingWindow.showIfNeeded(app: app)
        }
    }

    private func openMarketingPreviewWindow() {
        let rootView: AnyView
        let size: NSSize
        let title: String

        switch previewMode {
        case .popover:
            rootView = AnyView(
                PopoverView()
                    .environment(app)
                    .tokenOutAppearance(app)
                    .background(.ultraThinMaterial)
            )
            size = NSSize(width: 340, height: 820)
            title = "TokenOut Usage Preview"
        case .displaySettings:
            rootView = AnyView(
                SettingsView(initialTab: .display)
                    .environment(app)
                    .environment(updates)
                    .tokenOutAppearance(app)
            )
            size = NSSize(width: 680, height: 500)
            title = "TokenOut Settings"
        case .updateSettings:
            rootView = AnyView(
                SettingsView(initialTab: .updates)
                    .environment(app)
                    .environment(updates)
                    .tokenOutAppearance(app)
            )
            size = NSSize(width: 680, height: 500)
            title = "TokenOut Settings"
        case .none:
            return
        }

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: size)

        let styleMask: NSWindow.StyleMask = previewMode == .popover
            ? [.titled, .closable, .miniaturizable, .fullSizeContentView]
            : [.titled, .closable, .miniaturizable]
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.titlebarAppearsTransparent = previewMode == .popover
        window.isMovableByWindowBackground = true
        window.contentView = hostingView
        window.setContentSize(size)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        previewWindow = window

        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct TokenOutApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        // Must run before AppState reads defaults or the stores open files.
        LegacyMigration.runIfNeeded()
    }

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(delegate.app)
                .environment(delegate.updates)
                .tokenOutAppearance(delegate.app)
        }
    }
}
