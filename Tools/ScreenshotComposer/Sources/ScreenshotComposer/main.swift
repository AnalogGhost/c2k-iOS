import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Framed + captioned App Store screenshot compositor. Reads the raw per-locale
// screenshots under fastlane/screenshots/raw, draws each one onto a fixed
// 1320x2868 (6.9" iPhone) canvas — cream background, peach glow, bold caption
// band, orange rounded frame, camera dot, faint runner watermark — and writes
// the result to fastlane/screenshots/framed. Visual language matches the
// Android app's Play Store marketing set; the geometry is adapted because
// Apple requires an exact screenshot size.

// MARK: - Design constants

let CANVAS_W: CGFloat = 1320
let CANVAS_H: CGFloat = 2868

let SIDE_MARGIN: CGFloat = 96
let CAPTION_BAND: CGFloat = 380      // reserved height at the top for the caption
let CAPTION_GAP: CGFloat = 44        // gap between the caption band and the frame
let CAPTION_SIDE_INSET: CGFloat = 150 // horizontal inset for caption text (wraps earlier than the frame is wide)
let BOTTOM_MARGIN: CGFloat = 110

let FRAME_BORDER: CGFloat = 10
let FRAME_CORNER_RADIUS: CGFloat = 56
let SHOT_CORNER_RADIUS: CGFloat = 46

let CAPTION_FONT_SIZE: CGFloat = 76
let CAPTION_LINE_SPACING: CGFloat = 1.15

let WATERMARK_ALPHA: CGFloat = 0.10

func rgb(_ r: Int, _ g: Int, _ b: Int) -> CGColor {
    CGColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
}
let BACKGROUND = rgb(0xF7, 0xF3, 0xEE)
let GLOW_CENTER = rgb(0xFF, 0xE4, 0xD5)
let ACCENT = rgb(0xE5, 0x5A, 0x2A)
let CAPTION_TEXT = rgb(0x1E, 0x23, 0x28)
let CAMERA_DOT = rgb(0xC8, 0xBE, 0xB6)

// MARK: - Entry point

let root = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath
let fm = FileManager.default

let fastlaneDir = (root as NSString).appendingPathComponent("fastlane")
let rawRoot = (fastlaneDir as NSString).appendingPathComponent("screenshots/raw")
let outRoot = (fastlaneDir as NSString).appendingPathComponent("screenshots/framed")
let captionsFile = (fastlaneDir as NSString).appendingPathComponent("screenshot_captions.yml")

let captions = parseCaptions(captionsFile)

guard let localeDirs = try? fm.contentsOfDirectory(atPath: rawRoot).sorted() else {
    fail("No raw screenshots found under \(rawRoot) — run `fastlane snapshot` first.")
}

var composed = 0
for locale in localeDirs {
    let inDir = (rawRoot as NSString).appendingPathComponent(locale)
    var isDir: ObjCBool = false
    guard fm.fileExists(atPath: inDir, isDirectory: &isDir), isDir.boolValue else { continue }

    let outDir = (outRoot as NSString).appendingPathComponent(locale)
    try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

    let pngs = ((try? fm.contentsOfDirectory(atPath: inDir)) ?? [])
        .filter { $0.lowercased().hasSuffix(".png") }
        .sorted()

    for png in pngs {
        // snapshot names files "<device>-<screen>.png"; the caption key is the screen part.
        let stem = (png as NSString).deletingPathExtension
        let screen = stem.range(of: "-", options: .backwards)
            .map { String(stem[$0.upperBound...]) } ?? stem
        guard let caption = captions[screen]?[locale] else {
            fail("No caption for '\(screen)' in locale '\(locale)' (fastlane/screenshot_captions.yml)")
        }
        let rawPath = (inDir as NSString).appendingPathComponent(png)
        guard let raw = loadCGImage(rawPath) else { fail("Could not read \(rawPath)") }

        let framed = composite(raw: raw, caption: caption)
        let outPath = (outDir as NSString).appendingPathComponent(png)
        writePNG(framed, to: outPath)
        composed += 1
    }
}

print("Composed \(composed) screenshot(s) into \(outRoot)")

// MARK: - Compositing

func composite(raw: CGImage, caption: String) -> CGImage {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil,
        width: Int(CANVAS_W), height: Int(CANVAS_H),
        bitsPerComponent: 8, bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fail("Could not create bitmap context") }

    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    // Everything below is in CoreGraphics' native y-up space. `fromTop` converts a
    // distance measured from the top of the canvas into a y-up origin.
    func fromTop(_ topY: CGFloat, height h: CGFloat) -> CGFloat { CANVAS_H - topY - h }

    // Fit the raw screenshot into the area below the caption band.
    let availW = CANVAS_W - 2 * SIDE_MARGIN
    let availTop = CAPTION_BAND + CAPTION_GAP
    let availH = CANVAS_H - availTop - BOTTOM_MARGIN
    let rawW = CGFloat(raw.width), rawH = CGFloat(raw.height)
    let scale = min(availW / rawW, availH / rawH)
    let shotW = (rawW * scale).rounded()
    let shotH = (rawH * scale).rounded()
    let shotX = ((CANVAS_W - shotW) / 2).rounded()
    let shotTopY = availTop + ((availH - shotH) / 2).rounded()
    let shotY = fromTop(shotTopY, height: shotH)          // y-up origin of the screenshot
    let frameTopYUp = shotY + shotH + FRAME_BORDER        // y-up coordinate of the frame's top edge

    // Background
    ctx.setFillColor(BACKGROUND)
    ctx.fill(CGRect(x: 0, y: 0, width: CANVAS_W, height: CANVAS_H))

    // Peach radial glow, brightest at the frame's top edge
    let glow = CGGradient(colorsSpace: cs, colors: [GLOW_CENTER, BACKGROUND] as CFArray,
                          locations: [0, 1])!
    let glowCenter = CGPoint(x: CANVAS_W / 2, y: frameTopYUp)
    ctx.saveGState()
    ctx.drawRadialGradient(glow, startCenter: glowCenter, startRadius: 0,
                           endCenter: glowCenter, endRadius: CANVAS_W * 0.9,
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()

    drawWatermarkRunner(ctx)
    drawCaption(ctx, caption)

    // Orange frame
    let frameRect = CGRect(x: shotX - FRAME_BORDER, y: shotY - FRAME_BORDER,
                           width: shotW + 2 * FRAME_BORDER, height: shotH + 2 * FRAME_BORDER)
    ctx.setFillColor(ACCENT)
    ctx.addPath(CGPath(roundedRect: frameRect, cornerWidth: FRAME_CORNER_RADIUS,
                       cornerHeight: FRAME_CORNER_RADIUS, transform: nil))
    ctx.fillPath()

    // Screenshot, clipped to rounded corners
    let shotRect = CGRect(x: shotX, y: shotY, width: shotW, height: shotH)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: shotRect, cornerWidth: SHOT_CORNER_RADIUS,
                       cornerHeight: SHOT_CORNER_RADIUS, transform: nil))
    ctx.clip()
    ctx.draw(raw, in: shotRect)
    ctx.restoreGState()

    // Camera dot, just above the frame's top edge
    let dotR: CGFloat = 9
    ctx.setFillColor(CAMERA_DOT)
    ctx.fillEllipse(in: CGRect(x: CANVAS_W / 2 - dotR, y: frameTopYUp + 18 - dotR,
                               width: dotR * 2, height: dotR * 2))

    guard let image = ctx.makeImage() else { fail("Could not render image") }
    return image
}

// MARK: - Caption

func drawCaption(_ ctx: CGContext, _ caption: String) {
    let font = NSFont.boldSystemFont(ofSize: CAPTION_FONT_SIZE) as CTFont
    let maxWidth = CANVAS_W - 2 * CAPTION_SIDE_INSET

    func lineWidth(_ s: String) -> CGFloat {
        let attr = NSAttributedString(string: s, attributes: [.font: font])
        return CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attr), nil, nil, nil)
    }

    let lines = wrap(caption, maxWidth: maxWidth, width: lineWidth)

    var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
    _ = CTLineGetTypographicBounds(
        CTLineCreateWithAttributedString(NSAttributedString(string: "Ag", attributes: [.font: font])),
        &ascent, &descent, &leading)
    let lineHeight = (ascent + descent + leading) * CAPTION_LINE_SPACING
    let blockHeight = lineHeight * CGFloat(lines.count)

    // Vertically centre the text block within the caption band (measured from the top).
    var baselineFromTop = (CAPTION_BAND - blockHeight) / 2 + ascent

    let textColor = NSColor(cgColor: CAPTION_TEXT) ?? .black
    for line in lines {
        let attr = NSAttributedString(string: line, attributes: [.font: font, .foregroundColor: textColor])
        let ctLine = CTLineCreateWithAttributedString(attr)
        let w = CTLineGetTypographicBounds(ctLine, nil, nil, nil)
        ctx.textPosition = CGPoint(x: (CANVAS_W - CGFloat(w)) / 2, y: CANVAS_H - baselineFromTop)
        CTLineDraw(ctLine, ctx)
        baselineFromTop += lineHeight
    }
}

func wrap(_ text: String, maxWidth: CGFloat, width: (String) -> CGFloat) -> [String] {
    var lines: [String] = []
    var current = ""
    for word in text.split(separator: " ").map(String.init) {
        let candidate = current.isEmpty ? word : current + " " + word
        if current.isEmpty || width(candidate) <= maxWidth {
            current = candidate
        } else {
            lines.append(current)
            current = word
        }
    }
    if !current.isEmpty { lines.append(current) }
    return lines
}

// MARK: - Watermark

/// The running-figure glyph from the app's feature graphic (head circle + torso/
/// arm/leg strokes in a local 0-100 space), drawn large and faint in the
/// bottom-right corner so the screenshots share a motif with the store graphic.
func drawWatermarkRunner(_ ctx: CGContext) {
    ctx.saveGState()
    defer { ctx.restoreGState() }

    // Flip into a y-down space so the glyph coordinates (taken verbatim from the
    // Android compositor) map straight across.
    ctx.translateBy(x: 0, y: CANVAS_H)
    ctx.scaleBy(x: 1, y: -1)

    let figureScale = CANVAS_W / 173.0
    let targetX = CANVAS_W - 110.0
    let targetY = CANVAS_H - 110.0
    ctx.translateBy(x: targetX - 57 * figureScale, y: targetY - 50 * figureScale)
    ctx.rotate(by: -8 * .pi / 180)
    ctx.scaleBy(x: figureScale, y: figureScale)

    ctx.setAlpha(WATERMARK_ALPHA)
    ctx.setFillColor(CAPTION_TEXT)
    ctx.setStrokeColor(CAPTION_TEXT)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    ctx.fillEllipse(in: CGRect(x: 50 - 8, y: 26 - 8, width: 16, height: 16))

    func stroke(_ w: CGFloat, _ pts: [(CGFloat, CGFloat)]) {
        ctx.setLineWidth(w)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
        for p in pts.dropFirst() { ctx.addLine(to: CGPoint(x: p.0, y: p.1)) }
        ctx.strokePath()
    }

    stroke(8, [(52, 34), (60, 57)])
    stroke(7, [(50, 43), (33, 31)])
    stroke(7, [(53, 42), (70, 55)])
    stroke(8, [(60, 57), (72, 73), (82, 83)])
    stroke(8, [(58, 57), (46, 71), (32, 64)])
}

// MARK: - Captions file

/// Parses the narrow two-level shape used by fastlane/screenshot_captions.yml:
///   <screen>:
///     <locale>: "<caption>"
func parseCaptions(_ path: String) -> [String: [String: String]] {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        fail("Missing caption file: \(path)")
    }
    let screenKey = try! NSRegularExpression(pattern: #"^(\S+):\s*$"#)
    let localeLine = try! NSRegularExpression(pattern: #"^\s{2}([\w-]+):\s*"(.*)"\s*$"#)

    var result: [String: [String: String]] = [:]
    var current: String?

    for line in text.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

        let range = NSRange(line.startIndex..., in: line)
        if let m = screenKey.firstMatch(in: line, range: range) {
            current = substr(line, m.range(at: 1))
            result[current!] = result[current!] ?? [:]
            continue
        }
        if let m = localeLine.firstMatch(in: line, range: range), let screen = current {
            result[screen, default: [:]][substr(line, m.range(at: 1))] = substr(line, m.range(at: 2))
        }
    }
    return result
}

func substr(_ s: String, _ r: NSRange) -> String {
    Range(r, in: s).map { String(s[$0]) } ?? ""
}

// MARK: - Image IO

func loadCGImage(_ path: String) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

func writePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else {
        fail("Could not create PNG destination at \(path)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) { fail("Could not write \(path)") }
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("screenshot-composer: " + message + "\n").utf8))
    exit(1)
}
