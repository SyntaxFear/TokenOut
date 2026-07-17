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

    /// SwiftUI exposes scrollbar visibility but not native scroller style or size.
    /// This keeps the ScrollView fully SwiftUI-owned while narrowly configuring its
    /// enclosing NSScrollView as a transparent, auto-hiding mini overlay scroller.
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
            scrollView.verticalScroller?.controlSize = .mini
            scrollView.verticalScroller?.knobStyle = .default
        }
    }
}
