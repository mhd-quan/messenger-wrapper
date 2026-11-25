import Foundation

/// A global hot key: one key plus at least one modifier, parsed from the
/// `hotkey` user default, e.g. `"ctrl+opt+m"`.
public struct HotKeySpec: Equatable {
    public struct Modifiers: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)
    }

    /// The virtual key code, as in Carbon's `Events.h` (`kVK_ANSI_M` is 46).
    public let keyCode: UInt32
    public let modifiers: Modifiers

    /// ⌃⌥M.
    public static let `default` = HotKeySpec(keyCode: 46, modifiers: [.control, .option])

    public enum Parsed: Equatable {
        case spec(HotKeySpec)
        /// The string was `"none"`: no hot key.
        case disabled
        case invalid
    }

    /// Parses `+`-separated parts, ignoring case and whitespace: modifiers
    /// `ctrl`/`control`, `opt`/`option`/`alt`, `shift`, `cmd`/`command`, and
    /// exactly one key, `a`–`z`, `0`–`9` or `space`. At least one modifier is
    /// required. `"none"` disables the hot key.
    public static func parse(_ string: String) -> Parsed {
        let normalized = string.filter { !$0.isWhitespace }.lowercased()
        if normalized == "none" {
            return .disabled
        }
        var keyCode: UInt32?
        var modifiers: Modifiers = []
        for part in normalized.split(separator: "+", omittingEmptySubsequences: false) {
            if let modifier = modifierNames[String(part)] {
                modifiers.insert(modifier)
            } else if let code = keyCodes[String(part)], keyCode == nil {
                keyCode = code
            } else {
                // Empty, unknown, or a second key.
                return .invalid
            }
        }
        guard let keyCode, !modifiers.isEmpty else {
            return .invalid
        }
        return .spec(HotKeySpec(keyCode: keyCode, modifiers: modifiers))
    }

    private static let modifierNames: [String: Modifiers] = [
        "ctrl": .control, "control": .control,
        "opt": .option, "option": .option, "alt": .option,
        "shift": .shift,
        "cmd": .command, "command": .command,
    ]

    /// ANSI virtual key codes (`kVK_ANSI_*`, `kVK_Space`) from Carbon's
    /// `Events.h`, which Core cannot import. They follow the physical key
    /// positions, hence the irregular order.
    private static let keyCodes: [String: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35, "l": 37,
        "j": 38, "k": 40, "n": 45, "m": 46,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25,
        "7": 26, "8": 28, "0": 29,
        "space": 49,
    ]
}
