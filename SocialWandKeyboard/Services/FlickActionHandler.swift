import CoreGraphics
import KeyboardKit

final class FlickActionHandler: KeyboardActionHandler {
    private let base: KeyboardActionHandler
    private let alternateMap: [String: String]
    private let flickThreshold: CGFloat
    private var flickedActions: [KeyboardAction: Bool] = [:]
    private let flickState: FlickGestureStateStore
    private let calloutContext: CalloutContext

    init(
        base: KeyboardActionHandler,
        keyboardContext: KeyboardContext,
        alternateMap: [String: String],
        flickState: FlickGestureStateStore,
        calloutContext: CalloutContext
    ) {
        self.base = base
        self.alternateMap = alternateMap
        self.flickState = flickState
        self.calloutContext = calloutContext
        let rowHeight = KeyboardLayout.DeviceConfiguration.standard(for: keyboardContext).rowHeight
        self.flickThreshold = rowHeight * 0.16
    }

    func canHandle(_ gesture: Keyboard.Gesture, on action: KeyboardAction) -> Bool {
        base.canHandle(gesture, on: action)
    }

    func handle(_ action: KeyboardAction) {
        if case .custom(let name) = action, name == "emoji" {
            base.handle(.keyboardType(.emojis))
            return
        }
        base.handle(action)
    }

    func handle(_ gesture: Keyboard.Gesture, on action: KeyboardAction) {
        if case .custom(let name) = action, name == "emoji" {
            if gesture == .release || gesture == .end {
                base.handle(.keyboardType(.emojis))
            } else {
                base.handle(gesture, on: action)
            }
            return
        }
        if gesture == .press {
            calloutContext.resetInputAction()
            calloutContext.resetSecondaryActions()
        }

        if (gesture == .release || gesture == .end),
           flickedActions[action] == true,
           let alternate = alternateAction(for: action) {
            base.handle(.release, on: alternate)
        } else {
            base.handle(gesture, on: action)
        }

        if gesture == .release || gesture == .end {
            flickedActions[action] = nil
            flickState.clearProgress(for: action)
            calloutContext.resetInputAction()
            calloutContext.resetSecondaryActions()
            if shouldTriggerAutocomplete(for: action) {
                NotificationCenter.default.post(name: NSNotification.Name("KeyboardAutocompleteTrigger"), object: nil)
            }
        }
    }

    func handle(_ suggestion: Autocomplete.Suggestion) {
        base.handle(suggestion)
    }

    func handleDrag(on action: KeyboardAction, from startLocation: CGPoint, to currentLocation: CGPoint) {
        base.handleDrag(on: action, from: startLocation, to: currentLocation)

        guard alternateAction(for: action) != nil else {
            flickState.clearProgress(for: action)
            calloutContext.resetInputAction()
            return
        }

        let deltaY = currentLocation.y - startLocation.y
        flickState.setProgress(deltaY / flickThreshold, for: action)
        flickedActions[action] = deltaY > flickThreshold
    }

    func triggerFeedback(for gesture: Keyboard.Gesture, on action: KeyboardAction) {
        base.triggerFeedback(for: gesture, on: action)
    }

    func triggerAudioFeedback(_ feedback: Feedback.Audio) {
        base.triggerAudioFeedback(feedback)
    }

    func triggerHapticFeedback(_ feedback: Feedback.Haptic) {
        base.triggerHapticFeedback(feedback)
    }

    private func alternateAction(for action: KeyboardAction) -> KeyboardAction? {
        guard case .character(let char) = action,
              let alternate = alternateMap[char.lowercased()] else {
            return nil
        }

        return .character(alternate)
    }

    private func shouldTriggerAutocomplete(for action: KeyboardAction) -> Bool {
        switch action {
        case .character, .space, .backspace:
            return true
        default:
            return false
        }
    }
}
