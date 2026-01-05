import SwiftUI
import KeyboardKit

struct FlickKeyButton: View {
    let item: KeyboardLayout.Item
    @ObservedObject var keyboardContext: KeyboardContext
    let actionHandler: any KeyboardActionHandler

    @State private var isPressed = false
    @State private var isFlicking = false
    @State private var startLocation: CGPoint? = nil

    var body: some View {
        GeometryReader { geo in
            let threshold = max(10, geo.size.height * 0.22)
            let backgroundColor = item.action.standardButtonBackgroundColor(for: keyboardContext, isPressed: isPressed)
            let foregroundColor = item.action.standardButtonForegroundColor(for: keyboardContext, isPressed: isPressed)
            let cornerRadius = item.action.standardButtonCornerRadius(for: keyboardContext)
            let mainFontSize = min(24, geo.size.height * 0.5)
            let altFontSize = min(14, geo.size.height * 0.28)
            let altColor = isFlicking ? foregroundColor : foregroundColor.opacity(0.6)

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)

                Text(primaryLabel)
                    .font(.system(size: mainFontSize, weight: .regular))
                    .foregroundColor(foregroundColor)

                if let secondary = secondaryLabel {
                    Text(secondary)
                        .font(.system(size: altFontSize, weight: .medium))
                        .foregroundColor(altColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, geo.size.height * 0.08)
                        .padding(.trailing, geo.size.height * 0.12)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if startLocation == nil {
                            startLocation = value.startLocation
                            isPressed = true
                            actionHandler.handle(.press, on: item.action)
                            actionHandler.triggerFeedback(for: .press, on: item.action)
                        }

                        let start = startLocation ?? value.startLocation
                        let deltaY = value.location.y - start.y

                        if hasSecondaryAction {
                            let shouldFlick = deltaY > threshold
                            if shouldFlick != isFlicking {
                                isFlicking = shouldFlick
                                if shouldFlick {
                                    actionHandler.triggerFeedback(for: .repeat, on: item.action)
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        let action = isFlicking ? (item.secondaryAction ?? item.action) : item.action
                        actionHandler.handle(.release, on: action)
                        resetPressState()
                    }
            )
        }
    }

    private var hasSecondaryAction: Bool {
        if case .character = item.secondaryAction {
            return true
        }
        return false
    }

    private var primaryLabel: String {
        item.action.standardButtonText(for: keyboardContext) ?? ""
    }

    private var secondaryLabel: String? {
        guard let secondary = item.secondaryAction else { return nil }
        return secondary.standardButtonText(for: keyboardContext)
    }

    private func resetPressState() {
        isPressed = false
        isFlicking = false
        startLocation = nil
    }
}
