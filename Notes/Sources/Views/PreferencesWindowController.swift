import SwiftUI
import AppKit

class PreferencesWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Notes Preferences"
        
        // Force dark appearance for consistent Raycast-like look
        window.appearance = NSAppearance(named: .darkAqua)
        
        // Create visual effect view for vibrancy/translucency (darker style)
        // Frame will be set by window contentView bounds
        let visualEffect = NSVisualEffectView()
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = .ultraDark  // Darkest available material
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true
        visualEffect.appearance = NSAppearance(named: .darkAqua)
        
        // Add semi-transparent dark overlay for even deeper darkness
        let darkOverlay = NSView(frame: visualEffect.bounds)
        darkOverlay.autoresizingMask = [.width, .height]
        darkOverlay.wantsLayer = true
        darkOverlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.25).cgColor
        visualEffect.addSubview(darkOverlay)
        
        // Create hosting view for SwiftUI content
        let hostingView = NSHostingView(rootView: PreferencesView())
        hostingView.autoresizingMask = [.width, .height]
        // Add hosting view above the dark overlay
        visualEffect.addSubview(hostingView, positioned: .above, relativeTo: darkOverlay)
        
        window.contentView = visualEffect
        
        self.init(window: window)
        
        // Size window to fit content after view is laid out
        DispatchQueue.main.async { [weak window, weak hostingView] in
            guard let window = window, let hostingView = hostingView else { return }
            let fittingSize = hostingView.fittingSize
            window.setContentSize(NSSize(width: max(500, fittingSize.width), height: fittingSize.height))
            window.center()
        }
    }
    
    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
