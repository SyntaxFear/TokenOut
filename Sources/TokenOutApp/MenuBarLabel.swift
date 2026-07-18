import SwiftUI
import AppKit
import TokenOutCore

/// Draws the menu bar glyph (TokenOut mark and/or usage gauge) as a template
/// image so the system tints it correctly in light/dark menu bars. The text
/// part of the label is set directly on the status button — an NSHostingView
/// inside NSStatusBarButton does not reliably repaint on SwiftUI updates.
enum MenuBarGlyph {
    static func image(icon: Bool, gauge: Bool, fraction: Double?) -> NSImage? {
        guard icon || gauge else { return nil }
        let markWidth: CGFloat = icon ? 12 : 0
        let gaugeWidth: CGFloat = gauge ? 16 : 0
        let gap: CGFloat = icon && gauge ? 4 : 0
        let size = NSSize(width: markWidth + gap + gaugeWidth, height: 16)
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setStroke()
            if icon {
                // Token ring with a gap and an escaping arrow — the app mark at 12 px.
                let markCenter = NSPoint(x: 5.8, y: 8)
                let ring = NSBezierPath()
                ring.appendArc(withCenter: markCenter, radius: 4.6,
                               startAngle: 85, endAngle: 5, clockwise: false)
                ring.lineWidth = 2.1
                ring.lineCapStyle = .round
                ring.stroke()
                let dot = NSBezierPath(ovalIn: NSRect(x: markCenter.x - 1.3, y: markCenter.y - 1.3,
                                                      width: 2.6, height: 2.6))
                NSColor.black.setFill()
                dot.fill()
                let arrow = NSBezierPath()
                arrow.move(to: NSPoint(x: markCenter.x + 2.4, y: markCenter.y + 2.4))
                arrow.line(to: NSPoint(x: markCenter.x + 5.6, y: markCenter.y + 5.6))
                arrow.move(to: NSPoint(x: markCenter.x + 2.9, y: markCenter.y + 5.6))
                arrow.line(to: NSPoint(x: markCenter.x + 5.6, y: markCenter.y + 5.6))
                arrow.line(to: NSPoint(x: markCenter.x + 5.6, y: markCenter.y + 2.9))
                arrow.lineWidth = 2.1
                arrow.lineCapStyle = .round
                arrow.lineJoinStyle = .round
                arrow.stroke()
            }
            if gauge {
                let gaugeRect = NSRect(x: markWidth + gap, y: 5, width: 16, height: 6.5)
                let outline = NSBezierPath(roundedRect: gaugeRect, xRadius: 3, yRadius: 3)
                outline.lineWidth = 1
                NSColor.black.setStroke()
                outline.stroke()
                if let fraction, fraction > 0 {
                    let inset = gaugeRect.insetBy(dx: 1.5, dy: 1.5)
                    let width = max(1, inset.width * fraction)
                    let fill = NSBezierPath(
                        roundedRect: NSRect(x: inset.minX, y: inset.minY,
                                            width: width, height: inset.height),
                        xRadius: 1.5, yRadius: 1.5)
                    NSColor.black.setFill()
                    fill.fill()
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
