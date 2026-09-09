import AppKit

// Original door-and-knocks mark. Coordinates match docs/images/logo.svg.
let directory = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: pixels * 4, bitsPerPixel: 32)!
        NSGraphicsContext.saveGraphicsState()
        let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.current = graphics
        let context = graphics.cgContext
        context.translateBy(x: 0, y: CGFloat(pixels))
        context.scaleBy(x: CGFloat(pixels) / 1024, y: -CGFloat(pixels) / 1024)
        let teal = NSColor(srgbRed: 27 / 255, green: 97 / 255, blue: 91 / 255, alpha: 1)
        func rounded(_ rect: CGRect, _ radius: CGFloat, _ color: NSColor) {
            context.setFillColor(color.cgColor)
            context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
            context.fillPath()
        }
        rounded(CGRect(x: 64, y: 64, width: 896, height: 896), 195, teal)
        rounded(CGRect(x: 300, y: 220, width: 360, height: 600), 36, .white)
        rounded(CGRect(x: 354, y: 274, width: 252, height: 492), 12, teal)
        context.setFillColor(NSColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: 532, y: 505, width: 40, height: 40))
        rounded(CGRect(x: 252, y: 790, width: 458, height: 32), 16, .white)
        context.setStrokeColor(NSColor(srgbRed: 245 / 255, green: 123 / 255, blue: 131 / 255, alpha: 1).cgColor)
        context.setLineWidth(40)
        context.setLineCap(.round)
        context.move(to: CGPoint(x: 702, y: 322)); context.addLine(to: CGPoint(x: 766, y: 278))
        context.move(to: CGPoint(x: 716, y: 426)); context.addLine(to: CGPoint(x: 806, y: 412))
        context.strokePath()
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
    }
}
