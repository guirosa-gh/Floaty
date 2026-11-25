// Draws Floaty's app icon (the blue scribble on a dark tile, same as the
// selected pencil in the toolbar) and writes AppIcon.icns.
// Run by build.sh:  swift make_icon.swift

import Cocoa

let bgTop    = NSColor(srgbRed: 0.106, green: 0.118, blue: 0.145, alpha: 1)  // #1B1E25
let bgBottom = NSColor(srgbRed: 0.075, green: 0.082, blue: 0.102, alpha: 1)  // #13151A
let accent   = NSColor(srgbRed: 0.173, green: 0.443, blue: 0.965, alpha: 1)  // #2C71F6

func drawIcon(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let k = CGFloat(pixels) / 1024           // design on a 1024 grid
    ctx.scaleBy(x: k, y: k)

    // Tile, sized and rounded like standard macOS app icons.
    let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24,
                  color: NSColor.black.withAlphaComponent(0.35).cgColor)
    bgBottom.setFill()
    shape.fill()
    ctx.restoreGState()

    NSGradient(starting: bgTop, ending: bgBottom)!.draw(in: shape, angle: -90)

    let rim = NSBezierPath(roundedRect: tile.insetBy(dx: 2, dy: 2), xRadius: 183, yRadius: 183)
    rim.lineWidth = 4
    NSColor(white: 1, alpha: 0.08).setStroke()
    rim.stroke()

    // The scribble.
    let cfg = NSImage.SymbolConfiguration(pointSize: 420, weight: .medium)
    let symbol = NSImage(systemSymbolName: "scribble.variable", accessibilityDescription: nil)!
        .withSymbolConfiguration(cfg)!
    let tinted = NSImage(size: symbol.size, flipped: false) { r in
        symbol.draw(in: r)
        accent.set()
        r.fill(using: .sourceAtop)
        return true
    }
    let s = symbol.size
    let scale = min(500 / s.width, 500 / s.height)
    let w = s.width * scale, h = s.height * scale
    tinted.draw(in: NSRect(x: 512 - w / 2, y: 512 - h / 2, width: w, height: h))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: "AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    try! drawIcon(pixels: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! drawIcon(pixels: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", "AppIcon.icns"]
try! p.run()
p.waitUntilExit()
try? fm.removeItem(at: iconset)
print(p.terminationStatus == 0 ? "Wrote AppIcon.icns" : "iconutil failed")
