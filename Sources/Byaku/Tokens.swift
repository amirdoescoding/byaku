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

    /// Onboarding (docs/designs/onboarding.md, prototype design/onboarding/motion.html). Springs are CASpringAnimation (mass 1).
    enum Onboarding {
        struct Spring { let stiffness: CGFloat, damping: CGFloat }
        static let raise = Spring(stiffness: 380, damping: 22), frown = Spring(stiffness: 220, damping: 28)
        static let focus = Spring(stiffness: 260, damping: 30), look = Spring(stiffness: 300, damping: 26)
        static let neutral = Spring(stiffness: 300, damping: 26), snap = Spring(stiffness: 6000, damping: 155)
        static let fly = Spring(stiffness: 340, damping: 32), flyY = Spring(stiffness: 260, damping: 28)
        static let flyScale = Spring(stiffness: 380, damping: 36), follow = Spring(stiffness: 300, damping: 30)
        /// Blink: one keyframe this long; idle blinks every blinkEvery…+blinkJitter s.
        static let blinkTime = 0.2, blinkEvery = 2.0, blinkJitter = 1.5
        /// Stressed (tour, no hover): a pose every stressStep s, stressSteps times, then a frown.
        static let stressStep = 0.15, stressSteps = 8
        /// Intro (seconds from start): ring draws, blades wake (fade), blink, wordmark rises, hold, then the mark flies to the corner.
        static let ringDraw = 0.52, bladesAt = 0.18, bladesFade = 0.16, blinkAt = 0.64, wordAt = 0.56, wordRise = 0.32
        static let hold = 1.5, wordOut = 0.15, frameIn = 0.32, frameDelay = 0.06
        /// Outro (seconds from the video's end): scrim settles, the mark returns, smiles, the thanks card arrives.
        static let scrim = 0.36, scrimAlpha: CGFloat = 0.92, backAt = 0.12, smileAt = 0.52, smileHold = 0.74
        static let thanksAt = 0.64, buttonStagger = 0.06, textRise = 0.26
        /// Tour: the menu opens this long after the flight starts; the bubble sits this far left of the menu.
        static let menuAfter = 0.25, bubbleGap: CGFloat = 14, locate = 0.05
        /// Tour: seconds without a hover before the mascot gets stressed.
        static let impatient = 6.0
        /// Tour: if no menu has opened this long after opening it, end onboarding rather than hang invisible.
        static let menuCheck = 1.0
        /// Synthesised sounds (Sfx): peak level 0…1 and lengths.
        static let whooshLevel: Float = 0.22, flickLevel: Float = 0.16, whoosh = 0.42, flick = 0.07
        /// Mark colour change (accent ↔ ink at the video's corner) and the window fade while the tour is on the menu.
        static let recolor = 0.3, windowFade = 0.15, idleAfter = 1.2
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
