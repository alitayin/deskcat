import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Options {
    var outputSize = 362
    var backgroundTolerance = 96
    var strictPetCounts = false
    var contactSheetURL: URL?
    var anchorReportURL: URL?
    var maxAnchorDrift: CGFloat?
    var minEdgePadding: Int?
    var maxScaleDrift: CGFloat?
    var maxAreaDrift: CGFloat?
    var minLargestComponentRatio: CGFloat?
}

struct RGBA {
    let r: UInt8
    let g: UInt8
    let b: UInt8
    let a: UInt8
}

struct ContentBounds {
    let minX: Int
    let minY: Int
    let maxX: Int
    let maxY: Int

    var midX: CGFloat {
        CGFloat(minX + maxX) / 2
    }

    var baselineY: CGFloat {
        CGFloat(maxY)
    }

    var width: Int {
        maxX - minX + 1
    }

    var height: Int {
        maxY - minY + 1
    }

    func edgePadding(in canvasSize: Int) -> Int {
        min(minX, minY, canvasSize - maxX - 1, canvasSize - maxY - 1)
    }
}

struct ContentMetrics {
    let bounds: ContentBounds
    let alphaArea: Int
    let largestComponentArea: Int
    let significantComponentCount: Int

    var largestComponentRatio: CGFloat {
        guard alphaArea > 0 else {
            return 0
        }
        return CGFloat(largestComponentArea) / CGFloat(alphaArea)
    }
}

struct FrameOutput {
    let name: String
    let image: CGImage
    let metrics: ContentMetrics

    var bounds: ContentBounds {
        metrics.bounds
    }
}

final class Bitmap {
    let width: Int
    let height: Int
    let context: CGContext
    let bytes: UnsafeMutableBufferPointer<UInt8>

    init(width: Int, height: Int) throws {
        self.width = width
        self.height = height

        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: width * 4,
                  space: colorSpace,
                  bitmapInfo: bitmapInfo
              ),
              let data = context.data
        else {
            throw ScriptError("Failed to create bitmap context.")
        }

        self.context = context
        self.bytes = UnsafeMutableBufferPointer(start: data.bindMemory(to: UInt8.self, capacity: width * height * 4), count: width * height * 4)
    }

    convenience init(image: CGImage) throws {
        try self.init(width: image.width, height: image.height)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }

    func offset(x: Int, y: Int) -> Int {
        ((y * width) + x) * 4
    }

    func pixel(x: Int, y: Int) -> RGBA {
        let index = offset(x: x, y: y)
        return RGBA(r: bytes[index], g: bytes[index + 1], b: bytes[index + 2], a: bytes[index + 3])
    }

    func clearPixel(x: Int, y: Int) {
        let index = offset(x: x, y: y)
        bytes[index] = 0
        bytes[index + 1] = 0
        bytes[index + 2] = 0
        bytes[index + 3] = 0
    }

    func makeImage() throws -> CGImage {
        guard let image = context.makeImage() else {
            throw ScriptError("Failed to create output image.")
        }
        return image
    }
}

struct ScriptError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

func usage(exitCode: Int32) -> Never {
    fputs("""
    Usage:
      swift slice_named_sprite_sheet.swift [options] <input.png> <output-dir> <cols> <rows> <name1> ... <nameN>

    Options:
      --output-size <px>             Output canvas size. Default: 362.
      --background-tolerance <n>     RGB flood-fill tolerance. Default: 96.
      --strict-pet-counts            Require walk*=10, sleep=4, every other action=6.
      --contact-sheet <path.png>     Write a visual check sheet after slicing.
      --anchor-report <path.txt>     Write per-frame bbox center/baseline measurements.
      --max-anchor-drift <px>        Fail if a group's bbox center/baseline drifts more than px.
      --min-edge-padding <px>        Fail if visible content is too close to any output edge.
      --max-scale-drift <ratio>      Fail if bbox width/height drifts from group median.
      --max-area-drift <ratio>       Fail if alpha area drifts from group median.
      --min-largest-component-ratio <ratio>
                                     Fail if too much alpha sits outside the main subject.

    Example:
      swift scripts/slice_named_sprite_sheet.swift --strict-pet-counts source.png assets/pet 4 4 walk-1 walk-2 walk-3 walk-4 walk-5 walk-6 walk-7 walk-8 walk-9 walk-10 _skip _skip _skip _skip _skip _skip

    """, stderr)
    exit(exitCode)
}

func parseArguments(_ arguments: [String]) throws -> (Options, URL, URL, Int, Int, [String]) {
    var options = Options()
    var positional: [String] = []
    var index = 1

    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--output-size":
            index += 1
            guard index < arguments.count, let value = Int(arguments[index]), value > 0 else {
                throw ScriptError("--output-size requires a positive integer.")
            }
            options.outputSize = value
        case "--background-tolerance":
            index += 1
            guard index < arguments.count, let value = Int(arguments[index]), value >= 0 else {
                throw ScriptError("--background-tolerance requires a non-negative integer.")
            }
            options.backgroundTolerance = value
        case "--strict-pet-counts":
            options.strictPetCounts = true
        case "--contact-sheet":
            index += 1
            guard index < arguments.count else {
                throw ScriptError("--contact-sheet requires a path.")
            }
            options.contactSheetURL = URL(fileURLWithPath: arguments[index])
        case "--anchor-report":
            index += 1
            guard index < arguments.count else {
                throw ScriptError("--anchor-report requires a path.")
            }
            options.anchorReportURL = URL(fileURLWithPath: arguments[index])
        case "--max-anchor-drift":
            index += 1
            guard index < arguments.count, let value = Double(arguments[index]), value >= 0 else {
                throw ScriptError("--max-anchor-drift requires a non-negative number.")
            }
            options.maxAnchorDrift = CGFloat(value)
        case "--min-edge-padding":
            index += 1
            guard index < arguments.count, let value = Int(arguments[index]), value >= 0 else {
                throw ScriptError("--min-edge-padding requires a non-negative integer.")
            }
            options.minEdgePadding = value
        case "--max-scale-drift":
            index += 1
            guard index < arguments.count, let value = Double(arguments[index]), value >= 0 else {
                throw ScriptError("--max-scale-drift requires a non-negative number.")
            }
            options.maxScaleDrift = CGFloat(value)
        case "--max-area-drift":
            index += 1
            guard index < arguments.count, let value = Double(arguments[index]), value >= 0 else {
                throw ScriptError("--max-area-drift requires a non-negative number.")
            }
            options.maxAreaDrift = CGFloat(value)
        case "--min-largest-component-ratio":
            index += 1
            guard index < arguments.count, let value = Double(arguments[index]), value >= 0, value <= 1 else {
                throw ScriptError("--min-largest-component-ratio requires a number between 0 and 1.")
            }
            options.minLargestComponentRatio = CGFloat(value)
        case "--help", "-h":
            usage(exitCode: 0)
        default:
            positional.append(argument)
        }
        index += 1
    }

    guard positional.count >= 5 else {
        usage(exitCode: 1)
    }

    let inputURL = URL(fileURLWithPath: positional[0])
    let outputDirectory = URL(fileURLWithPath: positional[1], isDirectory: true)
    guard let columns = Int(positional[2]), columns > 0,
          let rows = Int(positional[3]), rows > 0
    else {
        throw ScriptError("Columns and rows must be positive integers.")
    }

    let names = Array(positional.dropFirst(4))
    guard names.count == columns * rows else {
        throw ScriptError("Columns, rows, and frame names do not match: \(columns)x\(rows)=\(columns * rows), names=\(names.count).")
    }

    let outputNames = names.filter { !isSkippedFrameName($0) }
    if options.strictPetCounts {
        try validatePetFrameCounts(outputNames)
    }

    return (options, inputURL, outputDirectory, columns, rows, names)
}

func isSkippedFrameName(_ frameName: String) -> Bool {
    frameName == "_" || frameName == "-" || frameName.hasPrefix("_skip") || frameName.hasPrefix("skip")
}

func groupName(for frameName: String) -> String {
    guard let dash = frameName.lastIndex(of: "-"),
          Int(frameName[frameName.index(after: dash)...]) != nil
    else {
        return frameName
    }
    return String(frameName[..<dash])
}

func expectedFrameCount(for group: String) -> Int {
    if group == "walk" || group == "walk-left" || group == "walk-right" {
        return 10
    }
    if group == "sleep" {
        return 4
    }
    return 6
}

func validatePetFrameCounts(_ names: [String]) throws {
    let counts = Dictionary(grouping: names.filter { !isSkippedFrameName($0) }, by: groupName).mapValues(\.count)
    for group in counts.keys.sorted() {
        let expected = expectedFrameCount(for: group)
        let actual = counts[group] ?? 0
        guard actual == expected else {
            throw ScriptError("Frame count mismatch for \(group): expected \(expected), got \(actual).")
        }
    }
}

func loadImage(_ url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw ScriptError("Failed to read input image: \(url.path)")
    }
    return image
}

func dominantBorderColor(in bitmap: Bitmap) -> RGBA {
    struct Bucket: Hashable {
        let r: Int
        let g: Int
        let b: Int
    }

    struct Accumulator {
        var count = 0
        var r = 0
        var g = 0
        var b = 0
        var a = 0
    }

    var buckets: [Bucket: Accumulator] = [:]
    let stepX = max(1, bitmap.width / 64)
    let stepY = max(1, bitmap.height / 64)

    func add(_ pixel: RGBA) {
        let key = Bucket(r: Int(pixel.r) / 16, g: Int(pixel.g) / 16, b: Int(pixel.b) / 16)
        var value = buckets[key] ?? Accumulator()
        value.count += 1
        value.r += Int(pixel.r)
        value.g += Int(pixel.g)
        value.b += Int(pixel.b)
        value.a += Int(pixel.a)
        buckets[key] = value
    }

    for x in stride(from: 0, to: bitmap.width, by: stepX) {
        add(bitmap.pixel(x: x, y: 0))
        add(bitmap.pixel(x: x, y: bitmap.height - 1))
    }

    for y in stride(from: 0, to: bitmap.height, by: stepY) {
        add(bitmap.pixel(x: 0, y: y))
        add(bitmap.pixel(x: bitmap.width - 1, y: y))
    }

    guard let dominant = buckets.values.max(by: { $0.count < $1.count }), dominant.count > 0 else {
        return bitmap.pixel(x: 0, y: 0)
    }

    return RGBA(
        r: UInt8(dominant.r / dominant.count),
        g: UInt8(dominant.g / dominant.count),
        b: UInt8(dominant.b / dominant.count),
        a: UInt8(dominant.a / dominant.count)
    )
}

func colorDistance(_ left: RGBA, _ right: RGBA) -> Int {
    abs(Int(left.r) - Int(right.r)) +
        abs(Int(left.g) - Int(right.g)) +
        abs(Int(left.b) - Int(right.b))
}

func removeFloodFilledBackground(from bitmap: Bitmap, tolerance: Int) {
    let background = dominantBorderColor(in: bitmap)
    var visited = Array(repeating: false, count: bitmap.width * bitmap.height)
    var queue: [(Int, Int)] = []

    func linearIndex(x: Int, y: Int) -> Int {
        (y * bitmap.width) + x
    }

    func isBackground(_ pixel: RGBA) -> Bool {
        if pixel.a <= 8 {
            return true
        }
        return colorDistance(pixel, background) <= tolerance
    }

    func enqueue(_ x: Int, _ y: Int) {
        guard x >= 0, y >= 0, x < bitmap.width, y < bitmap.height else {
            return
        }

        let index = linearIndex(x: x, y: y)
        guard !visited[index], isBackground(bitmap.pixel(x: x, y: y)) else {
            return
        }

        visited[index] = true
        queue.append((x, y))
    }

    for x in 0 ..< bitmap.width {
        enqueue(x, 0)
        enqueue(x, bitmap.height - 1)
    }

    for y in 0 ..< bitmap.height {
        enqueue(0, y)
        enqueue(bitmap.width - 1, y)
    }

    var cursor = 0
    while cursor < queue.count {
        let (x, y) = queue[cursor]
        cursor += 1
        enqueue(x - 1, y)
        enqueue(x + 1, y)
        enqueue(x, y - 1)
        enqueue(x, y + 1)
    }

    for y in 0 ..< bitmap.height {
        for x in 0 ..< bitmap.width where visited[linearIndex(x: x, y: y)] {
            bitmap.clearPixel(x: x, y: y)
        }
    }
}

func contentBounds(in bitmap: Bitmap) -> ContentBounds? {
    var minX = bitmap.width
    var minY = bitmap.height
    var maxX = 0
    var maxY = 0
    var found = false

    for y in 0 ..< bitmap.height {
        for x in 0 ..< bitmap.width {
            let alpha = bitmap.bytes[bitmap.offset(x: x, y: y) + 3]
            if alpha > 10 {
                found = true
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
    }

    guard found else {
        return nil
    }
    return ContentBounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
}

func contentMetrics(in bitmap: Bitmap) -> ContentMetrics? {
    guard let bounds = contentBounds(in: bitmap) else {
        return nil
    }

    let alphaThreshold: UInt8 = 10
    var alphaArea = 0
    var visited = Array(repeating: false, count: bitmap.width * bitmap.height)
    var componentAreas: [Int] = []

    func linearIndex(x: Int, y: Int) -> Int {
        (y * bitmap.width) + x
    }

    func isContent(x: Int, y: Int) -> Bool {
        bitmap.bytes[bitmap.offset(x: x, y: y) + 3] > alphaThreshold
    }

    for y in 0 ..< bitmap.height {
        for x in 0 ..< bitmap.width where isContent(x: x, y: y) {
            alphaArea += 1
        }
    }

    for y in 0 ..< bitmap.height {
        for x in 0 ..< bitmap.width {
            let startIndex = linearIndex(x: x, y: y)
            guard !visited[startIndex], isContent(x: x, y: y) else {
                continue
            }

            var area = 0
            var queue = [(x, y)]
            visited[startIndex] = true
            var cursor = 0

            while cursor < queue.count {
                let (currentX, currentY) = queue[cursor]
                cursor += 1
                area += 1

                for (nextX, nextY) in [
                    (currentX - 1, currentY),
                    (currentX + 1, currentY),
                    (currentX, currentY - 1),
                    (currentX, currentY + 1)
                ] {
                    guard nextX >= 0, nextY >= 0, nextX < bitmap.width, nextY < bitmap.height else {
                        continue
                    }

                    let nextIndex = linearIndex(x: nextX, y: nextY)
                    guard !visited[nextIndex], isContent(x: nextX, y: nextY) else {
                        continue
                    }

                    visited[nextIndex] = true
                    queue.append((nextX, nextY))
                }
            }

            componentAreas.append(area)
        }
    }

    let largestComponentArea = componentAreas.max() ?? 0
    let significantThreshold = max(20, Int(CGFloat(alphaArea) * 0.015))
    let significantComponentCount = componentAreas.filter { $0 >= significantThreshold }.count

    return ContentMetrics(
        bounds: bounds,
        alphaArea: alphaArea,
        largestComponentArea: largestComponentArea,
        significantComponentCount: significantComponentCount
    )
}

func assertTransparentCorners(_ bitmap: Bitmap, name: String) throws {
    let points = [
        (0, 0),
        (bitmap.width - 1, 0),
        (0, bitmap.height - 1),
        (bitmap.width - 1, bitmap.height - 1)
    ]

    let opaqueCorners = points.filter { x, y in
        bitmap.bytes[bitmap.offset(x: x, y: y) + 3] > 10
    }

    guard opaqueCorners.isEmpty else {
        throw ScriptError("Background removal failed for \(name): one or more corners are still opaque.")
    }
}

func normalizedFullCell(_ image: CGImage, outputSize: Int) throws -> (CGImage, ContentMetrics) {
    let bitmap = try Bitmap(width: outputSize, height: outputSize)
    bitmap.context.clear(CGRect(x: 0, y: 0, width: outputSize, height: outputSize))

    let scale = min(CGFloat(outputSize) / CGFloat(image.width), CGFloat(outputSize) / CGFloat(image.height))
    let drawWidth = CGFloat(image.width) * scale
    let drawHeight = CGFloat(image.height) * scale
    let drawRect = CGRect(
        x: (CGFloat(outputSize) - drawWidth) / 2,
        y: (CGFloat(outputSize) - drawHeight) / 2,
        width: drawWidth,
        height: drawHeight
    )

    bitmap.context.interpolationQuality = .high
    bitmap.context.draw(image, in: drawRect)
    try assertTransparentCorners(bitmap, name: "normalized frame")

    guard let metrics = contentMetrics(in: bitmap) else {
        throw ScriptError("Normalized frame is empty after background removal.")
    }

    return (try bitmap.makeImage(), metrics)
}

func savePNG(_ cgImage: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw ScriptError("Failed to create PNG destination: \(url.path)")
    }
    CGImageDestinationAddImage(destination, cgImage, nil)
    if !CGImageDestinationFinalize(destination) {
        throw ScriptError("Failed to write PNG: \(url.path)")
    }
}

func assertAnchorDrift(_ outputs: [FrameOutput], maxDrift: CGFloat) throws {
    let grouped = Dictionary(grouping: outputs, by: { groupName(for: $0.name) })

    for group in grouped.keys.sorted() {
        guard let frames = grouped[group], !frames.isEmpty else {
            continue
        }
        let referenceCenter = median(frames.map { $0.bounds.midX })
        let referenceBaseline = median(frames.map { $0.bounds.baselineY })

        for frame in frames {
            let centerDrift = abs(frame.bounds.midX - referenceCenter)
            let baselineDrift = abs(frame.bounds.baselineY - referenceBaseline)
            if centerDrift > maxDrift || baselineDrift > maxDrift {
                throw ScriptError(
                    "Anchor drift too large for \(frame.name): center=\(String(format: "%.1f", centerDrift))px baseline=\(String(format: "%.1f", baselineDrift))px max=\(maxDrift)px."
                )
            }
        }
    }
}

func assertEdgePadding(_ outputs: [FrameOutput], outputSize: Int, minPadding: Int) throws {
    for output in outputs {
        let padding = output.bounds.edgePadding(in: outputSize)
        if padding < minPadding {
            throw ScriptError("Frame \(output.name) is too close to the output edge: padding=\(padding)px min=\(minPadding)px.")
        }
    }
}

func assertScaleDrift(_ outputs: [FrameOutput], maxDrift: CGFloat) throws {
    let grouped = Dictionary(grouping: outputs, by: { groupName(for: $0.name) })

    for group in grouped.keys.sorted() {
        guard let frames = grouped[group], !frames.isEmpty else {
            continue
        }

        let referenceWidth = median(frames.map { CGFloat($0.bounds.width) })
        let referenceHeight = median(frames.map { CGFloat($0.bounds.height) })
        for frame in frames {
            let widthDrift = relativeDrift(CGFloat(frame.bounds.width), reference: referenceWidth)
            let heightDrift = relativeDrift(CGFloat(frame.bounds.height), reference: referenceHeight)
            if widthDrift > maxDrift || heightDrift > maxDrift {
                throw ScriptError(
                    "Scale drift too large for \(frame.name): width=\(format(widthDrift)) height=\(format(heightDrift)) max=\(format(maxDrift))."
                )
            }
        }
    }
}

func assertAreaDrift(_ outputs: [FrameOutput], maxDrift: CGFloat) throws {
    let grouped = Dictionary(grouping: outputs, by: { groupName(for: $0.name) })

    for group in grouped.keys.sorted() {
        guard let frames = grouped[group], !frames.isEmpty else {
            continue
        }

        let referenceArea = median(frames.map { CGFloat($0.metrics.alphaArea) })
        for frame in frames {
            let drift = relativeDrift(CGFloat(frame.metrics.alphaArea), reference: referenceArea)
            if drift > maxDrift {
                throw ScriptError("Area drift too large for \(frame.name): area=\(format(drift)) max=\(format(maxDrift)).")
            }
        }
    }
}

func assertComponentQuality(_ outputs: [FrameOutput], minLargestComponentRatio: CGFloat) throws {
    for output in outputs {
        if output.metrics.largestComponentRatio < minLargestComponentRatio {
            throw ScriptError(
                "Frame \(output.name) has fragmented alpha: largest_component_ratio=\(format(output.metrics.largestComponentRatio)) min=\(format(minLargestComponentRatio))."
            )
        }
    }
}

func relativeDrift(_ value: CGFloat, reference: CGFloat) -> CGFloat {
    guard reference > 0 else {
        return 0
    }
    return abs(value - reference) / reference
}

func median(_ values: [CGFloat]) -> CGFloat {
    guard !values.isEmpty else {
        return 0
    }

    let sorted = values.sorted()
    let middle = sorted.count / 2
    if sorted.count % 2 == 0 {
        return (sorted[middle - 1] + sorted[middle]) / 2
    }
    return sorted[middle]
}

func writeAnchorReport(_ outputs: [FrameOutput], to url: URL) throws {
    let grouped = Dictionary(grouping: outputs, by: { groupName(for: $0.name) })
    var lines: [String] = []

    for group in grouped.keys.sorted() {
        guard let frames = grouped[group] else {
            continue
        }

        let referenceCenter = median(frames.map { $0.bounds.midX })
        let referenceBaseline = median(frames.map { $0.bounds.baselineY })
        lines.append("[\(group)] reference_center=\(format(referenceCenter)) reference_baseline=\(format(referenceBaseline))")

        for frame in frames.sorted(by: { $0.name < $1.name }) {
            let centerDrift = frame.bounds.midX - referenceCenter
            let baselineDrift = frame.bounds.baselineY - referenceBaseline
            lines.append(
                "\(frame.name) bbox=(\(frame.bounds.minX),\(frame.bounds.minY))-(\(frame.bounds.maxX),\(frame.bounds.maxY)) size=\(frame.bounds.width)x\(frame.bounds.height) alpha_area=\(frame.metrics.alphaArea) largest_component_ratio=\(format(frame.metrics.largestComponentRatio)) significant_components=\(frame.metrics.significantComponentCount) center=\(format(frame.bounds.midX)) baseline=\(format(frame.bounds.baselineY)) center_drift=\(format(centerDrift)) baseline_drift=\(format(baselineDrift))"
            )
        }
        lines.append("")
    }

    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
}

func format(_ value: CGFloat) -> String {
    String(format: "%.1f", Double(value))
}

func writeContactSheet(_ outputs: [FrameOutput], to url: URL) throws {
    let columns = min(10, max(1, outputs.count))
    let rows = Int(ceil(Double(outputs.count) / Double(columns)))
    let cellSize = NSSize(width: 142, height: 166)
    let previewSize = NSSize(width: 122, height: 122)
    let sheetSize = NSSize(width: CGFloat(columns) * cellSize.width, height: CGFloat(rows) * cellSize.height)
    let sheet = NSImage(size: sheetSize)

    sheet.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: sheetSize).fill()

    for (index, output) in outputs.enumerated() {
        let column = index % columns
        let row = index / columns
        let x = CGFloat(column) * cellSize.width
        let y = sheetSize.height - CGFloat(row + 1) * cellSize.height
        let cellRect = NSRect(x: x, y: y, width: cellSize.width, height: cellSize.height)

        NSColor(calibratedWhite: 0.90, alpha: 1).setStroke()
        NSBezierPath(rect: cellRect).stroke()

        let image = NSImage(cgImage: output.image, size: NSSize(width: output.image.width, height: output.image.height))
        image.draw(in: NSRect(
            x: x + (cellSize.width - previewSize.width) / 2,
            y: y + 32,
            width: previewSize.width,
            height: previewSize.height
        ))

        (output.name as NSString).draw(
            at: NSPoint(x: x + 8, y: y + 10),
            withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.black
            ]
        )
    }

    sheet.unlockFocus()

    guard let tiff = sheet.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:])
    else {
        throw ScriptError("Failed to encode contact sheet.")
    }

    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
}

func run() throws {
    let (options, inputURL, outputDirectory, columns, rows, names) = try parseArguments(CommandLine.arguments)
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    let sheet = try loadImage(inputURL)
    guard sheet.width % columns == 0, sheet.height % rows == 0 else {
        throw ScriptError("Sheet size \(sheet.width)x\(sheet.height) is not divisible by grid \(columns)x\(rows).")
    }

    let cellWidth = sheet.width / columns
    let cellHeight = sheet.height / rows
    guard cellWidth > 0, cellHeight > 0 else {
        throw ScriptError("Invalid cell size.")
    }

    var outputs: [FrameOutput] = []

    for (index, name) in names.enumerated() {
        if isSkippedFrameName(name) {
            continue
        }

        let column = index % columns
        let row = index / columns
        let rect = CGRect(x: column * cellWidth, y: row * cellHeight, width: cellWidth, height: cellHeight)
        guard let cell = sheet.cropping(to: rect) else {
            throw ScriptError("Failed to crop cell for \(name).")
        }

        let cellBitmap = try Bitmap(image: cell)
        removeFloodFilledBackground(from: cellBitmap, tolerance: options.backgroundTolerance)
        try assertTransparentCorners(cellBitmap, name: name)
        guard contentBounds(in: cellBitmap) != nil else {
            throw ScriptError("Frame \(name) is empty after background removal.")
        }

        let transparentCell = try cellBitmap.makeImage()
        let (normalizedImage, metrics) = try normalizedFullCell(transparentCell, outputSize: options.outputSize)
        outputs.append(FrameOutput(name: name, image: normalizedImage, metrics: metrics))
    }

    if let maxAnchorDrift = options.maxAnchorDrift {
        try assertAnchorDrift(outputs, maxDrift: maxAnchorDrift)
    }

    if let minEdgePadding = options.minEdgePadding {
        try assertEdgePadding(outputs, outputSize: options.outputSize, minPadding: minEdgePadding)
    }

    if let maxScaleDrift = options.maxScaleDrift {
        try assertScaleDrift(outputs, maxDrift: maxScaleDrift)
    }

    if let maxAreaDrift = options.maxAreaDrift {
        try assertAreaDrift(outputs, maxDrift: maxAreaDrift)
    }

    if let minLargestComponentRatio = options.minLargestComponentRatio {
        try assertComponentQuality(outputs, minLargestComponentRatio: minLargestComponentRatio)
    }

    for output in outputs {
        try savePNG(output.image, to: outputDirectory.appendingPathComponent(output.name + ".png"))
    }

    if let contactSheetURL = options.contactSheetURL {
        try writeContactSheet(outputs, to: contactSheetURL)
        print("Contact sheet: \(contactSheetURL.path)")
    }

    if let anchorReportURL = options.anchorReportURL {
        try writeAnchorReport(outputs, to: anchorReportURL)
        print("Anchor report: \(anchorReportURL.path)")
    }

    let counts = Dictionary(grouping: names.filter { !isSkippedFrameName($0) }, by: groupName).mapValues(\.count)
    for group in counts.keys.sorted() {
        print("\(group): \(counts[group] ?? 0)")
    }
    print("Wrote \(outputs.count) frames to \(outputDirectory.path)")
}

do {
    try run()
} catch let error as ScriptError {
    fputs("Error: \(error.description)\n", stderr)
    exit(1)
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
