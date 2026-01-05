import SwiftUI
import KeyboardKit

struct FlickKeyContent: View {
    let item: KeyboardLayout.Item
    @ObservedObject var keyboardContext: KeyboardContext
    @ObservedObject var flickState: FlickGestureStateStore

    var body: some View {
        let hasSecondary = secondaryLabel != nil
        let progress = hasSecondary ? flickState.progress(for: item.action) : 0

        ZStack {
            GeometryReader { geo in
                let height = geo.size.height
                let width = geo.size.width
                let primarySize = height * 0.52
                let primaryCenterY = height * 0.68
                let secondaryStartY = height * 0.14
                let primaryScale = 1 - (0.18 * progress)
                let primaryOpacity = 1 - (0.9 * progress)

                if let primary = primaryLabel {
                    Text(primary)
                        .font(.system(size: primarySize, weight: .medium))
                        .foregroundColor(primaryColor.opacity(primaryOpacity))
                        .position(x: width * 0.5, y: primaryCenterY)
                        .scaleEffect(primaryScale)
                        .allowsHitTesting(false)
                }

                if let secondary = secondaryLabel {
                    let secondarySize = height * 0.24
                    let startScale = secondarySize / max(primarySize, 1)
                    let scale = startScale + ((1 - startScale) * progress)
                    let opacity = 0.6 + (0.4 * progress)
                    let deltaY = primaryCenterY - secondaryStartY
                    let weight: Font.Weight = progress > 0.4 ? .bold : .medium
                    Text(secondary)
                        .font(.system(size: primarySize, weight: weight))
                        .foregroundColor(secondaryColor.opacity(opacity))
                        .position(x: width * 0.5, y: secondaryStartY + (deltaY * progress))
                        .scaleEffect(scale)
                        .allowsHitTesting(false)
                }
            }
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.08), value: progress)
    }

    private var primaryLabel: String? {
        item.action.standardButtonText(for: keyboardContext)
    }

    private var secondaryLabel: String? {
        guard case .character = item.action, let secondary = item.secondaryAction else {
            return nil
        }
        return secondary.standardButtonText(for: keyboardContext)
    }

    private var primaryColor: Color {
        item.action
            .standardButtonForegroundColor(for: keyboardContext, isPressed: false)
    }

    private var secondaryColor: Color {
        item.action
            .standardButtonForegroundColor(for: keyboardContext, isPressed: false)
            .opacity(0.6)
    }
}
