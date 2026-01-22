import SwiftUI
import AppKit

struct NoteEditorView: View {
    @ObservedObject var viewModel: NoteEditorViewModel
    @FocusState private var focusedField: Field?
    
    let onDismiss: () -> Void
    let onSave: (Note) -> Void
    let onDelete: () -> Void
    
    enum Field: Hashable {
        case title
        case body
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Title field + filename
            headerSection
            
            // Body editor
            bodySection
            
            // Footer toolbar
            footerSection
        }
        .frame(width: 560, height: 420)
        .background(Color.clear)
        .onAppear {
            // Focus title field when panel appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                focusedField = .title
            }
        }
        .onExitCommand {
            // Escape key - just dismiss (auto-save/delete handled by window controller)
            onDismiss()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Title field (editable, left side)
            titleField
            
            Spacer(minLength: 16)
            
            // Filename label (right side)
            if let fileName = viewModel.fileName {
                Text(fileName)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            } else if !viewModel.hasTargetFile {
                // No file selected - show browse button
                Button("Browse...") {
                    viewModel.selectFile()
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.6))
                .font(.system(size: 14))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }
    
    private var titleField: some View {
        ZStack(alignment: .leading) {
            // Placeholder
            if viewModel.title.isEmpty {
                Text("Create a note")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white.opacity(0.25))
                    .allowsHitTesting(false)
            }
            
            // Actual text field
            TextField("", text: $viewModel.title)
                .textFieldStyle(.plain)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .focused($focusedField, equals: .title)
                .onSubmit {
                    // Enter moves to body (no newline in title)
                    focusedField = .body
                }
        }
    }
    
    // MARK: - Body Section
    
    private var bodySection: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if viewModel.body.isEmpty && focusedField != .body {
                Text("Write your note here...")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.18))
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
            
            // Text editor
            TextEditor(text: $viewModel.body)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .focused($focusedField, equals: .body)
                .padding(.horizontal, 20)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        HStack(spacing: 16) {
            // App icon (left side) - using MenuBarIcon asset
            appIcon
            
            Spacer()
            
            // Cancel/Delete button - changes based on whether note exists
            if viewModel.hasExistingNote {
                // Existing note - show Delete
                Button(action: onDelete) {
                    HStack(spacing: 8) {
                        Text("Delete Note")
                            .foregroundColor(.white.opacity(0.6))
                        KeyboardShortcutBadge(modifiers: [.command], key: "X")
                    }
                }
                .buttonStyle(.plain)
                .keyboardShortcut("x", modifiers: .command)
            } else {
                // New note - show Cancel
                Button(action: onDismiss) {
                    HStack(spacing: 8) {
                        Text("Cancel")
                            .foregroundColor(.white.opacity(0.6))
                        KeyboardShortcutBadge(modifiers: [], key: "ESC")
                    }
                }
                .buttonStyle(.plain)
            }
            
            // Save button
            Button(action: handleSave) {
                HStack(spacing: 8) {
                    Text("Save Note")
                        .foregroundColor(.white.opacity(0.9))
                    KeyboardShortcutBadge(modifiers: [.command], key: "↵")
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!viewModel.hasTargetFile || viewModel.isEmpty)
            .opacity(viewModel.hasTargetFile && !viewModel.isEmpty ? 1 : 0.4)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    private var appIcon: some View {
        Group {
            // Try to load MenuBarIcon first
            if let menuBarIcon = NSImage(named: "MenuBarIcon") {
                Image(nsImage: menuBarIcon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .opacity(0.6)
            } else if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .opacity(0.6)
            } else {
                Image(systemName: "note.text")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleSave() {
        guard viewModel.hasTargetFile, !viewModel.isEmpty else { return }
        if let note = viewModel.buildNote() {
            onSave(note)
        }
        onDismiss()
    }
}

// MARK: - Keyboard Shortcut Badge

struct KeyboardShortcutBadge: View {
    let modifiers: [KeyModifier]
    let key: String
    
    enum KeyModifier {
        case command
        case option
        case control
        case shift
        
        var symbol: String {
            switch self {
            case .command: return "⌘"
            case .option: return "⌥"
            case .control: return "⌃"
            case .shift: return "⇧"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(modifiers.enumerated()), id: \.offset) { _, modifier in
                badgeKey(modifier.symbol)
            }
            badgeKey(key)
        }
    }
    
    private func badgeKey(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.55))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08))
            .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview {
    NoteEditorView(
        viewModel: NoteEditorViewModel(
            targetURL: URL(fileURLWithPath: "/Users/test/Documents/example.txt"),
            existingNote: nil
        ),
        onDismiss: {},
        onSave: { _ in },
        onDelete: {}
    )
    .frame(width: 560, height: 420)
    .background(Color.black.opacity(0.8))
}
