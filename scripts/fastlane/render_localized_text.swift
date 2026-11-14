// Text-only CoreText shaping and coverage proof. No app pixels are generated here.
import AppKit
import CoreText
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(2)
}

guard CommandLine.arguments.count == 3 else { fail("Usage: text-helper request.json response.json") }
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let response = URL(fileURLWithPath: CommandLine.arguments[2])
let requests = try JSONSerialization.jsonObject(with: Data(contentsOf: input)) as! [[String: Any]]
var results = [[String: Any]]()
for request in requests {
    let text = request["text"] as! String
    let family = request["font"] as! String
    let maximum = request["size"] as! Double
    let width = request["width"] as! Double
    let height = request["height"] as! Double
    let minimum = request["minimum"] as! Double
    let parts = text.components(separatedBy: "\n")
    var size = maximum
    var lines = [CTLine]()
    var rects = [CGRect]()
    var step = 0.0
    while true {
        let font = CTFontCreateWithName(family as CFString, size, nil)
        lines = parts.map {
            CTLineCreateWithAttributedString(NSAttributedString(string: $0, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true
            ]))
        }
        rects = lines.map { CTLineGetBoundsWithOptions($0, [.useGlyphPathBounds]) }
        step = max(CTFontGetAscent(font) + CTFontGetDescent(font), size * 1.18)
        let inkHeight = (Double(lines.count - 1) * step) +
            (rects.map { $0.maxY }.max() ?? 0) - (rects.map { $0.minY }.min() ?? 0)
        if (rects.map { $0.width }.max() ?? 0) <= width - 8 && inkHeight <= height - 8 {
            break
        }
        size -= 1
        if size < minimum { fail("Text cannot fit at readable minimum: \(text)") }
    }
    var names = Set<String>()
    var missing = 0
    var glyphCount = 0
    var positioned = false
    for line in lines {
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            missing += glyphs.filter { $0 == 0 }.count
            glyphCount += count
            positioned = positioned || positions.contains { $0 != .zero }
            let attributes = CTRunGetAttributes(run) as NSDictionary
            let font = attributes[kCTFontAttributeName] as! CTFont
            names.insert(CTFontCopyPostScriptName(font) as String)
        }
    }
    if missing != 0 || glyphCount == 0 { fail("Missing glyphs: \(text)") }
    let minY = rects.map { $0.minY }.min() ?? 0
    let maxY = rects.map { $0.maxY }.max() ?? 0
    let inkHeight = Double(lines.count - 1) * step + maxY - minY
    if let output = request["output"] as? String {
        guard let context = CGContext(data: nil, width: Int(width), height: Int(height),
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { fail("Cannot allocate text bitmap") }
        let hex = (request["color"] as! String).replacingOccurrences(of: "#", with: "")
        let rgb = UInt32(hex, radix: 16)!
        context.setFillColor(CGColor(red: Double((rgb >> 16) & 255) / 255,
                                    green: Double((rgb >> 8) & 255) / 255,
                                    blue: Double(rgb & 255) / 255, alpha: 1))
        for (index, line) in lines.enumerated() {
            let rect = rects[index]
            context.textPosition = CGPoint(x: (width - rect.width) / 2 - rect.minX,
                y: (height - inkHeight) / 2 - minY + Double(lines.count - 1 - index) * step)
            CTLineDraw(line, context)
        }
        let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
    }
    results.append([
        "text": text, "fonts": names.sorted(), "missing_glyphs": missing,
        "glyph_count": glyphCount, "positioned_glyphs": positioned,
        "engine": "CoreText", "point_size": size,
        "ink_width": rects.map { $0.width }.max() ?? 0,
        "ink_height": inkHeight, "bounds": [width, height],
        "line_count": lines.count
    ])
}
try JSONSerialization.data(withJSONObject: results, options: [.sortedKeys, .prettyPrinted])
    .write(to: response)
