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
            if let secondary = secondaryLabel {
                GeometryReader { geo in
                    let fontSize = min(14, geo.size.height * 0.28)
                    let offset = min(10, geo.size.height * 0.22) * progress
                    let scale = 1 + (0.12 * progress)
                    let opacity = 0.6 + (0.4 * progress)
                    Text(secondary)
                        .font(.system(size: fontSize, weight: .medium))
                        .foregroundColor(secondaryColor.opacity(opacity))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(y: offset)
                        .scaleEffect(scale)
                        .padding(.top, geo.size.height * 0.08)
                        .padding(.trailing, geo.size.height * 0.12)
                        .allowsHitTesting(false)
                }
            }
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.08), value: progress)
    }

    private var secondaryLabel: String? {
        guard case .character = item.action, let secondary = item.secondaryAction else {
            return nil
        }
        return secondary.standardButtonText(for: keyboardContext)
    }

    private var secondaryColor: Color {
        item.action
            .standardButtonForegroundColor(for: keyboardContext, isPressed: false)
            .opacity(0.6)
    }
}
