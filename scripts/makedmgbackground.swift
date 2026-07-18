import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: swift scripts/makedmgbackground.swift output.png\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])

// Finder does not extend a background picture when its window is enlarged.
// Use an oversized canvas and keep the designed 660x400 region at top-left so
// normal resizing never exposes Finder's plain fallback canvas.
let canvasSize = NSSize(width: 1200, height: 800)
let designYOffset: CGFloat = 400
let canvas = NSImage(size: canvasSize)
canvas.lockFocus()

NSGraphicsContext.current?.imageInterpolation = .high

// Finder always renders icon-label text in black on a window with a custom
// background picture, regardless of system Dark Mode. A light surface lets
// those native labels sit directly on the background with no plate behind
// them, instead of fighting the platform with a boxed-in pill.
let canvasColor = NSColor(calibratedWhite: 0.965, alpha: 1)
canvasColor.setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()

func centeredText(_ string: String, y: CGFloat, font: NSFont, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
    ]
    let size = (string as NSString).size(withAttributes: attributes)
    (string as NSString).draw(
        at: NSPoint(x: (660 - size.width) / 2, y: y),
        withAttributes: attributes
    )
}

centeredText(
    "Install TokenOut",
    y: 326 + designYOffset,
    font: .systemFont(ofSize: 25, weight: .semibold),
    color: NSColor(calibratedWhite: 0.1, alpha: 1)
)
centeredText(
    "Drag to Applications to install",
    y: 298 + designYOffset,
    font: .systemFont(ofSize: 12.5, weight: .medium),
    color: NSColor(calibratedWhite: 0.38, alpha: 1)
)

let orange = NSColor(calibratedRed: 1.0, green: 0.43, blue: 0.10, alpha: 1)
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 284, y: 180 + designYOffset))
arrow.line(to: NSPoint(x: 376, y: 180 + designYOffset))
arrow.lineWidth = 2.25
arrow.lineCapStyle = .round
orange.setStroke()
arrow.stroke()

let arrowhead = NSBezierPath()
arrowhead.move(to: NSPoint(x: 387, y: 180 + designYOffset))
arrowhead.line(to: NSPoint(x: 375, y: 187 + designYOffset))
arrowhead.line(to: NSPoint(x: 375, y: 173 + designYOffset))
arrowhead.close()
orange.setFill()
arrowhead.fill()

canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode background PNG\n", stderr)
    exit(1)
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL, options: .atomic)
