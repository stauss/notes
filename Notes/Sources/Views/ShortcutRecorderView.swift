import SwiftUI
import Carbon
import Combine

struct ShortcutRecorderView: View {
    @Binding var shortcut: String
    @State private var isRecording = false
    @State private var eventMonitor: Any?
    @State private var windowObserver: AnyCancellable?
    
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
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                if !shortcut.isEmpty && !isRecording {
                    Button(action: {
                        shortcut = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isRecording ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRecording ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            setupWindowObserver()
        }
        .onDisappear {
            if isRecording {
                stopRecording()
            }
            windowObserver?.cancel()
        }
    }
    
    private func setupWindowObserver() {
        // Monitor for window resign key events to stop recording when user clicks away
        windowObserver = NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)
            .sink { [self] _ in
                if isRecording {
                    stopRecording()
                }
            }
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
