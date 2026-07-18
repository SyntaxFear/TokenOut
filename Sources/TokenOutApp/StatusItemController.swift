import AppKit
import SwiftUI
import Observation
import TokenOutCore

/// Opens Settings in a window we own. The SwiftUI Settings scene can't be
/// summoned from a menu-bar-only app: the private showSettingsWindow: selector
/// needs a responder that agent apps (no main menu, no windows) don't have.
@MainActor
enum SettingsOpener {
    private static var window: NSWindow?
    // Set once at launch: NSApp.delegate is SwiftUI's adaptor wrapper, not our
    // AppDelegate, so the environment must be handed to us explicitly.
    private static weak var appRef: AppState?
    private static weak var updatesRef: UpdateController?

    static func configure(app: AppState, updates: UpdateController) {
        appRef = app
        updatesRef = updates
    }

    static func open() {
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        guard let app = appRef, let updates = updatesRef else { return }
        let hosting = NSHostingController(
            rootView: SettingsView()
                .environment(app)
                .environment(updates)
                .tokenOutAppearance(app))
        let win = NSWindow(contentViewController: hosting)
        win.title = tokenOutLocalized("Settings", "Settings")
        win.styleMask = [.titled, .closable, .miniaturizable]
        win.appearance = app.theme.nsAppearance
        win.isReleasedWhenClosed = false
        win.center()
        win.makeKeyAndOrderFront(nil)
        window = win
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: win, queue: .main
        ) { _ in
            Task { @MainActor in SettingsOpener.window = nil }
        }
    }
}

/// The menu bar presence: a custom NSStatusItem + NSPanel pair replacing
/// MenuBarExtra(.window), which can't do three things TokenOut needs:
/// shrink the popover back down when its content shrinks, stay open while the
/// user adjusts Settings side by side, and follow the in-app theme override.
@MainActor
final class StatusItemController: NSObject {
    private static let panelWidth: CGFloat = 340

    private let app: AppState
    private let statusItem: NSStatusItem
    private let panel: PopoverPanel
    private var hosting: NSHostingView<PanelRoot>?
    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?
    /// Reconciliation while visible: SwiftUI's geometry callback occasionally
    /// skips a content-size change (observed on tab switches), leaving stale
    /// dead space. This timer re-reads the ideal height every second and
    /// no-ops when it already matches.
    private var syncTimer: Timer?
    /// Screen Y of the panel's top edge, pinned just under the menu bar; height
    /// changes grow/shrink downward from here.
    private var anchorTop: CGFloat = 0
    private var maxPanelHeight: CGFloat = .infinity

    init(app: AppState) {
        self.app = app
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        panel = PopoverPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: true)
        super.init()

        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.moveToActiveSpace, .transient, .fullScreenAuxiliary]

        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 13
        effect.layer?.cornerCurve = .continuous
        effect.layer?.masksToBounds = true

        let hosting = NSHostingView(rootView: PanelRoot(
            app: app,
            onIdealHeight: { [weak self] height in
                self?.requestContentHeight(height)
            },
            onLayoutShapeChange: { [weak self] in
                // Let SwiftUI commit the new layout first, then measure.
                DispatchQueue.main.async { self?.syncContentHeight() }
            }))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: effect.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        panel.contentView = effect
        self.hosting = hosting

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePanel)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
        }

        trackTheme()
        trackLabel()
    }

    @objc private func togglePanel() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showContextMenu()
            return
        }
        if panel.isVisible { hide() } else { show() }
    }

    /// Right-click / control-click: a standard status-item context menu. The
    /// menu is attached only for the duration of the click so it never
    /// hijacks the plain left-click toggle.
    private func showContextMenu() {
        hide()
        let menu = NSMenu()
        func add(_ title: String, _ action: Selector, key: String = "") {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = self
            menu.addItem(item)
        }
        add(tokenOutLocalized("Show usage", "Show usage"), #selector(menuShowUsage))
        add(tokenOutLocalized("Refresh", "Refresh"), #selector(menuRefresh))
        menu.addItem(.separator())
        add(tokenOutLocalized("Share usage", "Share usage") + "…", #selector(menuShare))
        add(tokenOutLocalized("Settings", "Settings") + "…", #selector(menuSettings), key: ",")
        menu.addItem(.separator())
        add(tokenOutLocalized("Quit TokenOut", "Quit TokenOut"), #selector(menuQuit), key: "q")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func menuShowUsage() { show() }
    @objc private func menuRefresh() { app.refreshAll() }
    @objc private func menuShare() { ShareWindow.show(app: app) }
    @objc private func menuSettings() { SettingsOpener.open() }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    func show() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame
        anchorTop = buttonFrame.minY - 6
        maxPanelHeight = visible.map { anchorTop - $0.minY - 8 } ?? .infinity

        var x = buttonFrame.midX - Self.panelWidth / 2
        if let visible {
            x = min(max(x, visible.minX + 8), visible.maxX - Self.panelWidth - 8)
        }
        let ideal = panel.contentView?.fittingSize.height ?? 400
        let height = min(max(ideal, 100), maxPanelHeight)
        panel.setFrame(NSRect(x: x, y: anchorTop - height, width: Self.panelWidth, height: height),
                       display: false)
        panel.makeKeyAndOrderFront(nil)
        installMonitors()
        startSyncTimer()
        app.refreshIfStale()
    }

    func hide() {
        syncTimer?.invalidate()
        syncTimer = nil
        removeMonitors()
        panel.orderOut(nil)
    }

    /// Reads the current ideal height straight from the hosting view — no
    /// SwiftUI callback in the loop — and reconciles the panel to it.
    private func syncContentHeight() {
        guard panel.isVisible, let hosting else { return }
        applyContentHeight(hosting.fittingSize.height)
    }

    private func startSyncTimer() {
        syncTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.syncContentHeight() }
        }
        RunLoop.main.add(timer, forMode: .common)
        syncTimer = timer
    }

    /// The geometry callback fires DURING SwiftUI's layout pass; resizing the
    /// panel from inside that pass re-enters layout on the very hierarchy
    /// being measured and intermittently corrupts it (content drawn shifted
    /// far above the panel). Defer to the next runloop turn, coalescing.
    private var pendingIdeal: CGFloat?
    private func requestContentHeight(_ ideal: CGFloat) {
        let hadPending = pendingIdeal != nil
        pendingIdeal = ideal
        guard !hadPending else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, let ideal = self.pendingIdeal else { return }
            self.pendingIdeal = nil
            self.applyContentHeight(ideal)
        }
    }

    private func applyContentHeight(_ ideal: CGFloat) {
        let height = min(max(ideal, 100), maxPanelHeight)
        var frame = panel.frame
        // Autolayout can grow the window on its own when content expands; keep
        // the top edge pinned under the menu bar in that case too.
        let desiredY = anchorTop - height
        guard abs(frame.height - height) > 0.5
                || (panel.isVisible && abs(frame.origin.y - desiredY) > 0.5) else { return }
        if panel.isVisible {
            frame.origin.y = desiredY
            frame.size.height = height
            panel.setFrame(frame, display: true)
        } else {
            panel.setContentSize(NSSize(width: Self.panelWidth, height: height))
        }
    }

    /// Dismissal policy: clicks in OTHER apps close the panel (global monitor
    /// only sees those); clicks inside TokenOut's own windows — the panel itself
    /// or Settings — keep it open, so setting changes are visible live.
    private func installMonitors() {
        guard globalClickMonitor == nil else { return }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {  // Esc
                Task { @MainActor in self?.hide() }
                return nil
            }
            return event
        }
    }

    private func removeMonitors() {
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        if let localKeyMonitor { NSEvent.removeMonitor(localKeyMonitor) }
        globalClickMonitor = nil
        localKeyMonitor = nil
    }

    /// Rebuilds the status button from observed state: glyph as the button image,
    /// everything textual as the attributed title. Re-arms itself on any change
    /// to the state it read (Observation), so the menu bar always tracks live.
    private func trackLabel() {
        withObservationTracking {
            updateButton()
        } onChange: { [weak self] in
            Task { @MainActor in self?.trackLabel() }
        }
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }
        let comps = app.menuBarComponents.resolved
        let reading = app.menuBarReading
        func displayed(_ fraction: Double) -> Double {
            app.showRemaining ? 1 - fraction : fraction
        }
        button.image = MenuBarGlyph.image(icon: comps.icon, gauge: comps.gauge,
                                          fraction: reading?.fraction)
        var parts: [String] = []
        if comps.percent, let reading {
            parts.append(Format.pct(displayed(reading.fraction)))
        }
        if comps.providerSplit {
            let split = app.compactReadings
                .map { "\($0.letter)\(Int((displayed($0.fraction) * 100).rounded()))" }
                .joined(separator: " ")
            if !split.isEmpty { parts.append(split) }
        }
        if comps.todayTokens {
            let tokens = app.menuBarTodayTokens
            if tokens > 0 { parts.append(Format.tokens(tokens)) }
        }
        if comps.todayCost, let cost = app.menuBarTodayCost, cost > 0 {
            parts.append(Format.usd(cost))
        }
        let title = parts.joined(separator: " ")
        button.attributedTitle = NSAttributedString(
            string: title.isEmpty ? "" : (button.image == nil ? title : " " + title),
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)])
        button.imagePosition = button.image == nil ? .noImage
            : (title.isEmpty ? .imageOnly : .imageLeading)
    }

    /// Keeps the panel's AppKit appearance in sync with the in-app theme —
    /// .preferredColorScheme only reaches windows SwiftUI owns. The menu bar
    /// label deliberately stays on the system appearance to match the bar.
    private func trackTheme() {
        withObservationTracking {
            panel.appearance = app.theme.nsAppearance
        } onChange: { [weak self] in
            Task { @MainActor in self?.trackTheme() }
        }
    }
}

/// Borderless panels can't become key by default; the popover needs key status
/// for hover states and controls while staying non-activating.
private final class PopoverPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}


private struct PanelRoot: View {
    var app: AppState
    var onIdealHeight: (CGFloat) -> Void
    var onLayoutShapeChange: () -> Void

    /// Every setting that changes the popover's overall shape. onChange on
    /// this string backstops the geometry callback, which can skip a beat
    /// on branch switches like changing tabs.
    private var layoutKey: String {
        "\(app.popoverFocus?.rawValue ?? "all")|\(app.fontSize.rawValue)|\(app.fontFamily.rawValue)"
            + "|\(app.showDailyCharts)|\(app.showBreakdowns)|\(app.dailyRange)"
    }

    var body: some View {
        PopoverView()
            .environment(app)
            .tokenOutAppearance(app)
            // Measure BEFORE the expanding frame: PopoverView is fixedSize'd
            // vertically, so this reads its ideal height, not the panel's.
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { onIdealHeight($0) }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onChange(of: layoutKey) { onLayoutShapeChange() }
    }
}
