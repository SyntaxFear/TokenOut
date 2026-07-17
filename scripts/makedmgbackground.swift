import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("usage: swift scripts/makedmgbackground.swift input.png output.png\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = NSImage(contentsOf: inputURL) else {
    fputs("Unable to read \(inputURL.path)\n", stderr)
    exit(1)
}

let canvasSize = NSSize(width: 660, height: 400)
let canvas = NSImage(size: canvasSize)
canvas.lockFocus()

NSGraphicsContext.current?.imageInterpolation = .high
NSColor(calibratedWhite: 0.04, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()

let scale = max(canvasSize.width / source.size.width, canvasSize.height / source.size.height)
let drawnSize = NSSize(width: source.size.width * scale, height: source.size.height * scale)
let drawnRect = NSRect(
    x: (canvasSize.width - drawnSize.width) / 2,
    y: (canvasSize.height - drawnSize.height) / 2,
    width: drawnSize.width,
    height: drawnSize.height
)
source.draw(in: drawnRect, from: .zero, operation: .sourceOver, fraction: 1)

NSColor(calibratedWhite: 0, alpha: 0.14).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()

func centeredText(_ string: String, y: CGFloat, font: NSFont, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
    ]
    let size = (string as NSString).size(withAttributes: attributes)
    (string as NSString).draw(
        at: NSPoint(x: (canvasSize.width - size.width) / 2, y: y),
        withAttributes: attributes
    )
}

centeredText(
    "Install BurnBar",
    y: 334,
    font: .systemFont(ofSize: 25, weight: .bold),
    color: NSColor(calibratedRed: 0.96, green: 0.95, blue: 0.93, alpha: 1)
)
centeredText(
    "Drag BurnBar to Applications",
    y: 306,
    font: .systemFont(ofSize: 13, weight: .regular),
    color: NSColor(calibratedRed: 0.67, green: 0.64, blue: 0.61, alpha: 1)
)

let orange = NSColor(calibratedRed: 0.96, green: 0.48, blue: 0.12, alpha: 1)
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 260, y: 175))
arrow.line(to: NSPoint(x: 400, y: 175))
arrow.lineWidth = 4
arrow.lineCapStyle = .round
orange.setStroke()
arrow.stroke()

let arrowhead = NSBezierPath()
arrowhead.move(to: NSPoint(x: 400, y: 175))
arrowhead.line(to: NSPoint(x: 382, y: 186))
arrowhead.line(to: NSPoint(x: 382, y: 164))
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
