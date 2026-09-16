// Generates the 1024x1024 app icon by compositing a subject photo (transparent
// background) onto a rounded-square backdrop, matching macOS icon conventions.
// Run with: swift Scripts/generate-icon.swift [path/to/subject.png]

import AppKit

let canvasSize: CGFloat = 1024
let args = CommandLine.arguments
let subjectPath = args.count > 1 ? args[1] : nil

let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no context") }

let rect = CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
let corner: CGFloat = canvasSize * 0.225
let bgPath = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)
bgPath.addClip()

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.16, green: 0.32, blue: 0.55, alpha: 1),
    NSColor(calibratedRed: 0.06, green: 0.10, blue: 0.20, alpha: 1),
])
gradient?.draw(in: rect, angle: -90)

if let subjectPath, let subject = NSImage(contentsOfFile: subjectPath),
   let cgSubject = subject.cgImage(forProposedRect: nil, context: nil, hints: nil) {
    // Crop a square from the top of the source (head + shoulders) since the
    // source is a tall full-body cutout. CGImage crop space has origin top-left.
    let w = CGFloat(cgSubject.width)
    let h = CGFloat(cgSubject.height)
    let cropSide = min(w, h)
    let cropRect = CGRect(x: (w - cropSide) / 2, y: 0, width: cropSide, height: cropSide)

    // Fill most of the canvas, centered, with a soft shadow behind the subject.
    let margin = canvasSize * 0.04
    let destRect = rect.insetBy(dx: margin, dy: margin)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 28, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    if let cropped = cgSubject.cropping(to: cropRect) {
        ctx.draw(cropped, in: destRect)
    }
    ctx.restoreGState()
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not render icon")
}

let outDir = URL(fileURLWithPath: "AppIcon")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let outURL = outDir.appendingPathComponent("icon_1024.png")
try png.write(to: outURL)
print("Wrote \(outURL.path)")
