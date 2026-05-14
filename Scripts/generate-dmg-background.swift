import AppKit
import Foundation

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 960, height: 520)
let image = NSImage(size: size)

extension NSBezierPath {
    convenience init(roundedRect rect: NSRect, radius: CGFloat) {
        self.init(roundedRect: rect, xRadius: radius, yRadius: radius)
    }
}

func drawCentered(_ text: String, in rect: NSRect, attributes: [NSAttributedString.Key: Any]) {
    text.draw(in: rect, withAttributes: attributes)
}

image.lockFocus()

let bounds = NSRect(origin: .zero, size: size)

let base = NSGradient(colors: [
    NSColor(calibratedRed: 0.985, green: 0.985, blue: 0.99, alpha: 1),
    NSColor(calibratedRed: 0.925, green: 0.935, blue: 0.955, alpha: 1)
])
base?.draw(in: bounds, angle: 90)

let panelRect = NSRect(x: 64, y: 72, width: 832, height: 360)
let panel = NSBezierPath(roundedRect: panelRect, radius: 32)
NSColor(calibratedWhite: 1, alpha: 0.72).setFill()
panel.fill()
NSColor(calibratedWhite: 1, alpha: 0.9).setStroke()
panel.lineWidth = 1.5
panel.stroke()

let titleStyle = NSMutableParagraphStyle()
titleStyle.alignment = .center

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 28, weight: .bold),
    .foregroundColor: NSColor(calibratedRed: 0.09, green: 0.1, blue: 0.12, alpha: 1),
    .paragraphStyle: titleStyle
]

let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14, weight: .regular),
    .foregroundColor: NSColor(calibratedRed: 0.36, green: 0.39, blue: 0.44, alpha: 1),
    .paragraphStyle: titleStyle
]

drawCentered(
    "Install YTClipper",
    in: NSRect(x: 160, y: 382, width: 640, height: 36),
    attributes: titleAttributes
)

drawCentered(
    "Drag the app into Applications, then open it from there.",
    in: NSRect(x: 160, y: 356, width: 640, height: 22),
    attributes: subtitleAttributes
)

let arrowColor = NSColor(calibratedRed: 1, green: 0.16, blue: 0.25, alpha: 0.95)
arrowColor.setStroke()

let arrowPath = NSBezierPath()
arrowPath.lineWidth = 9
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowPath.move(to: NSPoint(x: 416, y: 238))
arrowPath.line(to: NSPoint(x: 544, y: 238))
arrowPath.stroke()

let arrowHead = NSBezierPath()
arrowHead.lineWidth = 9
arrowHead.lineCapStyle = .round
arrowHead.lineJoinStyle = .round
arrowHead.move(to: NSPoint(x: 514, y: 268))
arrowHead.line(to: NSPoint(x: 544, y: 238))
arrowHead.line(to: NSPoint(x: 514, y: 208))
arrowHead.stroke()

let appLabelAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
    .foregroundColor: NSColor(calibratedRed: 0.22, green: 0.24, blue: 0.28, alpha: 1),
    .paragraphStyle: titleStyle
]

drawCentered(
    "YTClipper",
    in: NSRect(x: 194, y: 116, width: 180, height: 20),
    attributes: appLabelAttributes
)

drawCentered(
    "Applications",
    in: NSRect(x: 586, y: 116, width: 180, height: 20),
    attributes: appLabelAttributes
)

let noteAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11, weight: .medium),
    .foregroundColor: NSColor(calibratedRed: 0.48, green: 0.5, blue: 0.55, alpha: 1),
    .paragraphStyle: titleStyle
]

drawCentered(
    "Use only with YT content you own or have permission to archive.",
    in: NSRect(x: 160, y: 36, width: 640, height: 18),
    attributes: noteAttributes
)

image.unlockFocus()

guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Could not render DMG background.\n", stderr)
    exit(1)
}

try pngData.write(to: outputURL)
