import AppKit
import Carbon

final class HotKeyService {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
        start()
    }

    deinit {
        stop()
    }

    private func start() {
        if startEventTap() {
            return
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handle(event: event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.handle(event: event) {
                return nil
            }
            return event
        }
    }

    private func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }

    private func handle(event: NSEvent) -> Bool {
        if event.isARepeat {
            return false
        }

        let config = HotKeyConfiguration.load()
        let eventConfig = hotKeyConfiguration(from: event)
        if matches(config: config, eventConfig: eventConfig) {
            handler()
            return true
        }
        return false
    }

    private func startEventTap() -> Bool {
        let mask = (1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard type == .keyDown,
                  let refcon,
                  let nsEvent = NSEvent(cgEvent: event) else {
                return Unmanaged.passUnretained(event)
            }

            let service = Unmanaged<HotKeyService>.fromOpaque(refcon).takeUnretainedValue()
            if service.handle(event: nsEvent) {
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func matches(config: HotKeyConfiguration, eventConfig: HotKeyConfiguration) -> Bool {
        guard eventConfig.keyCode == config.keyCode else { return false }
        let current = eventConfig.modifierFlags & HotKeyConfiguration.relevantMask
        let target = config.modifierFlags & HotKeyConfiguration.relevantMask
        return current == target
    }
}
