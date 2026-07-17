#!/usr/bin/env swift
// Generates Support/AppIcon.icns: dark squircle, gradient flame, 60%-filled burn bar.
// Run from repo root: swift scripts/makeicon.swift

import AppKit

func drawIcon(canvas: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { _ in
        let s = canvas / 1024.0

        // Background squircle on the standard macOS icon grid (824pt of 1024).
        let bgRect = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
        let bg = NSBezierPath(roundedRect: bgRect, xRadius: 185 * s, yRadius: 185 * s)
        NSGradient(colors: [
            NSColor(calibratedRed: 0.13, green: 0.13, blue: 0.15, alpha: 1),
            NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.09, alpha: 1),
        ])?.draw(in: bg, angle: -90)

        // Flame: two mirrored cubic lobes meeting at a tip, inner core lighter.
        func flamePath(cx: CGFloat, baseY: CGFloat, width: CGFloat, height: CGFloat) -> NSBezierPath {
            let p = NSBezierPath()
            let tip = NSPoint(x: cx, y: baseY + height)
            let bottom = NSPoint(x: cx, y: baseY)
            p.move(to: tip)
            p.curve(to: NSPoint(x: cx - width / 2, y: baseY + height * 0.32),
                    controlPoint1: NSPoint(x: cx - width * 0.10, y: baseY + height * 0.78),
                    controlPoint2: NSPoint(x: cx - width * 0.58, y: baseY + height * 0.60))
            p.curve(to: bottom,
                    controlPoint1: NSPoint(x: cx - width / 2, y: baseY + height * 0.10),
                    controlPoint2: NSPoint(x: cx - width * 0.28, y: baseY))
            p.curve(to: NSPoint(x: cx + width / 2, y: baseY + height * 0.32),
                    controlPoint1: NSPoint(x: cx + width * 0.28, y: baseY),
                    controlPoint2: NSPoint(x: cx + width / 2, y: baseY + height * 0.10))
            p.curve(to: tip,
                    controlPoint1: NSPoint(x: cx + width * 0.58, y: baseY + height * 0.60),
                    controlPoint2: NSPoint(x: cx + width * 0.10, y: baseY + height * 0.78))
            p.close()
            return p
        }

        let outer = flamePath(cx: 512 * s, baseY: 330 * s, width: 380 * s, height: 470 * s)
        NSGradient(colors: [
            NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.20, alpha: 1),
            NSColor(calibratedRed: 0.98, green: 0.45, blue: 0.12, alpha: 1),
            NSColor(calibratedRed: 0.90, green: 0.22, blue: 0.10, alpha: 1),
        ])?.draw(in: outer, angle: -90)

        let inner = flamePath(cx: 512 * s, baseY: 345 * s, width: 190 * s, height: 250 * s)
        NSGradient(colors: [
            NSColor(calibratedRed: 1.00, green: 0.93, blue: 0.55, alpha: 1),
            NSColor(calibratedRed: 1.00, green: 0.70, blue: 0.25, alpha: 1),
        ])?.draw(in: inner, angle: -90)

        // The burn bar: track + 60% amber fill.
        let track = NSRect(x: 262 * s, y: 208 * s, width: 500 * s, height: 64 * s)
        let trackPath = NSBezierPath(roundedRect: track, xRadius: 32 * s, yRadius: 32 * s)
        NSColor(white: 1, alpha: 0.16).setFill()
        trackPath.fill()
        let fill = NSRect(x: track.minX, y: track.minY, width: track.width * 0.6, height: track.height)
        let fillPath = NSBezierPath(roundedRect: fill, xRadius: 32 * s, yRadius: 32 * s)
        NSGradient(colors: [
            NSColor(calibratedRed: 1.00, green: 0.76, blue: 0.28, alpha: 1),
            NSColor(calibratedRed: 0.98, green: 0.52, blue: 0.14, alpha: 1),
        ])?.draw(in: fillPath, angle: 0)

        return true
    }
}

func pngData(_ image: NSImage, pixels: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let iconsetURL = URL(fileURLWithPath: "Support/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let master = drawIcon(canvas: 1024)
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
try? FileManager.default.removeItem(at: iconsetURL)
print(task.terminationStatus == 0 ? "AppIcon.icns written" : "iconutil failed")
