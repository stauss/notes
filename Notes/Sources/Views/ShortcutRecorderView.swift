import SwiftUI
import Carbon

struct ShortcutRecorderView: View {
    @Binding var shortcut: String
    @State private var isRecording = false
    @State private var eventMonitor: Any?
    
    var body: some View {
        Button(action: {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }) {
            HStack {
                Text(isRecording ? "Press keys..." : shortcut)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                if !shortcut.isEmpty && !isRecording {
                    Button(action: {
                        shortcut = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(isRecording ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func startRecording() {
        isRecording = true
        
        // Monitor for key events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.handleKeyEvent(event)
            return nil // Consume the event
        }
    }
    
    private func stopRecording() {
        isRecording = false
        
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        var modifierSymbols = ""
        let modifiers = event.modifierFlags
        
        // Build modifier string
        if modifiers.contains(.control) {
            modifierSymbols += "⌃"
        }
        if modifiers.contains(.option) {
            modifierSymbols += "⌥"
        }
        if modifiers.contains(.shift) {
            modifierSymbols += "⇧"
        }
        if modifiers.contains(.command) {
            modifierSymbols += "⌘"
        }
        
        // Get the key character
        if let characters = event.charactersIgnoringModifiers?.uppercased() {
            shortcut = modifierSymbols + characters
        }
        
        // Stop recording after capturing
        stopRecording()
    }
}
