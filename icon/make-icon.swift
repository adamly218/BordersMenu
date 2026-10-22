// Draws the 1024x1024 app icon: a dark tile with two windows,
// the front one outlined by a glowing violet border like JankyBorders draws.
// Usage: swift icon/make-icon.swift <output.png>

import AppKit

let size: CGFloat = 1024
let violet = NSColor(srgbRed: 0.54, green: 0.49, blue: 1.0, alpha: 1)

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// Tile: Apple's icon grid leaves a 100 px margin around an 824 px rounded square.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor(white: 0, alpha: 0.45).cgColor)
ctx.addPath(roundedRect(tile, 185))
ctx.setFillColor(NSColor.black.cgColor)
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(roundedRect(tile, 185))
ctx.clip()
let background = CGGradient(
    colorsSpace: space,
    colors: [NSColor(srgbRed: 0.19, green: 0.18, blue: 0.25, alpha: 1).cgColor,
             NSColor(srgbRed: 0.07, green: 0.07, blue: 0.10, alpha: 1).cgColor] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(background, start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])

func window(_ frame: CGRect, body: NSColor, bar: NSColor, lights: [NSColor]) {
    ctx.addPath(roundedRect(frame, 44))
    ctx.setFillColor(body.cgColor)
    ctx.fillPath()
    // Title bar.
    ctx.saveGState()
    ctx.addPath(roundedRect(frame, 44))
    ctx.clip()
    ctx.setFillColor(bar.cgColor)
    ctx.fill(CGRect(x: frame.minX, y: frame.maxY - 78, width: frame.width, height: 78))
    ctx.restoreGState()
    for (i, color) in lights.enumerated() {
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: frame.minX + 40 + CGFloat(i) * 44, y: frame.maxY - 54, width: 28, height: 28))
    }
}

// Back window: unfocused, faint white border.
let back = CGRect(x: 205, y: 395, width: 470, height: 360)
window(back, body: NSColor(srgbRed: 0.16, green: 0.16, blue: 0.20, alpha: 1),
       bar: NSColor(srgbRed: 0.20, green: 0.20, blue: 0.25, alpha: 1),
       lights: Array(repeating: NSColor(white: 0.38, alpha: 1), count: 3))
ctx.addPath(roundedRect(back.insetBy(dx: -10, dy: -10), 54))
ctx.setStrokeColor(NSColor(white: 1, alpha: 0.22).cgColor)
ctx.setLineWidth(8)
ctx.strokePath()

// Front window: focused, violet border with a glow.
let front = CGRect(x: 345, y: 245, width: 480, height: 370)
let ring = roundedRect(front.insetBy(dx: -14, dy: -14), 58)
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 60, color: violet.withAlphaComponent(0.9).cgColor)
ctx.addPath(ring)
ctx.setStrokeColor(violet.cgColor)
ctx.setLineWidth(20)
ctx.strokePath()
ctx.restoreGState()
// Fill inside the ring so the back window's outline doesn't show through the gap.
ctx.addPath(ring)
ctx.setFillColor(NSColor(srgbRed: 0.15, green: 0.15, blue: 0.19, alpha: 1).cgColor)
ctx.fillPath()
window(front, body: NSColor(srgbRed: 0.15, green: 0.15, blue: 0.19, alpha: 1),
       bar: NSColor(srgbRed: 0.21, green: 0.21, blue: 0.27, alpha: 1),
       lights: [NSColor(srgbRed: 1.0, green: 0.37, blue: 0.34, alpha: 1),
                NSColor(srgbRed: 1.0, green: 0.74, blue: 0.18, alpha: 1),
                NSColor(srgbRed: 0.16, green: 0.79, blue: 0.25, alpha: 1)])
ctx.addPath(ring)
ctx.setStrokeColor(violet.cgColor)
ctx.setLineWidth(20)
ctx.strokePath()
ctx.restoreGState()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
