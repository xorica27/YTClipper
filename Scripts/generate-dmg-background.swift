import AppKit
import Foundation

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 680, height: 420)
let image = NSImage(size: size)

image.lockFocus()

let bounds = NSRect(origin: .zero, size: size)
let background = NSGradient(colors: [
    NSColor(calibratedWhite: 0.96, alpha: 1),
    NSColor(calibratedWhite: 0.9, alpha: 1)
])
background?.draw(in: bounds, angle: 90)

let titleStyle = NSMutableParagraphStyle()
titleStyle.alignment = .center

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
    .foregroundColor: NSColor.labelColor,
    .paragraphStyle: titleStyle
]

let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .regular),
    .foregroundColor: NSColor.secondaryLabelColor,
    .paragraphStyle: titleStyle
]

"Drag YTClipper to Applications".draw(
    in: NSRect(x: 70, y: 330, width: 540, height: 32),
    withAttributes: titleAttributes
)

"Then open it from your Applications folder.".draw(
    in: NSRect(x: 70, y: 306, width: 540, height: 22),
    withAttributes: subtitleAttributes
)

let arrowColor = NSColor(calibratedRed: 1, green: 0.13, blue: 0.24, alpha: 0.9)
arrowColor.setStroke()

let arrowPath = NSBezierPath()
arrowPath.lineWidth = 8
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowPath.move(to: NSPoint(x: 292, y: 210))
arrowPath.line(to: NSPoint(x: 388, y: 210))
arrowPath.stroke()

let arrowHead = NSBezierPath()
arrowHead.lineWidth = 8
arrowHead.lineCapStyle = .round
arrowHead.lineJoinStyle = .round
arrowHead.move(to: NSPoint(x: 366, y: 232))
arrowHead.line(to: NSPoint(x: 388, y: 210))
arrowHead.line(to: NSPoint(x: 366, y: 188))
arrowHead.stroke()

let noteAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11, weight: .medium),
    .foregroundColor: NSColor.tertiaryLabelColor,
    .paragraphStyle: titleStyle
]

"Use only with YT content you own or have permission to archive.".draw(
    in: NSRect(x: 70, y: 44, width: 540, height: 18),
    withAttributes: noteAttributes
)

image.unlockFocus()

guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Could not render DMG background.\n", stderr)
    exit(1)
}

try pngData.write(to: outputURL)
