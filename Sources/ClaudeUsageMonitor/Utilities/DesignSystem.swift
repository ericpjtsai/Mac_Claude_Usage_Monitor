import SwiftUI

// MARK: - Design System
// Modeled after macOS native Weather app: compact, readable, even spacing

enum DS {

    // MARK: - Typography (matched to Weather app sizing)

    enum Font {
        // Header: "Claude Usage Monitor" — matches "Shoreline" in Weather
        static let h1 = SwiftUI.Font.system(size: 16, weight: .semibold)

        // Subheader: plan/email line
        static let h2 = SwiftUI.Font.system(size: 13, weight: .medium)

        // Body text: row labels like "Session (5h)" — matches "Seattle", "Berkeley"
        static let body = SwiftUI.Font.system(size: 14, weight: .regular)

        // Values: "32%" — matches "5°", "15°"
        static let value = SwiftUI.Font.system(size: 14, weight: .semibold, design: .monospaced)

        // Gauge center number — matches "4°" hero temp
        static let gauge = SwiftUI.Font.system(size: 36, weight: .bold, design: .rounded)

        // Gauge sub-labels: "Used", "Resets in..."
        static let gaugeSub = SwiftUI.Font.system(size: 12, weight: .medium)

        // Footer: "Updated just now", buttons — matches "Open Weather"
        static let footer = SwiftUI.Font.system(size: 13, weight: .regular)

        // Small meta text
        static let caption = SwiftUI.Font.system(size: 11, weight: .regular)

        // Buttons
        static let button = SwiftUI.Font.system(size: 13, weight: .medium)

        // Error
        static let error = SwiftUI.Font.system(size: 12, weight: .regular)
    }

    // MARK: - Colors

    enum Color {
        static let foreground = SwiftUI.Color.primary
        static let secondary = SwiftUI.Color.secondary
        static let muted = SwiftUI.Color.secondary.opacity(0.5)
        static let destructive = SwiftUI.Color(red: 0.94, green: 0.27, blue: 0.27)
        static let accent = SwiftUI.Color.blue
        static let border = SwiftUI.Color.primary.opacity(0.1)

        static func usage(_ pct: Double) -> SwiftUI.Color {
            switch pct {
            case ..<50:  return SwiftUI.Color(red: 0.22, green: 0.78, blue: 0.45)
            case ..<75:  return SwiftUI.Color(red: 0.96, green: 0.65, blue: 0.14)
            default:     return SwiftUI.Color(red: 0.94, green: 0.27, blue: 0.27)
            }
        }
    }

    // MARK: - Spacing

    enum Space {
        static let _1: CGFloat = 4
        static let _2: CGFloat = 8
        static let _3: CGFloat = 12
        static let _4: CGFloat = 16
        static let _5: CGFloat = 20
        static let _6: CGFloat = 24
    }
}
