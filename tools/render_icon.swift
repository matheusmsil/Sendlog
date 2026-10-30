import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Renders the Sendlog app icon: a climbing hold shaped like an "S", bolted to a gym wall.
// Usage (from the repo root): swift tools/render_icon.swift Sendlog/Assets.xcassets/AppIcon.appiconset

let size = 1024
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Deterministic random numbers so the grip texture is identical on every render.
struct SeededRandom {
    var state: UInt64
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(state >> 33) / CGFloat(1 << 31)
    }
}

struct Palette {
    let wallTop: UInt32, wallBottom: UInt32, tNut: UInt32, tNutRim: UInt32
    let holdLight: UInt32, holdMid: UInt32, holdDark: UInt32
    let shadowAlpha: CGFloat
}

enum Variant {
    case light, dark, tinted

    var palette: Palette {
        switch self {
        case .light: Palette(wallTop: 0xF4EFEA, wallBottom: 0xDCD4CC, tNut: 0xA59B92, tNutRim: 0xC9C0B7,
                             holdLight: 0xFFA552, holdMid: 0xF26A2C, holdDark: 0xC9431A, shadowAlpha: 0.35)
        case .dark: Palette(wallTop: 0x2C2825, wallBottom: 0x171513, tNut: 0x0C0B0A, tNutRim: 0x3A3532,
                            holdLight: 0xFF9C4A, holdMid: 0xF0642A, holdDark: 0xB83A16, shadowAlpha: 0.6)
        case .tinted: Palette(wallTop: 0x262626, wallBottom: 0x0A0A0A, tNut: 0x000000, tNutRim: 0x333333,
                              holdLight: 0xFFFFFF, holdMid: 0xD8D8D8, holdDark: 0x9A9A9A, shadowAlpha: 0.6)
        }
    }
}

// MARK: - Geometry (top-left origin, 1024 canvas)

let center = CGPoint(x: 512, y: 512)
/// Each bowl of the S is an ellipse; the two bowls meet at the center.
let bowlWidth: CGFloat = 185, bowlHeight: CGFloat = 150
let thickness: CGFloat = 170

func point(_ degrees: CGFloat, bowl: CGPoint, grow: CGFloat = 0) -> CGPoint {
    let a = degrees * .pi / 180
    return CGPoint(x: bowl.x + (bowlWidth + grow) * cos(a), y: bowl.y - (bowlHeight + grow) * sin(a))
}

let upperBowl = CGPoint(x: center.x, y: center.y - bowlHeight)
let lowerBowl = CGPoint(x: center.x, y: center.y + bowlHeight)

/// The S's centerline: the upper bowl counterclockwise from its right end to the center,
/// then the lower bowl clockwise from the center to its left end.
func sSpine() -> CGPath {
    let path = CGMutablePath()
    path.move(to: point(25, bowl: upperBowl))
    for degrees in stride(from: CGFloat(25), through: 270, by: 2) { path.addLine(to: point(degrees, bowl: upperBowl)) }
    for degrees in stride(from: CGFloat(90), through: -155, by: -2) { path.addLine(to: point(degrees, bowl: lowerBowl)) }
    return path
}

/// The hold's outline, slightly fatter along the bottom like a jug.
func holdShape() -> CGPath {
    let body = sSpine().copy(strokingWithWidth: thickness, lineCap: .round, lineJoin: .round, miterLimit: 10)
    let jug = CGMutablePath()
    jug.move(to: point(-20, bowl: lowerBowl, grow: 6))
    for degrees in stride(from: CGFloat(-20), through: -155, by: -2) { jug.addLine(to: point(degrees, bowl: lowerBowl, grow: 6)) }
    return body.union(jug.copy(strokingWithWidth: thickness + 26, lineCap: .round, lineJoin: .round, miterLimit: 10))
}

/// The bolt sits where the two bowls meet.
let boltCenter = center

// MARK: - Rendering

func render(_ variant: Variant, to name: String) {
    let p = variant.palette
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: 1, y: -1)
    let canvas = CGRect(x: 0, y: 0, width: size, height: size)

    // Wall.
    let wall = CGGradient(colorsSpace: space, colors: [color(p.wallTop), color(p.wallBottom)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(wall, start: .zero, end: CGPoint(x: 0, y: 1024), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    // T-nut holes in a staggered grid.
    for row in 0..<6 {
        for col in 0..<6 {
            let x = CGFloat(col) * 205 + (row.isMultiple(of: 2) ? 0 : 102) + 10
            let y = CGFloat(row) * 205 + 10
            ctx.setFillColor(color(p.tNutRim))
            ctx.fillEllipse(in: CGRect(x: x - 15, y: y - 15, width: 30, height: 30))
            ctx.setFillColor(color(p.tNut))
            ctx.fillEllipse(in: CGRect(x: x - 9, y: y - 9, width: 18, height: 18))
        }
    }

    let shape = holdShape()

    // Cast shadow on the wall.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 18, height: 34), blur: 46, color: color(0x000000, p.shadowAlpha))
    ctx.addPath(shape)
    ctx.setFillColor(color(p.holdMid))
    ctx.fillPath()
    ctx.restoreGState()

    // Body: lit from the top left.
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let body = CGGradient(colorsSpace: space, colors: [color(p.holdLight), color(p.holdMid), color(p.holdDark)] as CFArray, locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(body, start: CGPoint(x: 260, y: 220), end: CGPoint(x: 780, y: 820), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    // Rounded edges: an inner shadow along the lower right and a highlight along the upper left.
    let outside = CGMutablePath()
    outside.addRect(canvas.insetBy(dx: -200, dy: -200))
    outside.addPath(shape)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: -14, height: -20), blur: 30, color: color(0x000000, 0.35))
    ctx.addPath(outside)
    ctx.fillPath(using: .evenOdd)
    ctx.restoreGState()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 10, height: 14), blur: 18, color: color(0xFFFFFF, variant == .tinted ? 0.5 : 0.45))
    ctx.addPath(outside)
    ctx.fillPath(using: .evenOdd)
    ctx.restoreGState()

    // Grip texture.
    var random = SeededRandom(state: 7)
    for _ in 0..<1100 {
        let x = random.next() * 1024, y = random.next() * 1024, r = 1.2 + random.next() * 2.2
        let light = random.next() > 0.5
        ctx.setFillColor(light ? color(0xFFFFFF, 0.13) : color(0x000000, 0.10))
        ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }
    ctx.restoreGState()

    // Bolt: a countersunk hole with a hex-socket bolt.
    let well = CGRect(x: boltCenter.x - 46, y: boltCenter.y - 46, width: 92, height: 92)
    let wellGradient = CGGradient(colorsSpace: space, colors: [color(0x000000, 0.45), color(0x000000, 0.1)] as CFArray, locations: [0, 1])!
    ctx.saveGState()
    ctx.addEllipse(in: well)
    ctx.clip()
    ctx.drawLinearGradient(wellGradient, start: CGPoint(x: well.minX, y: well.minY), end: CGPoint(x: well.maxX, y: well.maxY), options: [])
    ctx.restoreGState()

    let head = well.insetBy(dx: 14, dy: 14)
    let metal = CGGradient(colorsSpace: space, colors: [color(0xF2F2F2), color(0x9C9C9C), color(0x5E5E5E)] as CFArray, locations: [0, 0.55, 1])!
    ctx.saveGState()
    ctx.addEllipse(in: head)
    ctx.clip()
    ctx.drawLinearGradient(metal, start: CGPoint(x: head.minX, y: head.minY), end: CGPoint(x: head.maxX, y: head.maxY), options: [])
    ctx.restoreGState()

    let hex = CGMutablePath()
    for i in 0..<6 {
        let a = CGFloat(i) * .pi / 3
        let v = CGPoint(x: boltCenter.x + 17 * cos(a), y: boltCenter.y + 17 * sin(a))
        i == 0 ? hex.move(to: v) : hex.addLine(to: v)
    }
    hex.closeSubpath()
    ctx.addPath(hex)
    ctx.setFillColor(color(0x2A2A2A))
    ctx.fillPath()

    let image = ctx.makeImage()!
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

render(.light, to: "AppIcon.png")
render(.dark, to: "AppIcon-Dark.png")
render(.tinted, to: "AppIcon-Tinted.png")
print("Rendered icons to \(outDir)")
