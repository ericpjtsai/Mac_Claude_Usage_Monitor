import AppKit

enum MenuBarIconRenderer {

    /// Renders a menu bar icon: circular progress ring + percentage text
    /// Uses template rendering so macOS handles light/dark automatically (all black/white)
    /// Font size matches the Weather app's menu bar style (~12pt medium)
    static func render(percentage: Double?) -> NSImage {
        let height: CGFloat = 18
        let ringSize: CGFloat = 13
        let padding: CGFloat = 2.5

        let pctText = percentage.map { "\(Int($0))%" } ?? "--%"
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black  // template mode will tint this
        ]
        let textSize = (pctText as NSString).size(withAttributes: attrs)

        let totalWidth = ringSize + padding + textSize.width
        let size = NSSize(width: totalWidth, height: height)

        let image = NSImage(size: size, flipped: false) { rect in
            // Vertically center both ring and text on the same baseline
            let midY = rect.midY
            let ringCenter = CGPoint(x: ringSize / 2, y: midY)
            let radius = (ringSize - 2) / 2
            let lineWidth: CGFloat = 1.8

            // Background track
            let trackPath = NSBezierPath()
            trackPath.appendArc(
                withCenter: ringCenter,
                radius: radius,
                startAngle: 0,
                endAngle: 360
            )
            NSColor.black.withAlphaComponent(0.3).setStroke()
            trackPath.lineWidth = lineWidth
            trackPath.stroke()

            // Progress arc
            if let pct = percentage, pct > 0 {
                let startAngle: CGFloat = 90
                let endAngle = 90 - (pct / 100.0 * 360)
                let progressPath = NSBezierPath()
                progressPath.appendArc(
                    withCenter: ringCenter,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: true
                )
                NSColor.black.setStroke()
                progressPath.lineWidth = lineWidth
                progressPath.lineCapStyle = .round
                progressPath.stroke()
            }

            // Percentage text — vertically centered to match ring
            let textY = midY - textSize.height / 2
            let textOrigin = CGPoint(
                x: ringSize + padding,
                y: textY
            )
            (pctText as NSString).draw(at: textOrigin, withAttributes: attrs)

            return true
        }

        // Template mode: macOS tints the image to match menu bar (black in light, white in dark)
        image.isTemplate = true
        return image
    }
}
