import SwiftUI
import AppKit

struct PreferencesView: View {
    @StateObject private var viewModel = PreferencesViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        TabView {
            // General Tab
            GeneralPreferencesView(viewModel: viewModel)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            // Shortcuts Tab
            ShortcutsPreferencesView(viewModel: viewModel)
                .tabItem {
                    Label("Shortcuts", systemImage: "command")
                }
            
            // Appearance Tab
            AppearancePreferencesView(viewModel: viewModel)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
        }
        .frame(width: 500, height: 400)
        .padding()
    }
}

// MARK: - General Preferences

struct GeneralPreferencesView: View {
    @ObservedObject var viewModel: PreferencesViewModel
    
    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $viewModel.settings.launchAtLogin)
                    .onChange(of: viewModel.settings.launchAtLogin) { newValue in
                        viewModel.saveSettings()
                    }
            } header: {
                Text("Startup")
                    .font(.headline)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    viewModel.resetToDefaults()
                }
                .buttonStyle(.bordered)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Shortcuts Preferences

struct ShortcutsPreferencesView: View {
    @ObservedObject var viewModel: PreferencesViewModel
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Global Shortcut:")
                    Spacer()
                    ShortcutRecorderView(shortcut: $viewModel.settings.globalShortcut)
                        .frame(width: 200)
                        .onChange(of: viewModel.settings.globalShortcut) { newValue in
                            viewModel.saveSettings()
                        }
                }
                
                Text("Press the shortcut combination to show the note editor from anywhere.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Keyboard Shortcuts")
                    .font(.headline)
            }
            
            Spacer()
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Appearance Preferences

struct AppearancePreferencesView: View {
    @ObservedObject var viewModel: PreferencesViewModel
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Menu Bar Icon Color:")
                    Spacer()
                    ColorPicker("", selection: $viewModel.iconColor)
                        .labelsHidden()
                        .onChange(of: viewModel.iconColor) { newColor in
                            viewModel.updateIconColor(newColor)
                        }
                }
                
                HStack {
                    Text("Badge Color:")
                    Spacer()
                    ColorPicker("", selection: $viewModel.badgeColor)
                        .labelsHidden()
                        .onChange(of: viewModel.badgeColor) { newColor in
                            viewModel.updateBadgeColor(newColor)
                        }
                }
            } header: {
                Text("Colors")
                    .font(.headline)
            }
            
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Text("Preview")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Preview of menu bar icon
                        if let image = NSImage(named: "MenuBarIcon") {
                            Image(nsImage: image)
                                .renderingMode(.template)
                                .foregroundStyle(viewModel.iconColor)
                                .frame(width: 18, height: 18)
                                .padding(8)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    Spacer()
                }
            }
            
            Spacer()
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Preview

#Preview {
    PreferencesView()
}
