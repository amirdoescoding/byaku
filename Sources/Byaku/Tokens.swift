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

    /// Guard overlay (docs/designs/guard-actions.md §4). Iris is the one sanctioned violet gradient: `accent` strips fading in from every edge.
    enum Overlay {
        static let dimAlpha: CGFloat = 0.40, edgeAlpha: Float = 0.70
        /// Iris mist depth = × screen width in pt (96 pt on a 1920 pt display, 72 on a 1440 pt laptop).
        static let edgeDepth: CGFloat = 0.05
        /// Mist falloff from the edge inward (location 0 = edge, 1 = inner side): eased so it reads as mist, not a band.
        static let mist: [(at: CGFloat, alpha: CGFloat)] = [(0, 1), (0.2, 0.62), (0.45, 0.3), (0.7, 0.1), (1, 0)]
    }

    /// Away (docs/designs/away-mode.md). Not motion: arming countdown, the camera-stall limit, the pause between message repeats, recording.
    enum Away {
        static let armSeconds = 5, stallLimit = 10.0, watchdog = 5.0, messageGap = 1.0, lockCheck = 1.0
        /// A sound picked in the Alarm sound menu plays this long at the slider level (iPhone alarm picker style).
        static let pickSeconds = 1.5
        /// Tone level under the message (mixer gain, 0…1): they play together, and speech is far quieter than the clipped
        /// siren at the same output volume. Set by ear on hardware. Recording cap, and the shortest take that counts as a message.
        static let toneGain: Float = 0.45, messageSeconds = 8.0, minMessageSeconds = 0.5
        /// Extra trim on the siren only (× toneGain): by ear it was louder than the message where the system sounds weren't.
        static let sirenTrim: Float = 0.25
        /// With VoiceOver on, the mic starts after "Recording, speak now" has been said, so it isn't in the take.
        static let voiceOverLead = 2.5
        /// Alarm volume slider (Control Center Sound style): floor so the alarm is never silent; default full.
        static let minVolume: Float = 0.25
        static let sliderTrack = NSColor.labelColor.withAlphaComponent(0.16)
        static let knobShadow = NSColor.black.withAlphaComponent(0.3)
        static let knobGlyph = NSColor.black.withAlphaComponent(0.85)
    }

    enum Motion {
        static let enter = 0.20, exit = 0.15, hover = 0.12, press = 0.10, release = 0.16, check = 0.24
        static let edgeIn = 0.28, spinTurn = 0.6, countStep = 1.0, autoClose = 3.0, startTimeout = 4.0
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
