import AppKit
import Carbon
import Foundation

struct HotKeyConfiguration: Codable, Equatable {
    let keyCode: UInt16
    let modifierFlags: UInt64

    static let storageKey = "clipboardHotkeyConfig"
    static let relevantMask: UInt64 =
        CGEventFlags.maskCommand.rawValue |
        CGEventFlags.maskAlternate.rawValue |
        CGEventFlags.maskShift.rawValue |
        CGEventFlags.maskControl.rawValue |
        CGEventFlags.maskSecondaryFn.rawValue

    static let `default` = HotKeyConfiguration(
        keyCode: UInt16(kVK_ANSI_V),
        modifierFlags: CGEventFlags.maskSecondaryFn.rawValue
    )

    static func load() -> HotKeyConfiguration {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let config = try? JSONDecoder().decode(HotKeyConfiguration.self, from: data) else {
            return .default
        }
        return config
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    func displayString() -> String {
        var parts: [String] = []
        let flags = CGEventFlags(rawValue: modifierFlags)
        if flags.contains(.maskControl) { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift) { parts.append("⇧") }
        if flags.contains(.maskCommand) { parts.append("⌘") }
        if flags.contains(.maskSecondaryFn) { parts.append("fn") }
        parts.append(keyCodeDisplay(keyCode))
        return parts.joined(separator: " ")
    }

    private func keyCodeDisplay(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        default: return "Key\(keyCode)"
        }
    }
}

func hotKeyConfiguration(from event: NSEvent) -> HotKeyConfiguration {
    var flags = CGEventFlags()
    if event.modifierFlags.contains(.control) { flags.insert(.maskControl) }
    if event.modifierFlags.contains(.option) { flags.insert(.maskAlternate) }
    if event.modifierFlags.contains(.shift) { flags.insert(.maskShift) }
    if event.modifierFlags.contains(.command) { flags.insert(.maskCommand) }
    if event.modifierFlags.contains(.function) { flags.insert(.maskSecondaryFn) }

    return HotKeyConfiguration(keyCode: event.keyCode, modifierFlags: flags.rawValue)
}
