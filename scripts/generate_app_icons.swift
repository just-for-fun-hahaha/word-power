import AppKit
import SwiftUI

private struct IconPalette {
    let backgroundStart: Color
    let backgroundEnd: Color
    let orbPrimary: Color
    let orbSecondary: Color
    let symbol: Color
}

private struct IconVariant {
    let filename: String
    let palette: IconPalette
}

private struct AppIconArtwork: View {
    let palette: IconPalette
    let canvasSize: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.backgroundStart, palette.backgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(palette.orbPrimary.opacity(0.18))
                .frame(width: canvasSize * 0.72, height: canvasSize * 0.72)
                .offset(x: -canvasSize * 0.34, y: -canvasSize * 0.36)

            Circle()
                .fill(palette.orbSecondary.opacity(0.16))
                .frame(width: canvasSize * 0.42, height: canvasSize * 0.42)
                .offset(x: canvasSize * 0.22, y: canvasSize * 0.24)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: canvasSize * 0.5, height: canvasSize * 0.5)
                .blur(radius: canvasSize * 0.02)

            Image(systemName: "book.pages.fill")
                .font(.system(size: canvasSize * 0.42, weight: .semibold))
                .foregroundStyle(palette.symbol)
                .shadow(color: .black.opacity(0.18), radius: canvasSize * 0.022, x: 0, y: canvasSize * 0.012)
        }
        .frame(width: canvasSize, height: canvasSize)
    }
}

private let macIconSizes: [(String, CGFloat)] = [
    ("app-icon-mac-16.png", 16),
    ("app-icon-mac-16@2x.png", 32),
    ("app-icon-mac-32.png", 32),
    ("app-icon-mac-32@2x.png", 64),
    ("app-icon-mac-128.png", 128),
    ("app-icon-mac-128@2x.png", 256),
    ("app-icon-mac-256.png", 256),
    ("app-icon-mac-256@2x.png", 512),
    ("app-icon-mac-512.png", 512),
    ("app-icon-mac-512@2x.png", 1024)
]

private let variants = [
    IconVariant(
        filename: "app-icon-ios-1024.png",
        palette: IconPalette(
            backgroundStart: Color(red: 0.08, green: 0.29, blue: 0.42),
            backgroundEnd: Color(red: 0.17, green: 0.63, blue: 0.72),
            orbPrimary: .white,
            orbSecondary: Color(red: 0.43, green: 0.87, blue: 0.96),
            symbol: Color(red: 0.98, green: 0.995, blue: 1.0)
        )
    ),
    IconVariant(
        filename: "app-icon-ios-dark-1024.png",
        palette: IconPalette(
            backgroundStart: Color(red: 0.04, green: 0.16, blue: 0.25),
            backgroundEnd: Color(red: 0.09, green: 0.38, blue: 0.47),
            orbPrimary: Color(red: 0.62, green: 0.86, blue: 0.94),
            orbSecondary: Color(red: 0.21, green: 0.56, blue: 0.64),
            symbol: .white
        )
    ),
    IconVariant(
        filename: "app-icon-ios-tinted-1024.png",
        palette: IconPalette(
            backgroundStart: Color(red: 0.06, green: 0.23, blue: 0.33),
            backgroundEnd: Color(red: 0.12, green: 0.46, blue: 0.56),
            orbPrimary: Color(red: 0.89, green: 0.97, blue: 1.0),
            orbSecondary: Color(red: 0.55, green: 0.84, blue: 0.9),
            symbol: .white
        )
    )
]

@MainActor
private func renderPNG(size: CGFloat, palette: IconPalette, outputURL: URL) throws {
    let renderer = ImageRenderer(
        content: AppIconArtwork(palette: palette, canvasSize: size)
    )
    renderer.proposedSize = ProposedViewSize(width: size, height: size)
    renderer.scale = 1

    guard let image = renderer.nsImage else {
        throw NSError(domain: "AppIconRenderer", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Failed to render icon artwork."
        ])
    }
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AppIconRenderer", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Failed to encode icon PNG."
        ])
    }

    try pngData.write(to: outputURL)
}

private func makeOutputDirectory(from arguments: [String]) -> URL {
    if arguments.count > 1 {
        return URL(fileURLWithPath: arguments[1], isDirectory: true)
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
}

@main
@MainActor
private struct AppIconGenerator {
    static func main() throws {
        let outputDirectory = makeOutputDirectory(from: CommandLine.arguments)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        for variant in variants {
            let outputURL = outputDirectory.appendingPathComponent(variant.filename)
            try renderPNG(size: 1024, palette: variant.palette, outputURL: outputURL)
        }

        guard let standardPalette = variants.first?.palette else {
            throw NSError(domain: "AppIconRenderer", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Missing standard icon palette."
            ])
        }

        for (filename, size) in macIconSizes {
            let outputURL = outputDirectory.appendingPathComponent(filename)
            try renderPNG(size: size, palette: standardPalette, outputURL: outputURL)
        }
    }
}
