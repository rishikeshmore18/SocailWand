import CoreGraphics
import KeyboardKit
import SwiftUI

final class FlickGestureStateStore: ObservableObject {
    @Published private var progressByAction: [KeyboardAction: CGFloat] = [:]

    func progress(for action: KeyboardAction) -> CGFloat {
        progressByAction[action] ?? 0
    }

    func setProgress(_ progress: CGFloat, for action: KeyboardAction) {
        let clamped = max(0, min(1, progress))
        updateState {
            self.progressByAction[action] = clamped
        }
    }

    func clearProgress(for action: KeyboardAction) {
        updateState {
            self.progressByAction[action] = nil
        }
    }

    private func updateState(_ update: @escaping () -> Void) {
        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async {
                update()
            }
        }
    }
}
