import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fputs("Usage: swift make_icns.swift <iconset-dir> <output.icns>\n", stderr)
    exit(1)
}

let iconsetURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
let outputURL = URL(fileURLWithPath: arguments[2])

let icons: [(type: String, filename: String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

func appendASCII(_ string: String, to data: inout Data) {
    data.append(contentsOf: string.utf8)
}

func appendBigEndianUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { bytes in
        data.append(contentsOf: bytes)
    }
}

var chunks = Data()

for icon in icons {
    let fileURL = iconsetURL.appendingPathComponent(icon.filename)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
        continue
    }

    let pngData = try Data(contentsOf: fileURL)
    let chunkLength = UInt32(pngData.count + 8)
    appendASCII(icon.type, to: &chunks)
    appendBigEndianUInt32(chunkLength, to: &chunks)
    chunks.append(pngData)
}

guard !chunks.isEmpty else {
    fputs("No icon PNGs found in \(iconsetURL.path).\n", stderr)
    exit(1)
}

var output = Data()
appendASCII("icns", to: &output)
appendBigEndianUInt32(UInt32(chunks.count + 8), to: &output)
output.append(chunks)
try output.write(to: outputURL)
