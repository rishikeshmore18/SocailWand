import AppKit
import SwiftUI

@main
struct SocialWandMacApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate
    @AppStorage("hasCompletedMacOnboarding") private var hasCompletedMacOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedMacOnboarding {
                MacClipboardMainView()
            } else {
                EmptyView()
            }
        }
        Settings {
            EmptyView()
        }
    }
}

private struct MacClipboardMainView: View {
    @StateObject private var viewModel = ClipboardPanelViewModel()
    @State private var showOverlay = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            VStack(spacing: 28) {
                ZStack {
                    HStack {
                        Spacer()
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(spacing: 10) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(.purple)
                        Text("Social Wand")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Button {
                    viewModel.refresh()
                    showOverlay = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Text("Clipboard")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(24)
            .background(Color.black.opacity(0.92))
            .onAppear {
                viewModel.refresh()
                NSApp.activate(ignoringOtherApps: true)
            }
            .sheet(isPresented: $showSettings) {
                MacSettingsView()
            }

            if showOverlay {
                MacClipboardOverlay(viewModel: viewModel, onClose: {
                    showOverlay = false
                }, onSelect: { clip in
                    copyToPasteboard(clip)
                    showOverlay = false
                })
            }
        }
        .frame(minWidth: 540, minHeight: 520)
    }

    private func copyToPasteboard(_ clip: MacClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let image = clip.displayImage {
            pasteboard.writeObjects([image])
        } else {
            pasteboard.setString(clip.displayText, forType: .string)
        }
    }
}

private struct MacClipboardOverlay: View {
    @ObservedObject var viewModel: ClipboardPanelViewModel
    let onClose: () -> Void
    let onSelect: (MacClipboardItem) -> Void
    @AppStorage(MacClipboardSyncService.autoSaveClipboardKey) private var autoSaveClipboard = true

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }

                ClipboardPanelView(
                    viewModel: viewModel,
                    onSelect: onSelect,
                    onDelete: { clip in
                        MacClipboardSyncService.shared.deleteClip(id: clip.id)
                    },
                    onToggleBookmark: { clip in
                        MacClipboardSyncService.shared.toggleBookmark(id: clip.id)
                    },
                    showSaveButton: !autoSaveClipboard,
                    onSave: {
                        MacClipboardSyncService.shared.saveFromPasteboard(force: true)
                    }
                )
            }
            .padding(24)
        }
    }
}

private struct MacSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var config = HotKeyConfiguration.load()
    @State private var isRecording = false
    @State private var selection: MacSettingsSection? = .clipboardSaving
    @AppStorage(MacClipboardSyncService.autoSaveClipboardKey) private var autoSaveClipboard = true

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Text("Clipboard Saving")
                    .tag(MacSettingsSection.clipboardSaving)
                Text("Clipboard Hotkey")
                    .tag(MacSettingsSection.clipboardHotkey)
            }
            .listStyle(.sidebar)
        } detail: {
            switch selection {
            case .clipboardHotkey:
                ClipboardHotkeySettingsView(config: $config, isRecording: $isRecording)
            case .clipboardSaving, nil:
                ClipboardSavingSettingsView(autoSaveClipboard: $autoSaveClipboard)
            }
        }
        .frame(minWidth: 560, minHeight: 360)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private enum MacSettingsSection: String, CaseIterable, Identifiable {
    case clipboardSaving = "Clipboard Saving"
    case clipboardHotkey = "Clipboard Hotkey"

    var id: String { rawValue }
}

private struct ClipboardSavingSettingsView: View {
    @Binding var autoSaveClipboard: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clipboard Saving")
                .font(.title3.weight(.bold))

            Toggle("Auto-save copied items", isOn: $autoSaveClipboard)
                .toggleStyle(.switch)

            Text(autoSaveClipboard
                 ? "Everything you copy will be saved to your Social Wand clipboard."
                 : "Auto-save is off. Copied items won't be added to your Social Wand clipboard.")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
            
            // Legal links at the bottom
            Text(legalAttributedText)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    // Legal text with clickable links
    private var legalAttributedText: AttributedString {
        var prefix = AttributedString("By using this app, you agree to our ")
        prefix.foregroundColor = .secondary

        var terms = AttributedString("Terms of Service")
        terms.underlineStyle = .single
        if let url = URL(string: "https://docs.google.com/document/d/1ky4F2b6VS6U-yxinBNJ0utUhc7rCA70l/edit?usp=sharing&ouid=108118613855142229853&rtpof=true&sd=true") {
            terms.link = url
        }

        var conjunction = AttributedString(" and ")
        conjunction.foregroundColor = .secondary

        var privacy = AttributedString("Privacy Policy")
        privacy.underlineStyle = .single
        if let url = URL(string: "https://docs.google.com/document/d/15MMBXRiCT2feCImbWmQXAPF_FyIdRMj9/edit?usp=sharing&ouid=108118613855142229853&rtpof=true&sd=true") {
            privacy.link = url
        }

        var combined = prefix
        combined.append(terms)
        combined.append(conjunction)
        combined.append(privacy)
        return combined
    }
}

private struct ClipboardHotkeySettingsView: View {
    @Binding var config: HotKeyConfiguration
    @Binding var isRecording: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clipboard Hotkey")
                .font(.title3.weight(.bold))

            Text("Current: \(config.displayString())")
                .foregroundColor(.secondary)

            Button(isRecording ? "Press keys…" : "Record Shortcut") {
                isRecording.toggle()
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)

            if isRecording {
                HotkeyRecorderView(isRecording: $isRecording) { newConfig in
                    config = newConfig
                    config.save()
                }
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.2))
                )
            }

            Button("Reset to Default (fn + V)") {
                config = .default
                config.save()
            }
            .buttonStyle(.bordered)

            Spacer()
            
            // Legal links at the bottom
            Text(legalAttributedText)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    // Legal text with clickable links
    private var legalAttributedText: AttributedString {
        var prefix = AttributedString("By using this app, you agree to our ")
        prefix.foregroundColor = .secondary

        var terms = AttributedString("Terms of Service")
        terms.underlineStyle = .single
        if let url = URL(string: "https://docs.google.com/document/d/1ky4F2b6VS6U-yxinBNJ0utUhc7rCA70l/edit?usp=sharing&ouid=108118613855142229853&rtpof=true&sd=true") {
            terms.link = url
        }

        var conjunction = AttributedString(" and ")
        conjunction.foregroundColor = .secondary

        var privacy = AttributedString("Privacy Policy")
        privacy.underlineStyle = .single
        if let url = URL(string: "https://docs.google.com/document/d/15MMBXRiCT2feCImbWmQXAPF_FyIdRMj9/edit?usp=sharing&ouid=108118613855142229853&rtpof=true&sd=true") {
            privacy.link = url
        }

        var combined = prefix
        combined.append(terms)
        combined.append(conjunction)
        combined.append(privacy)
        return combined
    }
}

private struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (HotKeyConfiguration) -> Void

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.isRecording = isRecording
        nsView.onCapture = { config in
            onCapture(config)
            DispatchQueue.main.async {
                isRecording = false
            }
        }
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

private final class KeyCaptureView: NSView {
    var onCapture: ((HotKeyConfiguration) -> Void)?
    var isRecording = false

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }
        let config = hotKeyConfiguration(from: event)
        onCapture?(config)
        isRecording = false
    }
}
