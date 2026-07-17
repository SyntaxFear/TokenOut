import SwiftUI
import AppKit

/// Pointing-hand cursor for anything clickable — clickability should be felt before the click.
struct PointerOnHover: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { inside in
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

/// Soft hover highlight for interactive rows/buttons, macOS-native feeling.
struct HoverHighlight: ViewModifier {
    @State private var hovering = false
    var cornerRadius: CGFloat = 6

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 5).padding(.vertical, 3)
            .background(hovering ? AnyShapeStyle(.quaternary.opacity(0.7))
                                 : AnyShapeStyle(.clear),
                        in: RoundedRectangle(cornerRadius: cornerRadius))
            .onHover { inside in
                withAnimation(.easeOut(duration: 0.12)) { hovering = inside }
            }
    }
}

extension View {
    func pointer() -> some View { modifier(PointerOnHover()) }
    func hoverHighlight(cornerRadius: CGFloat = 6) -> some View {
        modifier(HoverHighlight(cornerRadius: cornerRadius))
    }
    /// Standard treatment for every clickable control in BurnBar.
    func clickable() -> some View { hoverHighlight().pointer() }

    /// A completely trackless overlay scroller. The hit area stays native-sized for
    /// usability, while the only visible element is a restrained 3 px thumb.
    func thinOverlayScroller() -> some View {
        background(OverlayScrollerConfigurator())
    }
}

private struct OverlayScrollerConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> ConfiguratorView {
        ConfiguratorView()
    }

    func updateNSView(_ nsView: ConfiguratorView, context: Context) {
        nsView.scheduleConfiguration()
    }

    final class ConfiguratorView: NSView {
        private var attempts = 0

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            scheduleConfiguration()
        }

        func scheduleConfiguration() {
            DispatchQueue.main.async { [weak self] in self?.configureEnclosingScrollView() }
        }

        private func configureEnclosingScrollView() {
            guard let scrollView = sequence(first: superview, next: { $0?.superview })
                .compactMap({ $0 as? NSScrollView }).first else {
                attempts += 1
                if attempts < 4 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                        self?.configureEnclosingScrollView()
                    }
                }
                return
            }

            scrollView.scrollerStyle = .overlay
            scrollView.autohidesScrollers = true
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = false
            scrollView.drawsBackground = false
            scrollView.backgroundColor = .clear
            if !(scrollView.verticalScroller is BurnBarOverlayScroller) {
                scrollView.verticalScroller = BurnBarOverlayScroller()
            }
            scrollView.verticalScroller?.controlSize = .mini
        }
    }
}

private final class BurnBarOverlayScroller: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool { true }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
        // Intentionally empty: BurnBar never draws a scrollbar rail or background.
    }

    override func drawKnob() {
        let nativeKnob = rect(for: .knob)
        guard !nativeKnob.isEmpty else { return }

        let thumbWidth: CGFloat = 3
        let thumbRect = NSRect(
            x: nativeKnob.midX - thumbWidth / 2,
            y: nativeKnob.minY + 1,
            width: thumbWidth,
            height: max(8, nativeKnob.height - 2)
        )
        NSColor.secondaryLabelColor.withAlphaComponent(0.58).setFill()
        NSBezierPath(roundedRect: thumbRect, xRadius: 1.5, yRadius: 1.5).fill()
    }
}
