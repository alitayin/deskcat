import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Pixel {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8
}

let arguments = CommandLine.arguments
guard arguments.count >= 6 else {
    fputs("Usage: swift slice_named_sprite_sheet.swift <input.png> <output-dir> <cols> <rows> <name1> ... <nameN>\n", stderr)
    exit(1)
}

let inputURL = URL(fileURLWithPath: arguments[1])
let outputDirectory = URL(fileURLWithPath: arguments[2], isDirectory: true)
let columns = Int(arguments[3]) ?? 0
let rows = Int(arguments[4]) ?? 0
let names = Array(arguments.dropFirst(5))

guard columns > 0, rows > 0, names.count == columns * rows else {
    fputs("Columns, rows, and frame names do not match.\n", stderr)
    exit(1)
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fputs("Failed to read input image.\n", stderr)
    exit(1)
}

let width = image.width
let height = image.height
let bytesPerPixel = 4
let bytesPerRow = width * bytesPerPixel

guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(
          data: nil,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: bytesPerRow,
          space: colorSpace,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
else {
    fputs("Failed to create bitmap context.\n", stderr)
    exit(1)
}

context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

guard let data = context.data else {
    fputs("No bitmap data available.\n", stderr)
    exit(1)
}

let pixelBuffer = data.bindMemory(to: Pixel.self, capacity: width * height)

func indexFor(x: Int, y: Int) -> Int {
    y * width + x
}

func nearBackground(_ pixel: Pixel) -> Bool {
    if pixel.a < 250 {
        return false
    }

    let brightness = (Int(pixel.r) + Int(pixel.g) + Int(pixel.b)) / 3
    let spread = max(abs(Int(pixel.r) - Int(pixel.g)), abs(Int(pixel.g) - Int(pixel.b)), abs(Int(pixel.r) - Int(pixel.b)))
    return brightness >= 224 && spread <= 24
}

var visited = Array(repeating: false, count: width * height)
var queue: [(Int, Int)] = []

func enqueue(_ x: Int, _ y: Int) {
    guard x >= 0, y >= 0, x < width, y < height else {
        return
    }

    let index = indexFor(x: x, y: y)
    guard !visited[index], nearBackground(pixelBuffer[index]) else {
        return
    }

    visited[index] = true
    queue.append((x, y))
}

for x in 0 ..< width {
    enqueue(x, 0)
    enqueue(x, height - 1)
}

for y in 0 ..< height {
    enqueue(0, y)
    enqueue(width - 1, y)
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

for index in 0 ..< (width * height) where visited[index] {
    pixelBuffer[index].a = 0
}

guard let transparentImage = context.makeImage() else {
    fputs("Failed to create transparent image.\n", stderr)
    exit(1)
}

func savePNG(_ cgImage: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "CatBuddy", code: 1)
    }
    CGImageDestinationAddImage(destination, cgImage, nil)
    if !CGImageDestinationFinalize(destination) {
        throw NSError(domain: "CatBuddy", code: 2)
    }
}

let cellWidth = width / columns
let cellHeight = height / rows

for (index, name) in names.enumerated() {
    let column = index % columns
    let row = index / columns
    let rect = CGRect(x: column * cellWidth, y: row * cellHeight, width: cellWidth, height: cellHeight)
    guard let cropped = transparentImage.cropping(to: rect) else {
        continue
    }
    try savePNG(cropped, to: outputDirectory.appendingPathComponent(name + ".png"))
}

print("Wrote \(names.count) frames to \(outputDirectory.path)")
