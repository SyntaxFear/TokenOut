#!/usr/bin/env swift
// Composes the website hero (app icon beside the real popover screenshot) and
// the OpenGraph card from current brand assets. Run from repo root:
//   swift scripts/makesiteassets.swift

import AppKit

let icon = NSImage(contentsOf: URL(fileURLWithPath: "Brand/exports/tokenout-app-icon.png"))!
let popover = NSImage(contentsOf: URL(fileURLWithPath: "website/public/assets/app-popover-real.png"))!

func save(_ image: NSImage, to path: String, pixelsWide: Int, pixelsHigh: Int) {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixelsWide,
                                     pixelsHigh: pixelsHigh, bitsPerSample: 8,
                                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0,
                                     bitsPerPixel: 0) else { fatalError("rep") }
    rep.size = NSSize(width: pixelsWide, height: pixelsHigh)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: pixelsWide, height: pixelsHigh))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: path))
    print("wrote \(path) (\(pixelsWide)x\(pixelsHigh))")
}

func warmBackground(in rect: NSRect, glowCenter: NSPoint) {
    NSGradient(colors: [
        NSColor(calibratedRed: 0.10, green: 0.085, blue: 0.075, alpha: 1),
        NSColor(calibratedRed: 0.045, green: 0.04, blue: 0.05, alpha: 1),
    ])!.draw(in: rect, angle: -70)
    let glow = NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.2, alpha: 0.16),
        NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.2, alpha: 0.0),
    ])!
    glow.draw(fromCenter: glowCenter, radius: 0,
              toCenter: glowCenter, radius: rect.width * 0.45, options: [])
}

// MARK: Hero — 3072x2048 (2x of the page's 1536x1024 layout size)

let heroW: CGFloat = 3072, heroH: CGFloat = 2048
let hero = NSImage(size: NSSize(width: heroW, height: heroH), flipped: false) { rect in
    warmBackground(in: rect, glowCenter: NSPoint(x: heroW * 0.62, y: heroH * 0.6))

    // Right: top portion of the real popover, native-crisp, rounded, shadowed.
    let cropHeightPoints: CGFloat = min(620, popover.size.height)
    let sourceRect = NSRect(x: 0, y: popover.size.height - cropHeightPoints,
                            width: popover.size.width, height: cropHeightPoints)
    let shotScale: CGFloat = 2.6
    let shotSize = NSSize(width: popover.size.width * shotScale,
                          height: cropHeightPoints * shotScale)
    let shotRect = NSRect(x: heroW * 0.52, y: (heroH - shotSize.height) / 2,
                          width: shotSize.width, height: shotSize.height)

    NSGraphicsContext.saveGraphicsState()
    let shotShadow = NSShadow()
    shotShadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
    shotShadow.shadowBlurRadius = 60
    shotShadow.shadowOffset = NSSize(width: 0, height: -24)
    shotShadow.set()
    NSColor.black.setFill()
    let clipPath = NSBezierPath(roundedRect: shotRect, xRadius: 36, yRadius: 36)
    clipPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    clipPath.addClip()
    popover.draw(in: shotRect, from: sourceRect, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    // Left: the app icon, large, with its own soft shadow.
    let iconSize: CGFloat = 1080
    let iconRect = NSRect(x: heroW * 0.09, y: (heroH - iconSize) / 2,
                          width: iconSize, height: iconSize)
    NSGraphicsContext.saveGraphicsState()
    let iconShadow = NSShadow()
    iconShadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
    iconShadow.shadowBlurRadius = 70
    iconShadow.shadowOffset = NSSize(width: 0, height: -30)
    iconShadow.set()
    icon.draw(in: iconRect)
    NSGraphicsContext.restoreGraphicsState()
    return true
}
save(hero, to: "website/public/assets/hero-product.png",
     pixelsWide: Int(heroW), pixelsHigh: Int(heroH))
save(hero, to: "Brand/marketing/hero-product.png",
     pixelsWide: Int(heroW), pixelsHigh: Int(heroH))

// MARK: OpenGraph — rendered 2x then downsampled to exactly 1200x630

let ogW: CGFloat = 2400, ogH: CGFloat = 1260
let og = NSImage(size: NSSize(width: ogW, height: ogH), flipped: false) { rect in
    warmBackground(in: rect, glowCenter: NSPoint(x: ogW * 0.24, y: ogH * 0.55))

    let iconSize: CGFloat = 660
    let iconRect = NSRect(x: 170, y: (ogH - iconSize) / 2, width: iconSize, height: iconSize)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
    shadow.shadowBlurRadius = 50
    shadow.shadowOffset = NSSize(width: 0, height: -20)
    shadow.set()
    icon.draw(in: iconRect)
    NSGraphicsContext.restoreGraphicsState()

    let textX: CGFloat = 950
    let title = NSAttributedString(string: "TokenOut", attributes: [
        .font: NSFont.systemFont(ofSize: 190, weight: .bold),
        .foregroundColor: NSColor.white,
    ])
    title.draw(at: NSPoint(x: textX, y: ogH / 2 + 30))

    let tagline = NSAttributedString(string: "Claude + Codex.\nOne clear view.", attributes: [
        .font: NSFont.systemFont(ofSize: 84, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.72),
    ])
    tagline.draw(at: NSPoint(x: textX + 8, y: ogH / 2 - 240))

    let url = NSAttributedString(string: "tokenout.scrubmac.app", attributes: [
        .font: NSFont.monospacedSystemFont(ofSize: 54, weight: .semibold),
        .foregroundColor: NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.25, alpha: 1),
    ])
    url.draw(at: NSPoint(x: textX + 8, y: 130))
    return true
}
save(og, to: "website/public/opengraph-image.png", pixelsWide: 1200, pixelsHigh: 630)
