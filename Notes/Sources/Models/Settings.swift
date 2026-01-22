import Foundation

struct AppSettings: Codable {
    var globalShortcut: String
    var iconColor: String // Hex color
    var badgeColor: String // Hex color
    var launchAtLogin: Bool
    var duplicateNoteWithFile: Bool
    
    static let defaults = AppSettings(
        globalShortcut: "⌃⌥N",
        iconColor: "#000000",
        badgeColor: "#007AFF",
        launchAtLogin: false,
        duplicateNoteWithFile: false
    )
    
    // UserDefaults keys
    private enum Keys {
        static let globalShortcut = "globalShortcut"
        static let iconColor = "iconColor"
        static let badgeColor = "badgeColor"
        static let launchAtLogin = "launchAtLogin"
        static let duplicateNoteWithFile = "duplicateNoteWithFile"
    }
    
    // Save to UserDefaults
    func save() {
        let defaults = UserDefaults.standard
        defaults.set(globalShortcut, forKey: Keys.globalShortcut)
        defaults.set(iconColor, forKey: Keys.iconColor)
        defaults.set(badgeColor, forKey: Keys.badgeColor)
        defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        defaults.set(duplicateNoteWithFile, forKey: Keys.duplicateNoteWithFile)
    }
    
    // Load from UserDefaults
    static func load() -> AppSettings {
        let defaults = UserDefaults.standard
        return AppSettings(
            globalShortcut: defaults.string(forKey: Keys.globalShortcut) ?? AppSettings.defaults.globalShortcut,
            iconColor: defaults.string(forKey: Keys.iconColor) ?? AppSettings.defaults.iconColor,
            badgeColor: defaults.string(forKey: Keys.badgeColor) ?? AppSettings.defaults.badgeColor,
            launchAtLogin: defaults.bool(forKey: Keys.launchAtLogin),
            duplicateNoteWithFile: defaults.bool(forKey: Keys.duplicateNoteWithFile)
        )
    }
    
    // Reset to defaults
    mutating func reset() {
        self = AppSettings.defaults
        save()
    }
}
