import SwiftUI
import AppKit
import BurnBarCore

/// The literal burn bar: flame glyph + tiny draining gauge, drawn as a template
/// image so the system tints it correctly in light/dark menu bars.
struct MenuBarLabel: View {
    var reading: AppState.MenuBarReading?

    var body: some View {
        HStack(spacing: 3) {
            Image(nsImage: Self.barImage(fraction: reading?.fraction))
            if let reading {
                Text(Format.pct(reading.fraction))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
            }
        }
    }

    static func barImage(fraction: Double?) -> NSImage {
        let size = NSSize(width: 32, height: 16)
        let image = NSImage(size: size, flipped: false) { rect in
            // Flame glyph from SF Symbols, left side.
            if let flame = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "BurnBar")?
                .withSymbolConfiguration(.init(pointSize: 11, weight: .semibold)) {
                let flameRect = NSRect(x: 0, y: 2.5, width: 12, height: 12)
                flame.draw(in: flameRect)
            }
            // Gauge, right side: outline + fill proportional to usage.
            let gauge = NSRect(x: 15, y: 5, width: 16, height: 6.5)
            let outline = NSBezierPath(roundedRect: gauge, xRadius: 3, yRadius: 3)
            outline.lineWidth = 1
            NSColor.black.setStroke()
            outline.stroke()
            if let fraction, fraction > 0 {
                let inset = gauge.insetBy(dx: 1.5, dy: 1.5)
                let width = max(1, inset.width * fraction)
                let fill = NSBezierPath(
                    roundedRect: NSRect(x: inset.minX, y: inset.minY, width: width, height: inset.height),
                    xRadius: 1.5, yRadius: 1.5)
                NSColor.black.setFill()
                fill.fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
