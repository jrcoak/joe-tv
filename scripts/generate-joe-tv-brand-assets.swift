#!/usr/bin/env swift

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

private enum Layer: String, CaseIterable {
    case background
    case middle
    case foreground
}

private let outputRoot: URL = {
    guard CommandLine.arguments.count == 2 else {
        fputs("usage: generate-joe-tv-brand-assets.swift <AppIcon.brandassets>\n", stderr)
        exit(64)
    }
    return URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
}()

private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
private let dark = CGColor(red: 0.031, green: 0.039, blue: 0.051, alpha: 1)
private let raised = CGColor(red: 0.086, green: 0.106, blue: 0.129, alpha: 1)
private let paper = CGColor(red: 0.957, green: 0.949, blue: 0.929, alpha: 1)
private let signal = CGColor(red: 1.0, green: 0.357, blue: 0.208, alpha: 1)

private func makeContext(width: Int, height: Int) -> CGContext {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.interpolationQuality = .high
    return context
}

private func save(_ image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw NSError(domain: "JoeTVBrandAssets", code: 1)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "JoeTVBrandAssets", code: 2)
    }
}

private func drawBackground(in context: CGContext, width: CGFloat, height: CGFloat) {
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [raised, dark] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: height),
        end: CGPoint(x: width, y: 0),
        options: []
    )

    context.setStrokeColor(paper.copy(alpha: 0.08)!)
    context.setLineWidth(max(1, height * 0.004))
    let inset = height * 0.045
    context.addPath(CGPath(
        roundedRect: CGRect(x: inset, y: inset, width: width - inset * 2, height: height - inset * 2),
        cornerWidth: height * 0.09,
        cornerHeight: height * 0.09,
        transform: nil
    ))
    context.strokePath()
}

private func drawMiddle(in context: CGContext, width: CGFloat, height: CGFloat) {
    let center = CGPoint(x: width / 2, y: height / 2)
    let markSize = height * 0.68
    let capsuleWidth = markSize * 0.15
    let capsuleHeight = markSize * 0.31
    let offset = markSize * 0.18
    let colors = [
        signal,
        paper.copy(alpha: 0.42)!,
        paper.copy(alpha: 0.54)!,
        paper.copy(alpha: 0.66)!,
    ]

    for index in 0..<4 {
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: CGFloat(index) * .pi / 2)
        let rect = CGRect(
            x: -capsuleWidth / 2,
            y: offset,
            width: capsuleWidth,
            height: capsuleHeight
        )
        context.setFillColor(colors[index])
        context.addPath(CGPath(
            roundedRect: rect,
            cornerWidth: capsuleWidth / 2,
            cornerHeight: capsuleWidth / 2,
            transform: nil
        ))
        context.fillPath()
        context.restoreGState()
    }
}

private func drawForeground(in context: CGContext, width: CGFloat, height: CGFloat) {
    let center = CGPoint(x: width / 2, y: height / 2)
    let markSize = height * 0.68
    let screen = CGRect(
        x: center.x - markSize * 0.175,
        y: center.y - markSize * 0.135,
        width: markSize * 0.35,
        height: markSize * 0.27
    )
    context.setFillColor(dark)
    context.addPath(CGPath(
        roundedRect: screen,
        cornerWidth: markSize * 0.08,
        cornerHeight: markSize * 0.08,
        transform: nil
    ))
    context.fillPath()

    let triangleSize = markSize * 0.12
    let triangleCenter = CGPoint(x: center.x + markSize * 0.01, y: center.y)
    context.beginPath()
    context.move(to: CGPoint(x: triangleCenter.x - triangleSize * 0.34, y: triangleCenter.y - triangleSize * 0.50))
    context.addLine(to: CGPoint(x: triangleCenter.x - triangleSize * 0.34, y: triangleCenter.y + triangleSize * 0.50))
    context.addLine(to: CGPoint(x: triangleCenter.x + triangleSize * 0.55, y: triangleCenter.y))
    context.closePath()
    context.setFillColor(signal)
    context.fillPath()
}

private func renderLayer(_ layer: Layer, width: Int, height: Int) -> CGImage {
    let context = makeContext(width: width, height: height)
    let w = CGFloat(width)
    let h = CGFloat(height)
    switch layer {
    case .background: drawBackground(in: context, width: w, height: h)
    case .middle: drawMiddle(in: context, width: w, height: h)
    case .foreground: drawForeground(in: context, width: w, height: h)
    }
    return context.makeImage()!
}

private func drawWordmark(in context: CGContext, width: CGFloat, height: CGFloat) {
    let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, height * 0.17, nil)
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): paper,
        NSAttributedString.Key(kCTKernAttributeName as String): height * 0.018,
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "JOE-TV", attributes: attributes))
    let bounds = CTLineGetBoundsWithOptions(line, [.useOpticalBounds])
    context.textPosition = CGPoint(x: width * 0.54, y: (height - bounds.height) / 2 - bounds.minY)
    CTLineDraw(line, context)
}

private func renderTopShelf(width: Int, height: Int) -> CGImage {
    let context = makeContext(width: width, height: height)
    let w = CGFloat(width)
    let h = CGFloat(height)
    drawBackground(in: context, width: w, height: h)

    context.saveGState()
    context.translateBy(x: -w * 0.23, y: 0)
    drawMiddle(in: context, width: w, height: h)
    drawForeground(in: context, width: w, height: h)
    context.restoreGState()
    drawWordmark(in: context, width: w, height: h)
    return context.makeImage()!
}

private func renderIconPreview(width: Int, height: Int) -> CGImage {
    let context = makeContext(width: width, height: height)
    let w = CGFloat(width)
    let h = CGFloat(height)
    drawBackground(in: context, width: w, height: h)
    drawMiddle(in: context, width: w, height: h)
    drawForeground(in: context, width: w, height: h)
    return context.makeImage()!
}

private func writeStack(named name: String, sizes: [(suffix: String, width: Int, height: Int)]) throws {
    for layer in Layer.allCases {
        for size in sizes {
            let filename = "\(layer.rawValue)\(size.suffix).png"
            let url = outputRoot
                .appendingPathComponent("\(name).imagestack", isDirectory: true)
                .appendingPathComponent("\(layer.rawValue.capitalized).imagestacklayer", isDirectory: true)
                .appendingPathComponent("Content.imageset", isDirectory: true)
                .appendingPathComponent(filename)
            try save(renderLayer(layer, width: size.width, height: size.height), to: url)
        }
    }
}

try writeStack(named: "App Icon - Small", sizes: [
    (suffix: "", width: 400, height: 240),
    (suffix: "@2x", width: 800, height: 480),
])
try writeStack(named: "App Icon - Large", sizes: [
    (suffix: "", width: 1280, height: 768),
])

for shelf in [
    (folder: "Top Shelf Image.imageset", filename: "top-shelf.png", width: 1920, height: 720),
    (folder: "Top Shelf Image.imageset", filename: "top-shelf@2x.png", width: 3840, height: 1440),
    (folder: "Top Shelf Image Wide.imageset", filename: "top-shelf-wide.png", width: 2320, height: 720),
    (folder: "Top Shelf Image Wide.imageset", filename: "top-shelf-wide@2x.png", width: 4640, height: 1440),
] {
    try save(
        renderTopShelf(width: shelf.width, height: shelf.height),
        to: outputRoot.appendingPathComponent(shelf.folder, isDirectory: true).appendingPathComponent(shelf.filename)
    )
}

try save(
    renderIconPreview(width: 800, height: 480),
    to: FileManager.default.temporaryDirectory.appendingPathComponent("joe-tv-app-icon-preview.png")
)
