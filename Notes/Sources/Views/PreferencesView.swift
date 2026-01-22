import SwiftUI
import AppKit

struct PreferencesView: View {
    @StateObject private var viewModel = PreferencesViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            VStack(spacing: 20) {
                // Keyboard Shortcut row
                preferenceRow(
                    label: "Keyboard Shortcut",
                    control: {
                        ShortcutRecorderView(shortcut: $viewModel.settings.globalShortcut)
                            .frame(width: 200)
                            .onChange(of: viewModel.settings.globalShortcut) { _ in
                                viewModel.saveSettings()
                            }
                    },
                    helperText: "Press the shortcut to show/hide the note editor."
                )
                
                // Launch at Login row
                preferenceRow(
                    label: "Launch at Login",
                    control: {
                        Toggle("", isOn: $viewModel.settings.launchAtLogin)
                            .labelsHidden()
                            .onChange(of: viewModel.settings.launchAtLogin) { _ in
                                viewModel.saveSettings()
                            }
                    }
                )
                
                // Duplicate note with file row
                preferenceRow(
                    label: "Duplicate note with file",
                    control: {
                        Toggle("", isOn: $viewModel.settings.duplicateNoteWithFile)
                            .labelsHidden()
                            .onChange(of: viewModel.settings.duplicateNoteWithFile) { _ in
                                viewModel.saveSettings()
                            }
                    },
                    helperText: "When you duplicate a Finder item, the new copy keeps the same note."
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 24)
            
            Spacer(minLength: 0)
            
            // Footer
            footerSection
        }
        .frame(minWidth: 500, maxWidth: 500)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.clear)
    }
    
    // MARK: - Preference Row
    
    private func preferenceRow<Content: View>(
        label: String,
        control: () -> Content,
        helperText: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                control()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            
            if let helperText = helperText {
                Text(helperText)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 20)
                    .padding(.leading, 4)
            }
        }
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        HStack {
            // Left: Icon + Version
            HStack(spacing: 8) {
                appIcon
                
                Text("Notes Version \(appVersion) – © 2026")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Right: Feedback link
            Button("Give Feedback") {
                if let url = URL(string: "mailto:feedback@example.com?subject=Notes%20Feedback") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    private var appIcon: some View {
        Group {
            if let menuBarIcon = NSImage(named: "MenuBarIcon") {
                Image(nsImage: menuBarIcon)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .opacity(0.6)
            } else if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .opacity(0.6)
            } else {
                Image(systemName: "note.text")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "1.0"
    }
}

// MARK: - Preview

#Preview {
    PreferencesView()
        .frame(width: 500, height: 500)
        .background(Color.black.opacity(0.8))
}
