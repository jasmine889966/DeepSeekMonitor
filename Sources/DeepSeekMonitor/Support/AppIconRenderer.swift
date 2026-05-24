import AppKit
import Foundation

enum AppIconTone {
    case muted
    case normal
    case warning
    case danger
}

enum AppIconRenderer {
    static func baseImage() -> NSImage {
        if let url = Bundle.module.url(forResource: "deepseek", withExtension: "svg"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSImage(named: NSImage.applicationIconName) ?? NSImage(size: NSSize(width: 1024, height: 1024))
    }

    static func image(tone: AppIconTone, size: CGFloat = 1024) -> NSImage {
        let color: NSColor
        switch tone {
        case .muted:
            color = .tertiaryLabelColor
        case .normal:
            color = .systemBlue
        case .warning:
            color = .systemOrange
        case .danger:
            color = .systemRed
        }
        return tinted(base: baseImage(), color: color, size: NSSize(width: size, height: size))
    }

    static func tinted(base: NSImage, color: NSColor, size: NSSize) -> NSImage {
        let target = NSImage(size: size)
        target.lockFocus()
        defer { target.unlockFocus() }

        let rect = NSRect(origin: .zero, size: size)
        color.setFill()
        rect.fill()
        base.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1.0)
        return target
    }
}
