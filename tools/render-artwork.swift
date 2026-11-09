#!/usr/bin/env swift
// Renders the Yoga app's artwork: the golden orb, the layered tvOS app icon
// and the Top Shelf images. Everything is drawn in code so the icon, the
// splash and the in-app orb share one visual language.
//
//   swift tools/render-artwork.swift
//
// Output goes straight into Yoga/Resources/Assets.xcassets.

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Palette (mirrors Yoga/Design/Theme.swift)

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: a
    )
}

let ink = rgb(0x100F0B)
let dusk = rgb(0x2B2619)
let ember = rgb(0x3A2E14)
let gold = rgb(0xE8B93A)
let paleGold = rgb(0xFFE7A0)
let cream = rgb(0xF3F1E7)

// MARK: - Deterministic randomness, so re-renders are identical

struct SeededRandom {
    var state: UInt64
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF)
    }
    mutating func range(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { lo + (hi - lo) * next() }
}

// MARK: - Canvas helpers

func makeContext(_ w: Int, _ h: Int) -> CGContext {
    let ctx = CGContext(
        data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    // Flip so y grows downward, like UIKit/SwiftUI. Easier to reason about.
    ctx.translateBy(x: 0, y: CGFloat(h))
    ctx.scaleBy(x: 1, y: -1)
    return ctx
}

func save(_ ctx: CGContext, _ path: String, opaque: Bool = false) {
    var image = ctx.makeImage()!
    if opaque {
        // Back layers and top shelf images must not carry an alpha channel.
        let flat = CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        flat.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        image = flat.makeImage()!
    }
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

func radial(
    _ ctx: CGContext, center: CGPoint, radius: CGFloat, colors: [CGColor], locations: [CGFloat],
    startCenter: CGPoint? = nil, startRadius: CGFloat = 0
) {
    let g = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray,
        locations: locations)!
    ctx.drawRadialGradient(
        g, startCenter: startCenter ?? center, startRadius: startRadius, endCenter: center,
        endRadius: radius, options: [.drawsBeforeStartLocation])
}

func linear(_ ctx: CGContext, from: CGPoint, to: CGPoint, colors: [CGColor], locations: [CGFloat]) {
    let g = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray,
        locations: locations)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

// MARK: - The orb: a warm, marbled sun

func drawOrb(_ ctx: CGContext, center c: CGPoint, radius r: CGFloat, seed: UInt64 = 7) {
    var rng = SeededRandom(state: seed)
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    ctx.clip()

    // Base body: lit from the upper left.
    radial(
        ctx, center: c, radius: r * 1.05,
        colors: [rgb(0xFFDD55), rgb(0xF0B424), rgb(0xCB8C10), rgb(0x7A4C05)],
        locations: [0, 0.42, 0.78, 1],
        startCenter: CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.4), startRadius: 0)

    // Marbling: soft blobs of molten light and shadow.
    let tones: [UInt32] = [0xFFE58A, 0xF6C945, 0xD39A1C, 0xB37812, 0xFFF0B8]
    for _ in 0..<140 {
        let a = rng.range(0, .pi * 2)
        let d = sqrt(rng.next()) * r
        let p = CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d)
        let br = rng.range(r * 0.05, r * 0.28)
        let tone = tones[Int(rng.next() * CGFloat(tones.count)) % tones.count]
        ctx.saveGState()
        ctx.translateBy(x: p.x, y: p.y)
        ctx.rotate(by: rng.range(-0.6, 0.6))
        ctx.scaleBy(x: rng.range(1.2, 2.6), y: 1)
        radial(
            ctx, center: .zero, radius: br,
            colors: [rgb(tone, rng.range(0.18, 0.42)), rgb(tone, 0)], locations: [0, 1])
        ctx.restoreGState()
    }

    // Flowing streaks, like heat moving across the surface.
    ctx.setLineCap(.round)
    for i in 0..<14 {
        let y = c.y - r + (CGFloat(i) + rng.next()) * (2 * r / 14)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: c.x - r, y: y))
        let amp = rng.range(r * 0.04, r * 0.16)
        let phase = rng.range(0, .pi * 2)
        for s in stride(from: 0, through: 1.0, by: 0.02) {
            let x = c.x - r + CGFloat(s) * 2 * r
            path.addLine(to: CGPoint(x: x, y: y + sin(CGFloat(s) * .pi * rng.range(2.6, 3.0) + phase) * amp))
        }
        ctx.addPath(path)
        ctx.setStrokeColor(rgb(i % 3 == 0 ? 0x9A660C : 0xFFE9A6, rng.range(0.03, 0.08)))
        ctx.setLineWidth(rng.range(r * 0.03, r * 0.09))
        ctx.strokePath()
    }

    // Terminator shading (lower right) and a crisp specular glow (upper left).
    radial(
        ctx, center: CGPoint(x: c.x - r * 0.25, y: c.y - r * 0.3), radius: r * 1.45,
        colors: [rgb(0x000000, 0), rgb(0x000000, 0), rgb(0x3D2400, 0.55)],
        locations: [0, 0.55, 1])
    radial(
        ctx, center: CGPoint(x: c.x - r * 0.38, y: c.y - r * 0.42), radius: r * 0.55,
        colors: [rgb(0xFFFBEA, 0.55), rgb(0xFFF3C4, 0)], locations: [0, 1])

    // Limb darkening: the edge falls off like a real sphere.
    radial(
        ctx, center: c, radius: r,
        colors: [rgb(0x000000, 0), rgb(0x000000, 0), rgb(0x2E1A00, 0.5)],
        locations: [0, 0.72, 1])
    ctx.restoreGState()
}

func drawHalo(_ ctx: CGContext, center c: CGPoint, radius r: CGFloat, strength: CGFloat = 1) {
    radial(
        ctx, center: c, radius: r * 2.4,
        colors: [rgb(0xF2B53A, 0.42 * strength), rgb(0xD98A1F, 0.16 * strength), rgb(0xD98A1F, 0)],
        locations: [0.38, 0.6, 1])
}

// MARK: - The wave: a single golden line, the app's signature stroke

func drawWave(
    _ ctx: CGContext, in rect: CGRect, baseline: CGFloat, amplitude: CGFloat, cycles: CGFloat,
    phase: CGFloat, width: CGFloat, alpha: CGFloat
) {
    let path = CGMutablePath()
    let steps = 240
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps)
        let x = rect.minX + t * rect.width
        // Ease the amplitude in and out so the line feels drawn, not plotted.
        let envelope = 0.55 + 0.45 * sin(t * .pi)
        let y = baseline + sin(t * .pi * 2 * cycles + phase) * amplitude * envelope
        i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    ctx.saveGState()
    ctx.setLineCap(.round)
    // Soft glow under the line
    ctx.addPath(path)
    ctx.setStrokeColor(rgb(0xF2C14E, alpha * 0.25))
    ctx.setLineWidth(width * 5)
    ctx.strokePath()
    ctx.addPath(path)
    ctx.setStrokeColor(rgb(0xF6D27A, alpha))
    ctx.setLineWidth(width)
    ctx.strokePath()
    ctx.restoreGState()
}

func drawBackdrop(_ ctx: CGContext, _ w: CGFloat, _ h: CGFloat, glowAt glow: CGPoint, glowRadius: CGFloat) {
    linear(
        ctx, from: CGPoint(x: 0, y: 0), to: CGPoint(x: w * 0.3, y: h),
        colors: [dusk, rgb(0x17150F), ink], locations: [0, 0.55, 1])
    radial(
        ctx, center: glow, radius: glowRadius,
        colors: [rgb(0x6B4A12, 0.85), ember, rgb(0x1A170F, 0)], locations: [0, 0.35, 1])
    // A fine grain keeps the large gradients from banding on big TVs.
    var rng = SeededRandom(state: 99)
    let dots = Int(w * h / 90)
    for _ in 0..<dots {
        let p = CGPoint(x: rng.next() * w, y: rng.next() * h)
        ctx.setFillColor(rgb(rng.next() > 0.5 ? 0xFFFFFF : 0x000000, 0.025))
        ctx.fill(CGRect(x: p.x, y: p.y, width: 1, height: 1))
    }
}

func drawWordmark(_ ctx: CGContext, text: String, at origin: CGPoint, size: CGFloat, weight: NSFont.Weight, tracking: CGFloat, color: CGColor) {
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let attributed = NSAttributedString(
        string: text,
        attributes: [
            .font: font, .kern: tracking,
            .foregroundColor: NSColor(cgColor: color)!,
        ])
    let line = CTLineCreateWithAttributedString(attributed)
    ctx.saveGState()
    // Undo the flip locally: CoreText draws in a y-up space.
    ctx.translateBy(x: origin.x, y: origin.y)
    ctx.scaleBy(x: 1, y: -1)
    ctx.textPosition = .zero
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

// MARK: - Output

let root = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath + "/Yoga/Resources/Assets.xcassets"
let brand = root + "/App Icon & Top Shelf Image.brandassets"

// tvOS app icon: three parallax layers. Geometry is expressed in a 400x240 unit space.
func renderIconLayer(_ layer: String, width: Int, height: Int, to path: String) {
    let s = CGFloat(width) / 400
    let ctx = makeContext(width, height)
    let w = CGFloat(width), h = CGFloat(height)
    let orbCenter = CGPoint(x: 200 * s, y: 112 * s)
    let orbRadius = 60 * s
    switch layer {
    case "Back":
        drawBackdrop(ctx, w, h, glowAt: orbCenter, glowRadius: 230 * s)
        // A distant, dim echo of the wave anchors the composition.
        drawWave(
            ctx, in: CGRect(x: -20 * s, y: 0, width: w + 40 * s, height: h), baseline: 188 * s,
            amplitude: 9 * s, cycles: 1.2, phase: 2.2, width: 1.1 * s, alpha: 0.22)
        save(ctx, path, opaque: true)
    case "Middle":
        drawHalo(ctx, center: orbCenter, radius: orbRadius)
        drawOrb(ctx, center: orbCenter, radius: orbRadius)
        save(ctx, path)
    default: // Front
        drawWave(
            ctx, in: CGRect(x: -20 * s, y: 0, width: w + 40 * s, height: h), baseline: 128 * s,
            amplitude: 34 * s, cycles: 0.85, phase: 3.6, width: 2.4 * s, alpha: 0.95)
        save(ctx, path)
    }
}

func writeJSON(_ object: Any, to path: String) {
    let data = try! JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! data.write(to: url)
}

let info: [String: Any] = ["author": "xcode", "version": 1]

func renderStack(name: String, scales: [(String, Int, Int)]) {
    let stack = "\(brand)/\(name).imagestack"
    let layers = ["Front", "Middle", "Back"]
    writeJSON(["info": info, "layers": layers.map { ["filename": "\($0).imagestacklayer"] }], to: "\(stack)/Contents.json")
    for layer in layers {
        let dir = "\(stack)/\(layer).imagestacklayer"
        writeJSON(["info": info], to: "\(dir)/Contents.json")
        var images: [[String: Any]] = []
        for (scale, w, h) in scales {
            let file = "\(layer.lowercased())@\(scale).png"
            renderIconLayer(layer, width: w, height: h, to: "\(dir)/Content.imageset/\(file)")
            images.append(["idiom": "tv", "scale": scale, "filename": file])
        }
        writeJSON(["info": info, "images": images], to: "\(dir)/Content.imageset/Contents.json")
    }
}

renderStack(name: "App Icon", scales: [("1x", 400, 240), ("2x", 800, 480)])
renderStack(name: "App Icon - App Store", scales: [("1x", 1280, 768)])

// Top Shelf: the wordmark on the left, the sun rising on the right.
func renderTopShelf(width: Int, height: Int, to path: String) {
    let s = CGFloat(height) / 720
    let w = CGFloat(width), h = CGFloat(height)
    let ctx = makeContext(width, height)
    let orbCenter = CGPoint(x: w - 520 * s, y: 380 * s)
    let orbRadius = 205 * s
    drawBackdrop(ctx, w, h, glowAt: orbCenter, glowRadius: 760 * s)
    drawHalo(ctx, center: orbCenter, radius: orbRadius, strength: 0.9)
    drawOrb(ctx, center: orbCenter, radius: orbRadius)
    drawWave(
        ctx, in: CGRect(x: -40 * s, y: 0, width: w + 80 * s, height: h), baseline: 470 * s,
        amplitude: 110 * s, cycles: 0.75, phase: .pi / 2, width: 3.2 * s, alpha: 0.9)
    drawWordmark(ctx, text: "YOGA", at: CGPoint(x: 150 * s, y: 330 * s), size: 150 * s, weight: .ultraLight, tracking: 46 * s, color: cream)
    drawWordmark(ctx, text: "VECKANS KLASSER", at: CGPoint(x: 158 * s, y: 400 * s), size: 30 * s, weight: .medium, tracking: 9 * s, color: rgb(0xE8B93A, 0.9))
    save(ctx, path, opaque: true)
}

for (name, base) in [("Top Shelf Image", 1920), ("Top Shelf Image Wide", 2320)] {
    let dir = "\(brand)/\(name).imageset"
    var images: [[String: Any]] = []
    for scale in [1, 2] {
        let file = "topshelf@\(scale)x.png"
        renderTopShelf(width: base * scale, height: 720 * scale, to: "\(dir)/\(file)")
        images.append(["idiom": "tv", "scale": "\(scale)x", "filename": file])
    }
    writeJSON(["info": info, "images": images], to: "\(dir)/Contents.json")
}

writeJSON(
    [
        "info": info,
        "assets": [
            ["filename": "App Icon - App Store.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "1280x768"],
            ["filename": "App Icon.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "400x240"],
            ["filename": "Top Shelf Image Wide.imageset", "idiom": "tv", "role": "top-shelf-image-wide", "size": "2320x720"],
            ["filename": "Top Shelf Image.imageset", "idiom": "tv", "role": "top-shelf-image", "size": "1920x720"],
        ],
    ], to: "\(brand)/Contents.json")

// The standalone orb used by the app (splash, header, detail view).
do {
    let dir = "\(root)/Orb.imageset"
    var images: [[String: Any]] = []
    for (scale, px) in [("1x", 640), ("2x", 1280)] {
        let ctx = makeContext(px, px)
        let c = CGPoint(x: CGFloat(px) / 2, y: CGFloat(px) / 2)
        drawOrb(ctx, center: c, radius: CGFloat(px) / 2 - 1)
        let file = "orb@\(scale).png"
        save(ctx, "\(dir)/\(file)")
        images.append(["idiom": "universal", "scale": scale, "filename": file])
    }
    writeJSON(["info": info, "images": images], to: "\(dir)/Contents.json")
}

// Composite preview of the full icon, for eyeballing (not part of the asset catalog).
do {
    let preview = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : nil
    if let preview {
        let ctx = makeContext(800, 480)
        for layer in ["Back", "Middle", "Front"] {
            let tmp = NSTemporaryDirectory() + "yoga-\(layer).png"
            renderIconLayer(layer, width: 800, height: 480, to: tmp)
            let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: tmp) as CFURL, nil)!
            let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
            ctx.saveGState()
            ctx.translateBy(x: 0, y: 480)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: 800, height: 480))
            ctx.restoreGState()
        }
        save(ctx, preview, opaque: true)
    }
}

print("Artwork rendered into \(root)")
