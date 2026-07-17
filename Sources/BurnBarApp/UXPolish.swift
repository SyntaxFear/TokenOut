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
}
