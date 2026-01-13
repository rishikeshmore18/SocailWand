import AppKit

final class MacAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let panelController = ClipboardPanelController()
    private var hotKeyService: HotKeyService?
    private var onboardingWindowController: MacOnboardingWindowController?
    private let onboardingKey = "hasCompletedMacOnboarding"
    private let clipboardMonitor = MacClipboardMonitor()
    private let autoSaveKey = MacClipboardSyncService.autoSaveClipboardKey

    func applicationDidFinishLaunching(_ notification: Notification) {
        if UserDefaults.standard.object(forKey: autoSaveKey) == nil {
            UserDefaults.standard.set(true, forKey: autoSaveKey)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDefaultsChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        if UserDefaults.standard.bool(forKey: onboardingKey) {
            enableMenuBarMode()
        } else {
            showOnboarding()
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "Social Wand")
            button.action = #selector(togglePanel)
            button.target = self
        }
        statusItem = item
    }

    @objc private func togglePanel() {
        panelController.toggle()
    }

    private func enableMenuBarMode() {
        NSApp.setActivationPolicy(.regular)
        setupStatusItem()
        hotKeyService = HotKeyService { [weak self] in
            self?.panelController.toggle()
        }
        configureClipboardMonitor()
    }

    private func showOnboarding() {
        NSApp.setActivationPolicy(.regular)
        let controller = MacOnboardingWindowController { [weak self] in
            guard let self else { return }
            UserDefaults.standard.set(true, forKey: onboardingKey)
            onboardingWindowController = nil
            enableMenuBarMode()
        }
        onboardingWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func handleDefaultsChanged() {
        configureClipboardMonitor()
    }

    private func configureClipboardMonitor() {
        let autoSaveEnabled = UserDefaults.standard.bool(forKey: autoSaveKey)
        if autoSaveEnabled {
            clipboardMonitor.start()
        } else {
            clipboardMonitor.stop()
        }
    }
}

private final class MacClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount

    func start() {
        guard timer == nil else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        let newTimer = Timer(timeInterval: 0.45, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
        newTimer.tolerance = 0.2
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        MacClipboardSyncService.shared.saveFromPasteboard { success in
            guard success else { return }
            NotificationCenter.default.post(name: MacClipboardSyncService.didUpdateNotification, object: nil)
        }
    }
}
