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
    /// Standard treatment for every clickable control in TokenOut.
    func clickable() -> some View { hoverHighlight().pointer() }
}

/// A DisclosureGroup style with a self-drawn chevron sharing the label's hover
/// highlight and tap target — the built-in style draws its twisty separately,
/// so hovering it doesn't trigger the same feedback as hovering the label.
struct RowDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation { configuration.isExpanded.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.right")
                        .tokenOutFont(9, weight: .semibold)
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                    configuration.label
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .clickable()
            .help(configuration.isExpanded ? "Collapse" : "Expand")

            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}

/// A scroll view whose indicator is a floating 3 px thumb. It has no rail and
/// reserves no horizontal space from the content. Sizes itself to its content's
/// natural height, up to `maxHeight`, instead of always claiming the max.
///
/// Measurement uses `.onGeometryChange` on the scrolled content — preference
/// keys silently fail to propagate out of ScrollView content here, which kept
/// contentHeight at 0 and this view stuck at maxHeight.
struct ThinTracklessScrollView<Content: View>: View {
    private let coordinateSpaceName = "TokenOutThinScroll"
    private let content: Content
    private let maxHeight: CGFloat
    @State private var contentHeight: CGFloat = 0
    @State private var scrollMinY: CGFloat = 0

    init(maxHeight: CGFloat, @ViewBuilder content: () -> Content) {
        self.maxHeight = maxHeight
        self.content = content()
    }

    private var isScrollable: Bool { contentHeight > maxHeight }
    private var viewportHeight: CGFloat {
        contentHeight > 0 ? min(contentHeight, maxHeight) : maxHeight
    }

    var body: some View {
        ScrollView {
            content
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) {
                    contentHeight = $0
                }
                .onGeometryChange(for: CGFloat.self,
                                  of: { $0.frame(in: .named(coordinateSpaceName)).minY }) {
                    scrollMinY = $0
                }
        }
        .coordinateSpace(name: coordinateSpaceName)
        // .never, not .hidden: .hidden still lets AppKit FLASH the system
        // scroller when content size changes — exactly what collapsing a
        // disclosure does. The 3 px custom thumb is the only indicator here.
        .scrollIndicators(.never)
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: viewportHeight)
        .overlay(alignment: .topTrailing) {
            if isScrollable {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.secondary.opacity(0.58))
                    .frame(width: 3, height: thumbHeight())
                    .offset(y: thumbOffset())
                    .allowsHitTesting(false)
                    .padding(.trailing, 1)
                    .accessibilityHidden(true)
            }
        }
    }

    private func thumbHeight() -> CGFloat {
        max(24, viewportHeight * viewportHeight / max(contentHeight, 1))
    }

    private func thumbOffset() -> CGFloat {
        let maximumScroll = max(1, contentHeight - viewportHeight)
        let scrollOffset = min(max(-scrollMinY, 0), maximumScroll)
        let travel = max(0, viewportHeight - thumbHeight())
        return scrollOffset / maximumScroll * travel
    }
}
