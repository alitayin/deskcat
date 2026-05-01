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
    var maxAnchorDrift: CGFloat?
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
}

struct FrameOutput {
    let name: String
    let image: CGImage
    let bounds: ContentBounds
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
      --max-anchor-drift <px>        Fail if a group's bbox center/baseline drifts more than px.

    Example:
      swift scripts/slice_named_sprite_sheet.swift --strict-pet-counts source.png assets/pet 5 2 walk-1 walk-2 walk-3 walk-4 walk-5 walk-6 walk-7 walk-8 walk-9 walk-10

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
        case "--max-anchor-drift":
            index += 1
            guard index < arguments.count, let value = Double(arguments[index]), value >= 0 else {
                throw ScriptError("--max-anchor-drift requires a non-negative number.")
            }
            options.maxAnchorDrift = CGFloat(value)
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

    if options.strictPetCounts {
        try validatePetFrameCounts(names)
    }

    return (options, inputURL, outputDirectory, columns, rows, names)
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
    let counts = Dictionary(grouping: names, by: groupName).mapValues(\.count)
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

func normalizedFullCell(_ image: CGImage, outputSize: Int) throws -> (CGImage, ContentBounds) {
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

    guard let bounds = contentBounds(in: bitmap) else {
        throw ScriptError("Normalized frame is empty after background removal.")
    }

    return (try bitmap.makeImage(), bounds)
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
        guard let frames = grouped[group], let reference = frames.first else {
            continue
        }

        for frame in frames.dropFirst() {
            let centerDrift = abs(frame.bounds.midX - reference.bounds.midX)
            let baselineDrift = abs(frame.bounds.baselineY - reference.bounds.baselineY)
            if centerDrift > maxDrift || baselineDrift > maxDrift {
                throw ScriptError(
                    "Anchor drift too large for \(frame.name): center=\(String(format: "%.1f", centerDrift))px baseline=\(String(format: "%.1f", baselineDrift))px max=\(maxDrift)px."
                )
            }
        }
    }
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
    let cellWidth = sheet.width / columns
    let cellHeight = sheet.height / rows
    guard cellWidth > 0, cellHeight > 0 else {
        throw ScriptError("Invalid cell size.")
    }

    var outputs: [FrameOutput] = []

    for (index, name) in names.enumerated() {
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
        let (normalizedImage, bounds) = try normalizedFullCell(transparentCell, outputSize: options.outputSize)
        outputs.append(FrameOutput(name: name, image: normalizedImage, bounds: bounds))
    }

    if let maxAnchorDrift = options.maxAnchorDrift {
        try assertAnchorDrift(outputs, maxDrift: maxAnchorDrift)
    }

    for output in outputs {
        try savePNG(output.image, to: outputDirectory.appendingPathComponent(output.name + ".png"))
    }

    if let contactSheetURL = options.contactSheetURL {
        try writeContactSheet(outputs, to: contactSheetURL)
        print("Contact sheet: \(contactSheetURL.path)")
    }

    let counts = Dictionary(grouping: names, by: groupName).mapValues(\.count)
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
