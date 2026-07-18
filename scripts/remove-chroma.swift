#!/usr/bin/env swift
// Removes a flat #00ff00 chroma-key background from a PNG, writing a PNG with
// alpha. Soft matte at the edges plus green despill.
// Usage: swift scripts/remove-chroma.swift input.png output.png

import AppKit

guard CommandLine.arguments.count == 3 else {
    fatalError("usage: remove-chroma.swift input.png output.png")
}
let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let source = NSImage(contentsOf: inputURL),
      let tiff = source.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff) else {
    fatalError("cannot read \(inputURL.path)")
}

let width = rep.pixelsWide
let height = rep.pixelsHigh
guard let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0, bitsPerPixel: 0) else {
    fatalError("cannot allocate output")
}

// keyness = how much the pixel looks like the green key. Fully keyed above
// `opaqueKey`, fully kept below `transparentKey`, soft-matted between.
let transparentKey: CGFloat = 0.10
let opaqueKey: CGFloat = 0.45

for y in 0..<height {
    for x in 0..<width {
        guard let color = rep.colorAt(x: x, y: y) else { continue }
        let r = color.redComponent, g = color.greenComponent, b = color.blueComponent
        let keyness = g - max(r, b)
        var alpha: CGFloat
        if keyness >= opaqueKey {
            alpha = 0
        } else if keyness <= transparentKey {
            alpha = 1
        } else {
            alpha = 1 - (keyness - transparentKey) / (opaqueKey - transparentKey)
        }
        // Despill: clamp green so semi-transparent edges don't glow green.
        let despilledG = min(g, max(r, b) + 0.02)
        out.setColor(NSColor(deviceRed: r, green: alpha < 1 ? despilledG : g,
                             blue: b, alpha: alpha * color.alphaComponent),
                     atX: x, y: y)
    }
}

guard let png = out.representation(using: .png, properties: [:]) else {
    fatalError("png encode failed")
}
try png.write(to: outputURL)
print("wrote \(outputURL.path)")
