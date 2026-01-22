import SwiftUI
import AppKit

// MARK: - Notification Names

extension Notification.Name {
    static let noteEditorWillDismiss = Notification.Name("noteEditorWillDismiss")
    static let openNoteEditor = Notification.Name("openNoteEditor")
}

// MARK: - Custom Panel for Keyboard Focus

/// A borderless NSPanel that can become key window (required for text input)
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

// MARK: - Window Controller

class NoteEditorWindowController: NSWindowController, NSWindowDelegate {
    private(set) var targetURL: URL?
    private var existingNote: Note?
    private var viewModel: NoteEditorViewModel?
    private var hostingView: NSHostingView<NoteEditorView>?
    
    init(targetURL: URL?, existingNote: Note? = nil) {
        self.targetURL = targetURL
        self.existingNote = existingNote
        
        // Create borderless panel that CAN become key (for text input)
        // Using KeyablePanel subclass to enable keyboard focus on borderless window
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Panel configuration for Raycast-like behavior
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false  // Allow becoming key for text input
        
        // Force dark appearance for consistent Raycast-like look
        panel.appearance = NSAppearance(named: .darkAqua)
        
        // Create visual effect view for vibrancy/translucency (darker style)
        let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 560, height: 420))
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = .ultraDark  // Darkest available material
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true
        visualEffect.appearance = NSAppearance(named: .darkAqua)
        
        // Add semi-transparent dark overlay for even deeper darkness
        let darkOverlay = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 420))
        darkOverlay.autoresizingMask = [.width, .height]
        darkOverlay.wantsLayer = true
        darkOverlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.25).cgColor
        visualEffect.addSubview(darkOverlay)
        
        panel.contentView = visualEffect
        
        super.init(window: panel)
        panel.delegate = self
        
        // Create view model
        let vm = NoteEditorViewModel(targetURL: targetURL, existingNote: existingNote)
        self.viewModel = vm
        
        // Wire up auto-save callback
        vm.onAutoSave = { [weak self] note in
            guard let url = self?.targetURL else { return }
            NoteStorage.shared.saveNote(note, to: url)
            print("💾 Auto-saved (debounced) for: \(url.lastPathComponent)")
        }
        
        // Create SwiftUI view with callbacks
        let editorView = NoteEditorView(
            viewModel: vm,
            onDismiss: { [weak self] in
                self?.handleDismiss()
            },
            onSave: { [weak self] note in
                self?.handleSave(note)
            },
            onDelete: { [weak self] in
                self?.handleDelete()
            }
        )
        
        let hosting = NSHostingView(rootView: editorView)
        hosting.frame = visualEffect.bounds
        hosting.autoresizingMask = [.width, .height]
        // Add hosting view above the dark overlay
        visualEffect.addSubview(hosting, positioned: .above, relativeTo: darkOverlay)
        
        self.hostingView = hosting
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Methods
    
    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Ensure the window becomes first responder for text input
        window?.makeFirstResponder(hostingView)
    }
    
    func dismiss() {
        // Prevent multiple dismiss calls
        guard window?.isVisible == true else { return }
        window?.close()
    }
    
    // MARK: - NSWindowDelegate
    
    func windowDidResignKey(_ notification: Notification) {
        // Window lost focus - handle auto-save logic and close
        handleDismiss()
    }
    
    func windowWillClose(_ notification: Notification) {
        // Clean up
        NotificationCenter.default.post(name: .noteEditorWillDismiss, object: self)
    }
    
    // MARK: - Dismiss Logic
    
    private func handleDismiss() {
        guard let vm = viewModel, let url = targetURL else {
            dismiss()
            return
        }
        
        // COMMIT BOUNDARY: Check if note is empty
        if vm.isEmpty {
            // Delete note if it exists (empty on close = remove)
            if vm.hasExistingNote || NoteStorage.shared.hasNote(for: url) {
                NoteStorage.shared.removeNote(for: url)
                print("🗑️ Deleted empty note on dismiss: \(url.lastPathComponent)")
            }
        } else if vm.isDirty {
            // Final save on close (in case debounce hasn't fired yet)
            if let note = vm.buildNote() {
                NoteStorage.shared.saveNote(note, to: url)
                print("💾 Final save on dismiss: \(url.lastPathComponent)")
            }
        }
        
        dismiss()
    }
    
    // MARK: - Action Handlers
    
    private func handleSave(_ note: Note) {
        guard let url = targetURL else {
            print("❌ Cannot save: no target URL")
            showError("No file selected", message: "Please select a file to attach the note to.")
            return
        }
        
        // Don't save empty notes
        if viewModel?.isEmpty == true {
            print("ℹ️ Not saving empty note")
            return
        }
        
        let success = NoteStorage.shared.saveNote(note, to: url)
        if success {
            viewModel?.markAsSaved()
        } else {
            showError("Save Failed", message: "Could not save the note. The file may be read-only or inaccessible.")
        }
    }
    
    private func handleDelete() {
        guard let url = targetURL else {
            dismiss()
            return
        }
        
        // Delete any existing note
        if viewModel?.hasExistingNote == true {
            NoteStorage.shared.removeNote(for: url)
            print("🗑️ Deleted note for: \(url.lastPathComponent)")
        }
        
        dismiss()
    }
    
    private func showError(_ title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        
        if let window = self.window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
