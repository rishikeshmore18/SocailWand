import AppKit
import ApplicationServices
import SwiftUI

struct MacOnboardingView: View {
    enum Step: Int, CaseIterable {
        case inputMonitoring
        case accessibility
        case welcome
    }

    @State private var step: Step = .inputMonitoring
    @State private var accessibilityEnabled = AXIsProcessTrusted()

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)

            switch step {
            case .inputMonitoring:
                PermissionCard(
                    title: "Enable Input Monitoring",
                    message: "This lets Social Wand listen for your hotkey (fn + V) so it can open the clipboard instantly.",
                    primaryActionTitle: "Open Input Monitoring",
                    primaryAction: openInputMonitoringSettings
                )
            case .accessibility:
                PermissionCard(
                    title: "Enable Accessibility",
                    message: "This allows Social Wand to paste into the active app and position the clipboard near your cursor.",
                    primaryActionTitle: accessibilityEnabled ? "Accessibility Enabled" : "Enable Accessibility",
                    primaryAction: requestAccessibility
                )
            case .welcome:
                WelcomeCard()
            }

            HStack(spacing: 12) {
                if step != .inputMonitoring {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            step = Step(rawValue: step.rawValue - 1) ?? .inputMonitoring
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Spacer()

                Button(step == .welcome ? "Finish" : "Continue") {
                    advance()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(32)
        .frame(width: 520, height: 420)
        .background(
            LinearGradient(
                colors: [Color.black, Color.black.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func advance() {
        if step == .welcome {
            onComplete()
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            step = Step(rawValue: step.rawValue + 1) ?? .welcome
        }
    }

    private func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func requestAccessibility() {
        if !AXIsProcessTrusted() {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
            _ = AXIsProcessTrustedWithOptions(options)
            openAccessibilitySettings()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            accessibilityEnabled = AXIsProcessTrusted()
        }
    }
}

private struct PermissionCard: View {
    let title: String
    let message: String
    let primaryActionTitle: String
    let primaryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 38))
                .foregroundColor(.purple)

            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)

            Button(primaryActionTitle) {
                primaryAction()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

private struct WelcomeCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 38))
                .foregroundColor(.green)

            Text("Welcome to Social Wand")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text("Your clipboard is synced and ready. Press fn + V to open it anywhere on your Mac.")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.purple)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
