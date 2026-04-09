#!/usr/bin/env swift

import AppKit
import CoreGraphics

// MARK: - Colors

let claudeOrange = NSColor(red: 0xD9/255.0, green: 0x77/255.0, blue: 0x57/255.0, alpha: 1.0)
let coolBlue     = NSColor(red: 0x3B/255.0, green: 0x82/255.0, blue: 0xF6/255.0, alpha: 1.0)

// MARK: - Squircle path (iOS/macOS-style rounded square)

func squirclePath(rect: NSRect) -> NSBezierPath {
    // macOS app icon continuous-curvature approximation
    let radius = rect.width * 0.2237
    return NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

// MARK: - Icon rendering

func generateIcon(size: CGFloat, dark: Bool) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let center = CGPoint(x: size / 2, y: size / 2)

    // ── Background: subtle near-white / near-black squircle with vertical gradient
    let bgPath = squirclePath(rect: rect)
    bgPath.addClip()

    let bgGradient: NSGradient
    if dark {
        bgGradient = NSGradient(
            starting: NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1.0),
            ending:   NSColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
        )!
    } else {
        bgGradient = NSGradient(
            starting: NSColor(red: 0.985, green: 0.985, blue: 0.99, alpha: 1.0),
            ending:   NSColor(red: 0.915, green: 0.915, blue: 0.93, alpha: 1.0)
        )!
    }
    bgGradient.draw(in: bgPath, angle: -90)

    // Very subtle inner top highlight for depth
    ctx.saveGState()
    let highlightRect = NSRect(x: 0, y: size * 0.55, width: size, height: size * 0.45)
    let highlight = NSGradient(
        starting: NSColor(white: dark ? 1.0 : 1.0, alpha: dark ? 0.04 : 0.35),
        ending:   NSColor(white: 1.0, alpha: 0.0)
    )!
    highlight.draw(in: highlightRect, angle: -90)
    ctx.restoreGState()

    // ── Faint track ring
    let radius = size * 0.34
    let lineWidth = size * 0.10

    let trackPath = NSBezierPath()
    trackPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
    trackPath.lineWidth = lineWidth
    trackPath.lineCapStyle = .round
    (dark
        ? NSColor(white: 1.0, alpha: 0.07)
        : NSColor(white: 0.0, alpha: 0.06)
    ).setStroke()
    trackPath.stroke()

    // ── Progress arc (sweep 270°, gauge-style)
    // NSBezierPath uses math coords (y-up): 0°=right, 90°=top, 180°=left, 270°=bottom.
    // We want a gauge that starts at bottom-left (225°) and sweeps counterclockwise (visually clockwise)
    // through the bottom to bottom-right (315°), covering 270° — leaving a 90° gap at the bottom.
    // Wait — for a "gauge" look we want the GAP at the bottom. Start 225° (bottom-left) going CCW in
    // math (= visually CW) through 180, 90, 0, 315 = bottom-right. That's a 270° sweep with gap at bottom.
    let startAngle: CGFloat = 225
    let endAngle: CGFloat = 315

    let arcPath = NSBezierPath()
    arcPath.appendArc(
        withCenter: center,
        radius: radius,
        startAngle: startAngle,
        endAngle: endAngle,
        clockwise: true
    )

    // Stroke the path into a mask and fill with a linear gradient
    // Approach: clip to the stroked region, then draw a full-rect gradient.
    ctx.saveGState()

    // Soft drop shadow under the arc
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.012),
        blur: size * 0.035,
        color: NSColor(red: 0, green: 0, blue: 0, alpha: dark ? 0.55 : 0.22).cgColor
    )

    // Build a stroked copy of the arc as a CGPath for clipping
    let cgArc = arcPath.cgPath
    let strokedArc = cgArc.copy(
        strokingWithWidth: lineWidth,
        lineCap: .round,
        lineJoin: .round,
        miterLimit: 10
    )
    ctx.addPath(strokedArc)
    ctx.clip()

    // Linear gradient orange → blue, diagonal from top-left to bottom-right
    let colorspace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(
        colorsSpace: colorspace,
        colors: [claudeOrange.cgColor, coolBlue.cgColor] as CFArray,
        locations: [0.0, 1.0]
    )!

    let gStart = CGPoint(x: size * 0.15, y: size * 0.85)
    let gEnd   = CGPoint(x: size * 0.85, y: size * 0.15)
    ctx.drawLinearGradient(
        gradient,
        start: gStart,
        end: gEnd,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    ctx.restoreGState()

    // ── Tiny accent dot at the arc's "end" (top-right tip) for a polished touch
    ctx.saveGState()
    let dotRadius = lineWidth * 0.22
    let tipAngle = endAngle * .pi / 180
    let tipPoint = CGPoint(
        x: center.x + radius * cos(tipAngle),
        y: center.y + radius * sin(tipAngle)
    )
    let dotRect = NSRect(
        x: tipPoint.x - dotRadius,
        y: tipPoint.y - dotRadius,
        width: dotRadius * 2,
        height: dotRadius * 2
    )
    NSColor.white.withAlphaComponent(0.85).setFill()
    NSBezierPath(ovalIn: dotRect).fill()
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

// MARK: - NSBezierPath → CGPath bridge (for older SDKs)

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo, .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }
        return path
    }
}

// MARK: - Saving

func savePNG(image: NSImage, size: Int, path: String) {
    let resized = NSImage(size: NSSize(width: size, height: size))
    resized.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height),
        operation: .copy,
        fraction: 1.0
    )
    resized.unlockFocus()

    guard let tiff = resized.tiffRepresentation,
          let bmp = NSBitmapImageRep(data: tiff),
          let png = bmp.representation(using: .png, properties: [:]) else { return }

    try? png.write(to: URL(fileURLWithPath: path))
}

// MARK: - Main

let projectDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let assetDir = "\(projectDir)/Resources/Assets.xcassets/AppIcon.appiconset"
let iconsetDir = "\(projectDir)/Resources/AppIcon.iconset"

// Ensure dirs exist
try? FileManager.default.createDirectory(atPath: assetDir, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let darkMaster = generateIcon(size: 1024, dark: true)
let lightMaster = generateIcon(size: 1024, dark: false)

print("Generating minimalist gradient-arc icon assets...")

let sizes = [16, 32, 128, 256, 512]
for size in sizes {
    // xcassets (with appearance variants)
    savePNG(image: darkMaster, size: size,     path: "\(assetDir)/icon_\(size)x\(size).png")
    savePNG(image: darkMaster, size: size * 2, path: "\(assetDir)/icon_\(size)x\(size)@2x.png")
    savePNG(image: lightMaster, size: size,     path: "\(assetDir)/icon_\(size)x\(size)_light.png")
    savePNG(image: lightMaster, size: size * 2, path: "\(assetDir)/icon_\(size)x\(size)@2x_light.png")
    savePNG(image: darkMaster, size: size,     path: "\(assetDir)/icon_\(size)x\(size)_dark.png")
    savePNG(image: darkMaster, size: size * 2, path: "\(assetDir)/icon_\(size)x\(size)@2x_dark.png")

    // iconset (for iconutil → .icns). Use dark master as the shipped icon.
    savePNG(image: darkMaster, size: size,     path: "\(iconsetDir)/icon_\(size)x\(size).png")
    savePNG(image: darkMaster, size: size * 2, path: "\(iconsetDir)/icon_\(size)x\(size)@2x.png")
}

// Contents.json with appearance variants
let contentsJSON = """
{
  "images" : [
    { "appearances" : [ { "appearance" : "luminosity", "value" : "light" } ], "filename" : "icon_16x16_light.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "light" } ], "filename" : "icon_16x16@2x_light.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "filename" : "icon_16x16_dark.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "filename" : "icon_16x16@2x_dark.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "light" } ], "filename" : "icon_32x32_light.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "light" } ], "filename" : "icon_32x32@2x_light.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "filename" : "icon_32x32_dark.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "filename" : "icon_32x32@2x_dark.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "light" } ], "filename" : "icon_128x128_light.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "light" } ], "filename" : "icon_128x128@2x_light.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "filename" : "icon_128x128_dark.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "filename" : "icon_128x128@2x_dark.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "light" } ], "filename" : "icon_256x256_light.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "light" } ], "filename" : "icon_256x256@2x_light.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "filename" : "icon_256x256_dark.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "filename" : "icon_256x256@2x_dark.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "light" } ], "filename" : "icon_512x512_light.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "light" } ], "filename" : "icon_512x512@2x_light.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "filename" : "icon_512x512_dark.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "filename" : "icon_512x512@2x_dark.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""

try! contentsJSON.write(toFile: "\(assetDir)/Contents.json", atomically: true, encoding: .utf8)
print("Done! Assets written to:")
print("  \(assetDir)")
print("  \(iconsetDir)")
