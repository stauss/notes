import SwiftUI
import AppKit

class PreferencesViewModel: ObservableObject {
    @Published var settings: AppSettings
    @Published var iconColor: Color
    @Published var badgeColor: Color
    
    weak var menuBarManager: MenuBarManager?
    
    init() {
        let loadedSettings = AppSettings.load()
        self.settings = loadedSettings
        self.iconColor = Color(hex: loadedSettings.iconColor) ?? .black
        self.badgeColor = Color(hex: loadedSettings.badgeColor) ?? .blue
        
        // Sync launch at login state
        syncLaunchAtLogin()
    }
    
    private func syncLaunchAtLogin() {
        // Sync the toggle with actual launch at login status
        let actualStatus = LaunchAtLoginManager.shared.isEnabled
        if settings.launchAtLogin != actualStatus {
            settings.launchAtLogin = actualStatus
        }
    }
    
    func saveSettings() {
        // Update launch at login if it changed
        LaunchAtLoginManager.shared.isEnabled = settings.launchAtLogin
        
        settings.save()
        
        // Re-register global shortcut if it changed
        ShortcutManager.shared.registerShortcut(settings.globalShortcut)
    }
    
    func resetToDefaults() {
        settings.reset()
        iconColor = Color(hex: settings.iconColor) ?? .black
        badgeColor = Color(hex: settings.badgeColor) ?? .blue
        
        // Update menu bar icon
        if let nsColor = NSColor(iconColor) {
            menuBarManager?.updateIconColor(nsColor)
        }
    }
    
    func updateIconColor(_ color: Color) {
        settings.iconColor = color.toHex() ?? "#000000"
        saveSettings()
        
        // Update menu bar icon color
        if let nsColor = NSColor(color) {
            menuBarManager?.updateIconColor(nsColor)
        }
    }
    
    func updateBadgeColor(_ color: Color) {
        settings.badgeColor = color.toHex() ?? "#007AFF"
        saveSettings()
    }
}

// MARK: - Color Extensions

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String? {
        guard let components = NSColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}

extension NSColor {
    convenience init?(_ color: Color) {
        guard let cgColor = color.cgColor else { return nil }
        self.init(cgColor: cgColor)
    }
}
