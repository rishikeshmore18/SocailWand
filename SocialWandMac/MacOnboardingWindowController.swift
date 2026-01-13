import AppKit
import SwiftUI

final class MacOnboardingWindowController: NSWindowController {
    init(onComplete: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Social Wand"
        window.isReleasedWhenClosed = false
        window.titleVisibility = .visible

        let view = MacOnboardingView { [weak window] in
            onComplete()
            window?.close()
        }
        window.contentView = NSHostingView(rootView: view)

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        return nil
    }
}
