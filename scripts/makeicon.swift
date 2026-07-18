#!/usr/bin/env swift
// Generates the production TokenOut icon from the Azure-created brand master.
// Run from repo root: swift scripts/makeicon.swift

import AppKit

let fileManager = FileManager.default
let symbolURL = URL(fileURLWithPath: "Brand/exports/tokenout-symbol.png")
guard let symbol = NSImage(contentsOf: symbolURL) else {
    fatalError("Missing brand symbol at \(symbolURL.path). Generate Brand assets first.")
}

func drawIcon(canvas: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { _ in
        let s = canvas / 1024
        NSGraphicsContext.current?.imageInterpolation = .high

        // Standard macOS optical icon grid: a deep, neutral squircle keeps the
        // TokenOut mark legible in both light and dark system appearances.
        let backgroundRect = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
        let background = NSBezierPath(
            roundedRect: backgroundRect,
            xRadius: 188 * s,
            yRadius: 188 * s
        )

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
        shadow.shadowBlurRadius = 42 * s
        shadow.shadowOffset = NSSize(width: 0, height: -18 * s)
        shadow.set()
        NSGradient(colors: [
            NSColor(calibratedRed: 0.115, green: 0.118, blue: 0.132, alpha: 1),
            NSColor(calibratedRed: 0.035, green: 0.037, blue: 0.045, alpha: 1),
        ])?.draw(in: background, angle: -90)
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.09).setStroke()
        background.lineWidth = 2 * s
        background.stroke()

        // Preserve the generated mark's proportions and use a slight upward lift
        // to optically balance the ring and escaping arrow.
        let symbolWidth = 700 * s
        let symbolHeight = symbolWidth * symbol.size.height / symbol.size.width
        let symbolRect = NSRect(
            x: (canvas - symbolWidth) / 2,
            y: (canvas - symbolHeight) / 2 + 8 * s,
            width: symbolWidth,
            height: symbolHeight
        )

        NSGraphicsContext.saveGraphicsState()
        let markShadow = NSShadow()
        markShadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
        markShadow.shadowBlurRadius = 22 * s
        markShadow.shadowOffset = NSSize(width: 0, height: -8 * s)
        markShadow.set()
        symbol.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        return true
    }
}

func pngData(_ image: NSImage, pixels: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let exportsURL = URL(fileURLWithPath: "Brand/exports")
try fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true)

let iconsetURL = URL(fileURLWithPath: "Support/AppIcon.iconset")
try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let master = drawIcon(canvas: 1024)
if let masterData = pngData(master, pixels: 1024) {
    try masterData.write(to: exportsURL.appending(path: "tokenout-app-icon.png"))
}

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let suffix = scale == 2 ? "@2x" : ""
        guard let data = pngData(master, pixels: pixels) else { continue }
        try data.write(to: iconsetURL.appending(path: "icon_\(size)x\(size)\(suffix).png"))
    }
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetURL.path, "-o", "Support/AppIcon.icns"]
try task.run()
task.waitUntilExit()
try? fileManager.removeItem(at: iconsetURL)

print(task.terminationStatus == 0
      ? "Support/AppIcon.icns and Brand/exports/tokenout-app-icon.png written"
      : "iconutil failed")
