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
guard arguments.count >= 3 else {
    fputs("Usage: swift slice_sprite_sheet.swift <input.png> <output-dir>\n", stderr)
    exit(1)
}

let inputURL = URL(fileURLWithPath: arguments[1])
let outputDirectory = URL(fileURLWithPath: arguments[2], isDirectory: true)
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
let bitsPerComponent = 8

guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(
          data: nil,
          width: width,
          height: height,
          bitsPerComponent: bitsPerComponent,
          bytesPerRow: bytesPerRow,
          space: colorSpace,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
else {
    fputs("Failed to create bitmap context.\n", stderr)
    exit(1)
}

let drawRect = CGRect(x: 0, y: 0, width: width, height: height)
context.draw(image, in: drawRect)

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
    guard x >= 0, y >= 0, x < width, y < height else { return }
    let index = indexFor(x: x, y: y)
    guard !visited[index] else { return }
    let pixel = pixelBuffer[index]
    guard nearBackground(pixel) else { return }
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
    let neighbors = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
    for (nx, ny) in neighbors {
        enqueue(nx, ny)
    }
}

for idx in 0 ..< width * height {
    if visited[idx] {
        pixelBuffer[idx].a = 0
    }
}

guard let transparentImage = context.makeImage() else {
    fputs("Failed to create transparent image.\n", stderr)
    exit(1)
}

let cellWidth = width / 4
let cellHeight = height / 3

let mapping: [(name: String, column: Int, row: Int)] = [
    ("walk-1", 0, 0),
    ("walk-2", 1, 0),
    ("walk-3", 2, 0),
    ("walk-4", 3, 0),
    ("walk-5", 0, 1),
    ("walk-6", 1, 1),
    ("walk-7", 2, 1),
    ("walk-8", 3, 1),
    ("idle-1", 0, 2),
    ("idle-2", 1, 2),
    ("sleep-1", 2, 2),
    ("sleep-2", 3, 2)
]

func savePNG(_ cgImage: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "CatBuddy", code: 1)
    }
    CGImageDestinationAddImage(destination, cgImage, nil)
    if !CGImageDestinationFinalize(destination) {
        throw NSError(domain: "CatBuddy", code: 2)
    }
}

for item in mapping {
    let x = item.column * cellWidth
    let yFromTop = item.row * cellHeight
    let y = yFromTop
    let rect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
    guard let cropped = transparentImage.cropping(to: rect) else {
        continue
    }
    let destination = outputDirectory.appendingPathComponent(item.name + ".png")
    try savePNG(cropped, to: destination)
}

print("Wrote sprite frames to \(outputDirectory.path)")
