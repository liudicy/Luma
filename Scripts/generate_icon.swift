// Reproducible vector artwork. Run: swift Scripts/generate_icon.swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("QuickRecorder/Assets.xcassets/AppIcon.appiconset")
func render(size: Int, to url: URL) throws {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let tile = NSBezierPath(roundedRect: NSRect(x: 96, y: 96, width: 832, height: 832), xRadius: 190, yRadius: 190)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    shadow.shadowBlurRadius = 30
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor(calibratedRed: 0.28, green: 0.13, blue: 0.64, alpha: 1).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [NSColor(calibratedRed: 0.29, green: 0.15, blue: 0.67, alpha: 1),
                        NSColor(calibratedRed: 0.58, green: 0.41, blue: 0.94, alpha: 1)])!.draw(in: tile, angle: 75)
    NSColor.white.withAlphaComponent(0.22).setStroke()
    tile.lineWidth = 2
    tile.stroke()
    // The original's recording ring, with restrained depth and a warm active light.
    NSGraphicsContext.saveGraphicsState()
    let ringShadow = NSShadow()
    ringShadow.shadowColor = NSColor(calibratedRed: 0.15, green: 0.04, blue: 0.42, alpha: 0.25)
    ringShadow.shadowBlurRadius = 16
    ringShadow.shadowOffset = NSSize(width: 0, height: -8)
    ringShadow.set()
    let ring = NSBezierPath(ovalIn: NSRect(x: 282, y: 282, width: 460, height: 460))
    ring.lineWidth = 70
    NSColor(calibratedWhite: 0.97, alpha: 1).setStroke()
    ring.stroke()
    NSGraphicsContext.restoreGraphicsState()
    let dot = NSBezierPath(ovalIn: NSRect(x: 424, y: 424, width: 176, height: 176))
    NSGradient(colors: [NSColor(calibratedRed: 1, green: 0.36, blue: 0.40, alpha: 1),
                        NSColor(calibratedRed: 1, green: 0.68, blue: 0.58, alpha: 1)])!.draw(in: dot, angle: 90)
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}
for base in [16, 32, 128, 256, 512] {
    try render(size: base, to: assets.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(size: base * 2, to: assets.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try render(size: 1024, to: root.appendingPathComponent("img/luma-icon.png"))
