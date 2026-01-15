import AppKit
import Carbon
import SwiftUI

final class ClipboardPanelController {
    private let viewModel = ClipboardPanelViewModel()
    private var panel: NSPanel?
    private var eventMonitor: Any?
    private let autoSaveKey = MacClipboardSyncService.autoSaveClipboardKey

    func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            open()
        }
    }

    private func open() {
        viewModel.refresh()
        if panel == nil {
            panel = makePanel()
        }
        updatePanelContent()
        positionPanel()
        panel?.orderFrontRegardless()
        startEventMonitor()
    }

    private func close() {
        panel?.orderOut(nil)
        stopEventMonitor()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 320),
            styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = true

        return panel
    }

    private func updatePanelContent() {
        guard let panel else { return }
        let autoSaveEnabled = UserDefaults.standard.bool(forKey: autoSaveKey)
        let view = ClipboardPanelView(
            viewModel: viewModel,
            onSelect: { [weak self] clip in
                self?.handleSelect(clip)
            },
            onDelete: { [weak self] clip in
                MacClipboardSyncService.shared.deleteClip(id: clip.id)
            },
            onToggleBookmark: { [weak self] clip in
                MacClipboardSyncService.shared.toggleBookmark(id: clip.id)
            },
            showSaveButton: !autoSaveEnabled,
            onSave: { [weak self] in
                self?.handleSave()
            },
            onClose: { [weak self] in
                self?.close()
            }
        )
        panel.contentView = NSHostingView(rootView: view)
    }

    private func positionPanel() {
        guard let panel = panel else { return }

        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let panelSize = panel.frame.size

        var x = mouseLocation.x - panelSize.width / 2
        var y = mouseLocation.y - panelSize.height - 12

        if x < visibleFrame.minX { x = visibleFrame.minX + 12 }
        if x + panelSize.width > visibleFrame.maxX { x = visibleFrame.maxX - panelSize.width - 12 }
        if y < visibleFrame.minY { y = visibleFrame.minY + 12 }

        panel.setFrameOrigin(CGPoint(x: x, y: y))
    }

    private func handleSelect(_ clip: MacClipboardItem) {
        paste(clip)
        close()
    }

    private func handleSave() {
        MacClipboardSyncService.shared.saveFromPasteboard(force: true)
    }

    private func paste(_ clip: MacClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch clip.type {
        case .text:
            pasteboard.setString(clip.textContent ?? "", forType: .string)
        case .image:
            if let url = clip.imageURL, let image = NSImage(contentsOf: url) {
                pasteboard.writeObjects([image])
            }
        }

        triggerPasteShortcut()
    }

    private func triggerPasteShortcut() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: false)

        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand

        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }

    private func startEventMonitor() {
        stopEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    private func stopEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}
