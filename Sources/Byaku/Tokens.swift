import AppKit

/// The only place colours and animation timings are written down (scripts/check-ui.sh enforces it).
/// Roles, not hues: see design/brand/palette.md and docs/designs/menubar.md §4–5.
enum Tokens {
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x17161C)
    static let line = dynamic(light: 0xE1E0E6, dark: 0x25232C)
    static let ink = dynamic(light: 0x0E0D12, dark: 0xECEBF0)
    static let bg = dynamic(light: 0xF5F5F7, dark: 0x0E0D12)
    static let mute = dynamic(light: 0x66636F, dark: 0x8F8C99)
    /// Violet means *seen*: the eye is open (guarding, alert) and keyboard focus. Never decoration.
    static let accent = dynamic(light: 0x6A5DB8, dark: 0xC8BFEF)

    enum Motion {
        static let enter = 0.20, exit = 0.15, hover = 0.12, press = 0.10, release = 0.16, check = 0.24
        static let spinTurn = 0.6, countStep = 1.0, autoClose = 3.0, startTimeout = 4.0
        static let pressScale: CGFloat = 0.97, enterScale: CGFloat = 0.96
        /// Strong ease-out. No ease-in anywhere: feedback must start fast.
        static var easeOut: CAMediaTimingFunction { CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1) }
        static var reduced: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> NSColor {
        NSColor(name: nil) { a in
            let v = a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat(v >> 16 & 0xFF) / 255, green: CGFloat(v >> 8 & 0xFF) / 255,
                           blue: CGFloat(v & 0xFF) / 255, alpha: 1)
        }
    }
}
