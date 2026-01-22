import Cocoa
import Carbon

class ShortcutManager {
    static let shared = ShortcutManager()
    
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyID = EventHotKeyID(signature: OSType(0x4E4F5445), id: 1) // 'NOTE'
    
    var onShortcutPressed: (() -> Void)?
    
    private init() {}
    
    // MARK: - Public Methods
    
    func registerShortcut(_ shortcutString: String) {
        // Unregister existing shortcut first
        unregisterShortcut()
        
        // Parse shortcut string (e.g., "⌃⌥N")
        guard let (keyCode, modifiers) = parseShortcut(shortcutString) else {
            print("Failed to parse shortcut: \(shortcutString)")
            return
        }
        
        // Register the hotkey
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onShortcutPressed?()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            print("✅ Registered global shortcut: \(shortcutString)")
        } else {
            print("❌ Failed to register shortcut. Status: \(status)")
        }
    }
    
    func unregisterShortcut() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
            print("Unregistered global shortcut")
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    // MARK: - Private Methods
    
    private func parseShortcut(_ shortcut: String) -> (keyCode: Int, modifiers: Int)? {
        // Parse modifier symbols
        var modifiers = 0
        var keyChar = ""
        
        for char in shortcut {
            switch char {
            case "⌘": // Command
                modifiers |= cmdKey
            case "⌥": // Option
                modifiers |= optionKey
            case "⌃": // Control
                modifiers |= controlKey
            case "⇧": // Shift
                modifiers |= shiftKey
            default:
                keyChar.append(char)
            }
        }
        
        // Get key code for the character
        guard let keyCode = getKeyCode(for: keyChar.uppercased()) else {
            return nil
        }
        
        return (keyCode, modifiers)
    }
    
    private func getKeyCode(for character: String) -> Int? {
        // Map characters to key codes
        let keyCodeMap: [String: Int] = [
            "A": 0, "B": 11, "C": 8, "D": 2, "E": 14, "F": 3, "G": 5, "H": 4,
            "I": 34, "J": 38, "K": 40, "L": 37, "M": 46, "N": 45, "O": 31,
            "P": 35, "Q": 12, "R": 15, "S": 1, "T": 17, "U": 32, "V": 9,
            "W": 13, "X": 7, "Y": 16, "Z": 6,
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
            "6": 22, "7": 26, "8": 28, "9": 25,
            " ": 49, // Space
            "RETURN": 36, "ENTER": 76, "DELETE": 51, "ESCAPE": 53,
            "TAB": 48, "F1": 122, "F2": 120, "F3": 99, "F4": 118,
            "F5": 96, "F6": 97, "F7": 98, "F8": 100, "F9": 101,
            "F10": 109, "F11": 103, "F12": 111
        ]
        
        return keyCodeMap[character]
    }
}
