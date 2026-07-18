#!/usr/bin/env swift
// Extracts the canonical glossy TokenOut mark from its chroma-keyed brand
// master and writes the transparent production symbol.
// Run from repo root: swift scripts/maketokensymbol.swift

import AppKit

let inputURL = URL(fileURLWithPath: "Brand/masters/tokenout-symbol-master.png")
let outputURL = URL(fileURLWithPath: "Brand/exports/tokenout-symbol.png")

guard let source = NSImage(contentsOf: inputURL),
      let tiff = source.tiffRepresentation,
      let input = NSBitmapImageRep(data: tiff) else {
    fatalError("Missing or unreadable TokenOut symbol master at \(inputURL.path)")
}

let width = input.pixelsWide
let height = input.pixelsHigh
guard let output = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Unable to allocate TokenOut symbol output")
}

let transparentKey: CGFloat = 0.10
let opaqueKey: CGFloat = 0.45

for y in 0..<height {
    for x in 0..<width {
        guard let color = input.colorAt(x: x, y: y) else { continue }
        let red = color.redComponent
        let green = color.greenComponent
        let blue = color.blueComponent
        let keyness = green - max(red, blue)

        let alpha: CGFloat
        if keyness >= opaqueKey {
            alpha = 0
        } else if keyness <= transparentKey {
            alpha = 1
        } else {
            alpha = 1 - (keyness - transparentKey) / (opaqueKey - transparentKey)
        }

        let despilledGreen = min(green, max(red, blue) + 0.02)
        output.setColor(
            NSColor(
                deviceRed: red,
                green: alpha < 1 ? despilledGreen : green,
                blue: blue,
                alpha: alpha * color.alphaComponent
            ),
            atX: x,
            y: y
        )
    }
}

guard let png = output.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode TokenOut symbol")
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL)
print("wrote \(outputURL.path)")
