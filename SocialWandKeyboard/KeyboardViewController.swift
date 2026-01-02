//
//  KeyboardViewController.swift
//  SocialWandKeyboard
//

import UIKit
import SwiftUI
import KeyboardKit
import ObjectiveC

private enum SharedConstants {
    static let appGroupID = "group.rishi-more.social-wand"
    static let fullAccessKey = "KeyboardFullAccess"
}

final class KeyboardViewController: KeyboardInputViewController {
    
    // MARK: - Properties
    
    private var toolbarHosting: UIHostingController<AnyView>?
    
    // Tone picker
    private var tonePickerHosting: UIHostingController<TonePickerView>?
    private var currentTextForTone: String = ""
    private var savedTonePreferences: [String] = []
    
    // Length picker
    private var lengthPickerHosting: UIHostingController<LengthPickerView>?
    private var savedLengthPreference: String? = nil
    
    // Menu picker
    private var menuPickerHosting: UIHostingController<MenuPickerView>?
    
    // Clipboard history
    private var clipboardHistoryHosting: UIHostingController<ClipboardHistoryView>?
    
    // Tone/Length ID to Title mapping
    private let toneMapping: [String: String] = [
        "assertive": "Assertive",
        "confident": "Confident",
        "playful": "Playful",
        "empathetic": "Empathetic",
        "flirtatious": "Flirtatious",
        "professional": "Professional",
        "casual": "Casual"
    ]
    
    // Create the SuggestionsViewModel once
    private let suggestionsViewModel = SuggestionsViewModel()
    
    // Suggestions view hosting (created once)
    private var suggestionsHosting: UIHostingController<SuggestionsView>?
    
    // Store reference to keyboard view
    private weak var keyboardView: UIView?
    
    // State for suggestions
    private var suggestionBatchCount = 0
    
    // Banner properties
    private var suggestionBanner: SuggestionBannerView?
    private var statusBanner: SuggestionBannerView?
    private var hasPendingSuggestion = false
    
    // Custom feedback service (stored to prevent deallocation)
    private var customFeedbackService: CustomFeedbackService?
    
    // Track last visible picker for state restoration
    private enum LastVisiblePicker {
        case none
        case suggestions
        case tonePicker
        case lengthPicker
        case menuPicker
        case clipboardHistory
    }
    private var lastVisiblePicker: LastVisiblePicker = .none
    
    // Flag to prevent clearing state during restoration
    private var isRestoringPicker = false
    
    // Sync timer for monitoring App Group changes
    private var lengthSyncTimer: Timer? = nil
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        print("🚀 viewDidLoad called")
        
        // Set up callbacks once
        setupSuggestionsCallbacks()
        
        // Load saved preferences
        savedTonePreferences = loadSavedTonePreferences()
        savedLengthPreference = loadSavedLengthPreference()
        
        updateFullAccessFlag()
        
        // Start polling for length preference changes
        startLengthSyncTimer()
    }
    
    // MARK: - KeyboardKit Feedback Configuration
    
    func viewWillSetupKeyboard() {
        print("🔧 viewWillSetupKeyboard called - setting up custom feedback")
        setupCustomFeedbackService()
    }
    
    override func viewWillSetupKeyboardView() {
        super.viewWillSetupKeyboardView()
        
        // Enable swipe-down actions for iPhone (required for secondaryAction to work)
        state.keyboardContext.settings.isSwipeDownActionsEnabled = true
        print("✅ Enabled swipe-down actions for numeric alternatives")
        
        setupKeyboardView { [weak self] controller in
            let context = controller.state.keyboardContext
            let layout = self?.makeIPhoneNumericLayout(for: context)
            return KeyboardView(layout: layout, services: controller.services)
        }
    }
    
    private func makeIPhoneNumericLayout(for context: KeyboardContext) -> KeyboardLayout? {
        print("📱 makeIPhoneNumericLayout called - deviceType: \(context.deviceType)")
        
        // Verify device type check
        guard context.deviceType == .phone else {
            print("⚠️ Skipping numeric layout - not iPhone (deviceType: \(context.deviceType))")
            return nil
        }
        
        print("✅ iPhone detected, creating numeric layout...")
        
        // Try to get base layout with error handling
        let base: KeyboardLayout
        do {
            base = try context.locale.keyboardLayout(for: context)
            print("✅ Base layout created successfully")
        } catch {
            print("❌ Failed to create base layout: \(error)")
            return nil
        }
        
        let map: [String: String] = [
            "q": "1", "w": "2", "e": "3", "r": "4", "t": "5",
            "y": "6", "u": "7", "i": "8", "o": "9", "p": "0"
        ]
        
        var rows = base.itemRows
        var modifiedCount = 0
        
        for rowIndex in rows.indices {
            for itemIndex in rows[rowIndex].indices {
                let item = rows[rowIndex][itemIndex]
                if case .character(let char) = item.action,
                   let number = map[char.lowercased()] {
                    var updated = item
                    updated.secondaryAction = .character(number)
                    rows[rowIndex][itemIndex] = updated
                    modifiedCount += 1
                    print("  ✓ Added numeric alternative: \(char.uppercased()) → \(number)")
                }
            }
        }
        
        print("✅ Numeric layout created: \(modifiedCount) keys modified")
        
        return KeyboardLayout(
            itemRows: rows,
            deviceConfiguration: base.deviceConfiguration,
            idealItemHeight: base.idealItemHeight,
            idealItemInsets: base.idealItemInsets,
            inputToolbarInputSet: base.inputToolbarInputSet
        )
    }
    
    private func applyFeedbackSettingsFromAppGroup() {
        guard let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) else {
            print("⚠️ Cannot access App Group for feedback settings")
            return
        }
        
        // Read settings from App Group
        let soundEnabled = defaults.bool(forKey: "SoundFeedbackEnabled")
        let hapticLevel = defaults.string(forKey: "HapticFeedbackLevel") ?? "soft"
        let hapticsEnabled = hapticLevel != "off"
        
        // Sync KeyboardKit settings with App Group
        state.feedbackContext.settings.isAudioFeedbackEnabled = soundEnabled
        state.feedbackContext.settings.isHapticFeedbackEnabled = hapticsEnabled
        
        print("✅ Synced feedback settings: sound=\(soundEnabled), haptics=\(hapticsEnabled ? "on" : "off")")
    }
    
    private func setupCustomFeedbackService() {
        // Sync KeyboardKit settings with App Group first
        applyFeedbackSettingsFromAppGroup()
        
        // Create and store custom feedback service instance
        if customFeedbackService == nil {
            customFeedbackService = CustomFeedbackService()
        }
        
        // Assign to KeyboardKit (unwrap since we just created it if nil)
        guard let service = customFeedbackService else {
            print("❌ Failed to create custom feedback service")
            return
        }
        services.feedbackService = service
        print("✅ Custom feedback service installed")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("👁️ viewDidAppear")
        
        // Safety check: Ensure custom feedback service is installed
        if !(services.feedbackService is CustomFeedbackService) {
            print("⚠️ Custom feedback service missing, reinstalling...")
            setupCustomFeedbackService()
        }
        
        // Check if toolbar exists AND is actually visible in view hierarchy
        let toolbarNeedsRecreation = toolbarHosting == nil ||
                                     toolbarHosting?.view.superview == nil ||
                                     toolbarHosting?.view.frame.width == 0
        
        if toolbarNeedsRecreation {
            // Clean up stale reference if it exists
            cleanupToolbar()
            
            // Recreate toolbar
            addToolbarDirectly()
        } else {
            // Toolbar exists and is visible - ensure it's on top
            if let toolbar = toolbarHosting {
                view.bringSubviewToFront(toolbar.view)
            }
            print("✅ Toolbar already visible, brought to front")
        }
        
        // NEW: Check for photos ready from main app
        checkForPhotosReady()
        
        // Restore last visible picker if it was removed
        restoreLastVisiblePicker()
        
        // Check for pending suggestion
        checkForPendingSuggestion()
        
        // Restart length sync timer if it was stopped
        if lengthSyncTimer == nil {
            startLengthSyncTimer()
        }
        
        updateFullAccessFlag()
    }
    
    // NEW: Centralized refresh for picker text
    // This prevents stale/empty currentTextForTone during restore cycles.
    private func refreshCurrentTextForPickers() -> String {
        let context = getTextContext()
        currentTextForTone = context.textToImprove
        return currentTextForTone
    }
    
    // NEW: Check if main app saved photos for us
    private func checkForPhotosReady() {
        guard let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) else {
            return
        }
        
        // Check if photos are ready
        guard defaults.bool(forKey: "PhotosReadyForKeyboard") else {
            return
        }
        
        print("📸 Photos ready from main app!")
        
        // Get photo count
        let photoCount = defaults.integer(forKey: "PhotosReadyCount")
        guard photoCount > 0 else {
            print("⚠️ PhotosReadyForKeyboard flag set but no photos")
            defaults.set(false, forKey: "PhotosReadyForKeyboard")
            return
        }
        
        // Get context (optional)
        let context = defaults.string(forKey: "PhotosReadyContext") ?? ""
        
        // Load photos from App Group
        var photos: [String] = []
        for i in 0..<photoCount {
            if let photoData = defaults.string(forKey: "PhotoReady_\(i)") {
                photos.append(photoData)
            }
        }
        
        guard photos.count == photoCount else {
            print("⚠️ Photo count mismatch: expected \(photoCount), got \(photos.count)")
            clearPhotoData(defaults)
            return
        }
        
        print("✅ Loaded \(photos.count) photos from App Group")
        
        // Clear the flags
        clearPhotoData(defaults)
        
        // Show suggestions view if not already visible
        if suggestionsHosting == nil {
            showSuggestionsView()
        }
        
        // Start generation immediately
        suggestionsViewModel.state = .loading
        suggestionsViewModel.suggestions = []
        suggestionBatchCount = 0
        
        // Get saved preferences
        let toneTitles = savedTonePreferences.compactMap { toneMapping[$0] }
        let lengthValue = savedLengthPreference
        
        // Store operation for retry
        suggestionsViewModel.lastOperation = .photoGeneration(
            photos: photos,
            context: context,
            tones: toneTitles.isEmpty ? nil : toneTitles,
            length: lengthValue
        )
        
        // Generate from photos
        generateMoreFromPhoto(
            photos: photos,
            context: context,
            tones: toneTitles.isEmpty ? nil : toneTitles,
            length: lengthValue
        )
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func clearPhotoData(_ defaults: UserDefaults) {
        defaults.set(false, forKey: "PhotosReadyForKeyboard")
        defaults.removeObject(forKey: "PhotosReadyCount")
        defaults.removeObject(forKey: "PhotosReadyContext")
        
        // Clear all photo data (support up to 10 photos)
        for i in 0..<10 {
            defaults.removeObject(forKey: "PhotoReady_\(i)")
        }
        
        print("🧹 Cleared photo data from App Group")
    }
    
    // Restore picker state after keyboard reappears
    private func restoreLastVisiblePicker() {
        guard lastVisiblePicker != .none else { return }
        
        print("🔄 Attempting to restore last visible picker: \(lastVisiblePicker)")
        
        // Set flag to prevent hide methods from clearing lastVisiblePicker
        isRestoringPicker = true
        defer { isRestoringPicker = false }
        
        // Always try to restore - the show methods have guards to prevent duplicates
        switch lastVisiblePicker {
        case .suggestions:
            if suggestionsHosting == nil || suggestionsHosting?.view.superview == nil {
                print("↩️ Restoring suggestions view")
                showSuggestionsView()
            } else {
                print("✅ Suggestions view already visible")
            }
            
        case .tonePicker:
            if tonePickerHosting == nil || tonePickerHosting?.view.superview == nil {
                print("↩️ Restoring tone picker")
                _ = refreshCurrentTextForPickers()
                showTonePicker()
            } else {
                print("✅ Tone picker already visible")
            }
            
        case .lengthPicker:
            if lengthPickerHosting == nil || lengthPickerHosting?.view.superview == nil {
                print("↩️ Restoring length picker")
                _ = refreshCurrentTextForPickers()
                showLengthPicker()
            } else {
                print("✅ Length picker already visible")
            }
            
        case .menuPicker:
            if menuPickerHosting == nil || menuPickerHosting?.view.superview == nil {
                print("↩️ Restoring menu picker")
                showMenuPicker()
            } else {
                print("✅ Menu picker already visible")
            }
            
        case .clipboardHistory:
            if clipboardHistoryHosting == nil || clipboardHistoryHosting?.view.superview == nil {
                print("↩️ Restoring clipboard history")
                showClipboardHistory()
            } else {
                print("✅ Clipboard history already visible")
            }
            
        case .none:
            break
        }
    }
    
    // MARK: - Setup Callbacks
    
    private func setupSuggestionsCallbacks() {
        suggestionsViewModel.onApply = { [weak self] text in
            self?.applySuggestion(text)
        }
        
        suggestionsViewModel.onGenerateMore = { [weak self] in
            guard let self = self else { return }
            
            if let lastOp = self.suggestionsViewModel.lastOperation {
                print("🔄 Generate More - retrying last operation with preferences")
                
                // Check if this is photo generation - handle differently
                if case .photoGeneration(let photos, let context, let tones, let length) = lastOp {
                    // Get previous messages from current suggestions
                    let previousMessages = self.suggestionsViewModel.suggestions.map { $0.text }
                    print("📸 Photo generation - generating more with \(previousMessages.count) previous messages")
                    self.generateMoreFromPhoto(photos: photos, context: context, previousMessages: previousMessages, tones: tones, length: length)
                } else {
                    // Text-based generation - use existing retry logic
                    self.retryLastOperation()
                }
            } else {
                let context = self.getTextContext()
                self.suggestionsViewModel.lastOperation = .normalGeneration(text: context.textToImprove)
                self.generateSuggestions(for: context.textToImprove)
            }
        }
        
        suggestionsViewModel.onShowKeyboard = { [weak self] in
            self?.hideSuggestionsView()
        }
        
        suggestionsViewModel.onRetry = { [weak self] in
            self?.retryLastOperation()
        }
        
        // ✅ NEW: Handle preference changes from suggestions view
        suggestionsViewModel.onPreferencesChanged = { [weak self] toneIDs, lengthID in
            guard let self = self else { return }
            
            print("🎨 Preferences changed in SuggestionsView:")
            print("   Tones: \(toneIDs)")
            print("   Length: \(lengthID ?? "none")")
            
            // Update saved preferences
            self.savedTonePreferences = toneIDs
            self.savedLengthPreference = lengthID
            
            // Get the last operation to know what to regenerate
            guard let lastOp = self.suggestionsViewModel.lastOperation else {
                print("⚠️ No last operation to regenerate")
                return
            }
            
            // Convert tone IDs to titles for API
            let toneTitles = toneIDs.compactMap { self.toneMapping[$0] }
            
            // Regenerate based on last operation type
            switch lastOp {
            case .normalGeneration(let text):
                if let length = lengthID {
                    let lengthTitle = length.prefix(1).uppercased() + length.dropFirst()
                    self.applyLengthToText(text, length: lengthTitle, tones: toneTitles.isEmpty ? nil : toneTitles)
                } else if !toneTitles.isEmpty {
                    self.applyTonesToText(text, tones: toneTitles)
                } else {
                    self.generateSuggestions(for: text)
                }
                
            case .toneChange(let text, _):
                if let length = lengthID {
                    let lengthTitle = length.prefix(1).uppercased() + length.dropFirst()
                    self.applyLengthToText(text, length: lengthTitle, tones: toneTitles.isEmpty ? nil : toneTitles)
                } else if !toneTitles.isEmpty {
                    self.applyTonesToText(text, tones: toneTitles)
                } else {
                    self.generateSuggestions(for: text)
                }
                
            case .lengthChange(let text, _, _):
                if let length = lengthID {
                    let lengthTitle = length.prefix(1).uppercased() + length.dropFirst()
                    self.applyLengthToText(text, length: lengthTitle, tones: toneTitles.isEmpty ? nil : toneTitles)
                } else if !toneTitles.isEmpty {
                    self.applyTonesToText(text, tones: toneTitles)
                } else {
                    self.generateSuggestions(for: text)
                }
                
            case .replyGeneration(let incomingText, _, _):
                self.generateReply(to: incomingText, tones: toneTitles.isEmpty ? nil : toneTitles, length: lengthID)
                
            case .rewriteGeneration(let originalText, _, _):
                self.generateRewrite(of: originalText, tones: toneTitles.isEmpty ? nil : toneTitles, length: lengthID)
                
            case .photoGeneration(let photos, let context, _, _):
                self.generateMoreFromPhoto(photos: photos, context: context, tones: toneTitles.isEmpty ? nil : toneTitles, length: lengthID)
            }
            
            print("✅ Regeneration triggered with new preferences")
        }
    }
    
    // MARK: - Toolbar Button State Management
    
    private func updateToolbarButtonState(_ buttonType: ToolbarButtonType, isActive: Bool) {
        let notificationName = isActive ? "SetActiveButton" : "ClearActiveButton"
        NotificationCenter.default.post(
            name: NSNotification.Name(notificationName),
            object: nil,
            userInfo: ["buttonType": buttonType]
        )
    }
    
    // MARK: - Active View Detection
    
    private func closeAnyActiveView() {
        if suggestionsHosting != nil {
            hideSuggestionsView()
        }
        if tonePickerHosting != nil {
            hideTonePicker()
        }
        if lengthPickerHosting != nil {
            hideLengthPicker()
        }
        if menuPickerHosting != nil {
            hideMenuPicker()
        }
        if clipboardHistoryHosting != nil {
            hideClipboardHistory()
        }
    }
    
    private func isAnyViewActive() -> Bool {
        return suggestionsHosting != nil ||
               tonePickerHosting != nil ||
               lengthPickerHosting != nil ||
               menuPickerHosting != nil ||
               clipboardHistoryHosting != nil
    }
    
    // Retry the last failed operation
    private func retryLastOperation() {
        guard let lastOp = suggestionsViewModel.lastOperation else {
            print("⚠️ No last operation to retry")
            return
        }
        
        print("🔄 Retrying last operation...")
        
        switch lastOp {
        case .normalGeneration(let text):
            generateSuggestions(for: text)
            
        case .toneChange(let text, let tones):
            applyTonesToText(text, tones: tones)
            
        case .lengthChange(let text, let length, let tones):
            applyLengthToText(text, length: length, tones: tones)
            
        case .photoGeneration(let photos, let context, let tones, let length):
            generateMoreFromPhoto(photos: photos, context: context, tones: tones, length: length)
            
        case .replyGeneration(let incomingText, let tones, let length):
            generateReply(to: incomingText, tones: tones, length: length)
            
        case .rewriteGeneration(let originalText, let tones, let length):
            generateRewrite(of: originalText, tones: tones, length: length)
        }
    }
    
    // MARK: - Toolbar Setup
    
    private func cleanupToolbar() {
        guard let hosting = toolbarHosting else { return }
        
        hosting.willMove(toParent: nil)
        hosting.view.removeFromSuperview()
        hosting.removeFromParent()
        toolbarHosting = nil
        
        // Reset keyboard view reference so addToolbarDirectly can reposition it
        keyboardView = nil
        
        print("🧹 Cleaned up stale toolbar")
    }
    
    private func addToolbarDirectly() {
        print("🎯 Adding toolbar directly")
        
        // CRITICAL: Only adjust keyboard frame ONCE (guard with keyboardView == nil)
        if keyboardView == nil, let kbView = view.subviews.first {
            print("📊 Found KeyboardKit view: \(kbView.frame)")
            
            keyboardView = kbView
            
            kbView.frame = CGRect(
                x: 0,
                y: 44,
                width: kbView.frame.width,
                height: kbView.frame.height - 44
            )
            
            print("📊 Moved KeyboardKit view to: \(kbView.frame)")
        }
        
        let toolbarView = WandToolbar(
            onWandTap: { [weak self] in
                self?.handleGenerateButtonTap()
            },
            onToneButtonTap: { [weak self] in
                self?.handleToneButtonTap()
            },
            onLengthButtonTap: { [weak self] in
                self?.handleLengthButtonTap()
            },
            onUploadButtonTap: { [weak self] in
                self?.handleUploadButtonTap()
            },
            onReplyButtonTap: { [weak self] in
                self?.handleReplyButtonTap()
            },
            onRewriteButtonTap: { [weak self] in
                self?.handleRewriteButtonTap()
            },
            onMenuButtonTap: { [weak self] in
                self?.handleMenuButtonTap()
            },
            onSaveButtonTap: { [weak self] in
                self?.handlePasteAction()
            },
            onClipboardButtonTap: { [weak self] in
                self?.handleClipboardAction()
            },
            onSettingsButtonTap: { [weak self] in
                self?.handleSettingsAction()
            },
            isSuggestionsVisible: { [weak self] in
                return (self?.suggestionsHosting != nil) ||
                       (self?.tonePickerHosting != nil) ||
                       (self?.lengthPickerHosting != nil) ||
                       (self?.menuPickerHosting != nil) ||
                       (self?.clipboardHistoryHosting != nil)
            },
            onCloseSuggestions: { [weak self] in
                if self?.suggestionsHosting != nil {
                    self?.hideSuggestionsView()
                }
                if self?.tonePickerHosting != nil {
                    self?.hideTonePicker()
                }
                if self?.lengthPickerHosting != nil {
                    self?.hideLengthPicker()
                }
                if self?.menuPickerHosting != nil {
                    self?.hideMenuPicker()
                }
                if self?.clipboardHistoryHosting != nil {
                    self?.hideClipboardHistory()
                }
            }
        )
        
        let hosting = UIHostingController(rootView: AnyView(toolbarView))
        hosting.view.backgroundColor = UIColor.clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        
        addChild(hosting)
        view.addSubview(hosting.view)
        
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        hosting.didMove(toParent: self)
        toolbarHosting = hosting
        
        view.bringSubviewToFront(hosting.view)
        
        print("✅ Production toolbar added")
        print("📊 Toolbar frame: \(hosting.view.frame)")
    }
    
    // MARK: - Generation Handling
    
    private func handleGenerateButtonTap() {
        print("🔄 Gen button tapped")
        
        let context = getTextContext()
        
        guard !context.textToImprove.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ No text to improve")
            return
        }
        
        print("📝 Text to improve: \(context.textToImprove)")
        
        // Show suggestions view
        if suggestionsHosting == nil {
            showSuggestionsView()
        }
        
        // Apply saved preferences automatically
        let hasSavedTones = !savedTonePreferences.isEmpty
        let hasSavedLength = savedLengthPreference != nil
        
        if hasSavedLength || hasSavedTones {
            print("🎯 Applying saved preferences - Tones: \(savedTonePreferences), Length: \(savedLengthPreference ?? "none")")
            
            // Convert tone IDs to titles
            let toneTitles = savedTonePreferences.compactMap { toneMapping[$0] }
            
            if hasSavedLength {
                // Capitalize first letter for API
                let lengthTitle = savedLengthPreference!.prefix(1).uppercased() + savedLengthPreference!.dropFirst()
                
                // Store operation for retry
                suggestionsViewModel.lastOperation = .lengthChange(
                    text: context.textToImprove,
                    length: lengthTitle,
                    tones: toneTitles.isEmpty ? nil : toneTitles
                )
                
                // Apply length (with or without tones)
                applyLengthToText(context.textToImprove, length: lengthTitle, tones: toneTitles.isEmpty ? nil : toneTitles)
            } else {
                // Store operation for retry
                suggestionsViewModel.lastOperation = .toneChange(
                    text: context.textToImprove,
                    tones: toneTitles
                )
                
                // Apply tones only
                applyTonesToText(context.textToImprove, tones: toneTitles)
            }
        } else {
            // Store operation for retry
            suggestionsViewModel.lastOperation = .normalGeneration(text: context.textToImprove)
            
            // Normal generation (no saved preferences)
            suggestionsViewModel.suggestions = []
            suggestionBatchCount = 0
            generateSuggestions(for: context.textToImprove)
        }
    }
    
    private func generateSuggestions(for text: String) {
        // Determine if this is first generation or "Generate More"
        let isGenerateMore = !suggestionsViewModel.suggestions.isEmpty
        
        // Collect previous outputs to avoid duplicates
        let previousOutputs = suggestionsViewModel.suggestions.map { $0.text }
        
        if isGenerateMore {
            suggestionsViewModel.state = .loadingMore
        } else {
            suggestionsViewModel.state = .loading
            suggestionBatchCount = 0  // Reset batch count
        }
        
        Task {
            do {
                let alternatives = try await KeyboardAIService.shared.generateSuggestions(
                    for: text,
                    previousOutputs: previousOutputs
                )
                
                await MainActor.run {
                    // Create new suggestions
                    let newSuggestions = alternatives.enumerated().map { index, text in
                        KeyboardSuggestion(
                            text: text,
                            index: suggestionBatchCount * 2 + index
                        )
                    }
                    
                    // Update ViewModel - prepend new suggestions at top
                    if isGenerateMore {
                        suggestionsViewModel.suggestions.insert(contentsOf: newSuggestions, at: 0)
                        print("✅ Prepended \(newSuggestions.count) new suggestions (total: \(suggestionsViewModel.suggestions.count))")
                    } else {
                        suggestionsViewModel.suggestions = newSuggestions
                        print("✅ Initial suggestions set (\(newSuggestions.count) suggestions)")
                    }
                    
                    suggestionBatchCount += 1
                    
                    suggestionsViewModel.state = .success(suggestionsViewModel.suggestions)
                    
                    print("✅ Generated \(alternatives.count) suggestions (total: \(suggestionsViewModel.suggestions.count))")
                }
            } catch {
                await MainActor.run {
                    print("❌ Generation failed: \(error)")
                    let message = (error as? KeyboardAIError)?.errorDescription ?? "Something went wrong"
                    suggestionsViewModel.state = .error(message)
                }
            }
        }
    }
    
    // MARK: - Reply Button Handling

    private func handleReplyButtonTap() {
        print("💬 Reply button tapped")
        
        // ✅ Check if Reply view is already open (toggle off)
        if suggestionsHosting != nil && lastVisiblePicker == .suggestions {
            // Check if this is a Reply operation
            if case .replyGeneration = suggestionsViewModel.lastOperation {
                // Same button pressed - toggle off
                hideSuggestionsView()
                updateToolbarButtonState(.reply, isActive: false)
                print("✅ Reply suggestions closed (toggle off)")
                return
            }
        }
        
        // ✅ Different button or no view open - direct switch
        let context = getTextContext()
        let incomingText = context.fullText
        
        guard !incomingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ No incoming message to reply to")
            return
        }
        
        print("📝 Generating reply to: \(incomingText)")
        
        // Close any active view (Rewrite, Tone, Length, Menu, etc.)
        closeAnyActiveView()
        
        // Show suggestions view
        showSuggestionsView()
        
        // Set button to active state (purple)
        updateToolbarButtonState(.reply, isActive: true)
        
        // Apply saved preferences
        let toneTitles = savedTonePreferences.compactMap { toneMapping[$0] }
        let lengthValue = savedLengthPreference
        
        // Store operation for retry
        suggestionsViewModel.lastOperation = .replyGeneration(
            incomingText: incomingText,
            tones: toneTitles.isEmpty ? nil : toneTitles,
            length: lengthValue
        )
        
        // Generate reply
        generateReply(to: incomingText, tones: toneTitles.isEmpty ? nil : toneTitles, length: lengthValue)
        
        print("✅ Reply suggestions opened (direct switch)")
    }

    private func generateReply(to incomingText: String, tones: [String]?, length: String?) {
        let isGenerateMore = !suggestionsViewModel.suggestions.isEmpty
        let previousOutputs = suggestionsViewModel.suggestions.map { $0.text }
        
        if isGenerateMore {
            suggestionsViewModel.state = .loadingMore
        } else {
            suggestionsViewModel.state = .loading
            suggestionsViewModel.suggestions = []
            suggestionBatchCount = 0
        }
        
        Task {
            do {
                let alternatives = try await KeyboardAIService.shared.generateReply(
                    for: incomingText,
                    tones: tones,
                    length: length,
                    previousOutputs: previousOutputs
                )
                
                await MainActor.run {
                    let newSuggestions = alternatives.enumerated().map { index, text in
                        KeyboardSuggestion(
                            text: text,
                            index: suggestionBatchCount * 2 + index
                        )
                    }
                    
                    if isGenerateMore {
                        suggestionsViewModel.suggestions.insert(contentsOf: newSuggestions, at: 0)
                        print("✅ Reply - prepended \(newSuggestions.count) suggestions (total: \(suggestionsViewModel.suggestions.count))")
                    } else {
                        suggestionsViewModel.suggestions = newSuggestions
                        print("✅ Reply - initial \(newSuggestions.count) suggestions")
                    }
                    
                    suggestionBatchCount += 1
                    suggestionsViewModel.state = .success(suggestionsViewModel.suggestions)
                    
                    print("✅ Reply generated successfully - \(alternatives.count) alternatives")
                }
            } catch {
                await MainActor.run {
                    print("❌ Reply generation failed: \(error)")
                    let message = (error as? KeyboardAIError)?.errorDescription ?? "Failed to generate reply"
                    suggestionsViewModel.state = .error(message)
                }
            }
        }
    }
    
    // MARK: - Rewrite Button Handling

    private func handleRewriteButtonTap() {
        print("✏️ Rewrite button tapped")
        
        // ✅ Check if Rewrite view is already open (toggle off)
        if suggestionsHosting != nil && lastVisiblePicker == .suggestions {
            // Check if this is a Rewrite operation
            if case .rewriteGeneration = suggestionsViewModel.lastOperation {
                // Same button pressed - toggle off
                hideSuggestionsView()
                updateToolbarButtonState(.rewrite, isActive: false)
                print("✅ Rewrite suggestions closed (toggle off)")
                return
            }
        }
        
        // ✅ Different button or no view open - direct switch
        let context = getTextContext()
        let textToRewrite = context.hasSelection ? (context.selectedText ?? "") : context.fullText
        
        guard !textToRewrite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ No text to rewrite")
            return
        }
        
        print("📝 Rewriting text: \(textToRewrite)")
        
        // Close any active view
        closeAnyActiveView()
        
        // Show suggestions view
        showSuggestionsView()
        
        // Set button to active state (purple)
        updateToolbarButtonState(.rewrite, isActive: true)
        
        // Apply saved preferences
        let toneTitles = savedTonePreferences.compactMap { toneMapping[$0] }
        let lengthValue = savedLengthPreference
        
        // Store operation for retry
        suggestionsViewModel.lastOperation = .rewriteGeneration(
            originalText: textToRewrite,
            tones: toneTitles.isEmpty ? nil : toneTitles,
            length: lengthValue
        )
        
        // Generate rewrite
        generateRewrite(of: textToRewrite, tones: toneTitles.isEmpty ? nil : toneTitles, length: lengthValue)
        
        print("✅ Rewrite suggestions opened (direct switch)")
    }

    private func generateRewrite(of originalText: String, tones: [String]?, length: String?) {
        let isGenerateMore = !suggestionsViewModel.suggestions.isEmpty
        let previousOutputs = suggestionsViewModel.suggestions.map { $0.text }
        
        if isGenerateMore {
            suggestionsViewModel.state = .loadingMore
        } else {
            suggestionsViewModel.state = .loading
            suggestionsViewModel.suggestions = []
            suggestionBatchCount = 0
        }
        
        Task {
            do {
                let alternatives = try await KeyboardAIService.shared.generateRewrite(
                    for: originalText,
                    tones: tones,
                    length: length,
                    previousOutputs: previousOutputs
                )
                
                await MainActor.run {
                    let newSuggestions = alternatives.enumerated().map { index, text in
                        KeyboardSuggestion(
                            text: text,
                            index: suggestionBatchCount * 2 + index
                        )
                    }
                    
                    if isGenerateMore {
                        suggestionsViewModel.suggestions.insert(contentsOf: newSuggestions, at: 0)
                        print("✅ Rewrite - prepended \(newSuggestions.count) suggestions (total: \(suggestionsViewModel.suggestions.count))")
                    } else {
                        suggestionsViewModel.suggestions = newSuggestions
                        print("✅ Rewrite - initial \(newSuggestions.count) suggestions")
                    }
                    
                    suggestionBatchCount += 1
                    suggestionsViewModel.state = .success(suggestionsViewModel.suggestions)
                    
                    print("✅ Rewrite generated successfully - \(alternatives.count) alternatives")
                }
            } catch {
                await MainActor.run {
                    print("❌ Rewrite generation failed: \(error)")
                    let message = (error as? KeyboardAIError)?.errorDescription ?? "Failed to generate rewrite"
                    suggestionsViewModel.state = .error(message)
                }
            }
        }
    }
    
    private func getTextContext() -> TextContext {
        let fullText = textDocumentProxy.documentContextBeforeInput ?? ""
        let selectedText = textDocumentProxy.selectedText
        let hasSelection = selectedText != nil && !selectedText!.isEmpty
        
        return TextContext(
            fullText: fullText,
            selectedText: selectedText,
            hasSelection: hasSelection
        )
    }
    
    // MARK: - Suggestions View Management
    
    private func showSuggestionsView() {
        guard suggestionsHosting == nil else { return }
        
        // Hide other pickers (mutual exclusivity)
        if tonePickerHosting != nil {
            hideTonePicker()
        }
        if lengthPickerHosting != nil {
            hideLengthPicker()
        }
        if menuPickerHosting != nil {
            hideMenuPicker()
        }
        if clipboardHistoryHosting != nil {
            hideClipboardHistory()
        }
        
        // ✅ NEW: Update viewModel with current preferences BEFORE creating view
        suggestionsViewModel.currentTones = savedTonePreferences
        suggestionsViewModel.currentLength = savedLengthPreference
        
        // Create view once with ViewModel
        let suggestionsView = SuggestionsView(viewModel: suggestionsViewModel)
        
        let hosting = UIHostingController(rootView: suggestionsView)
        hosting.view.backgroundColor = UIColor.clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        
        addChild(hosting)
        view.addSubview(hosting.view)
        
        // Position below toolbar (y: 44)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor, constant: 44),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        hosting.didMove(toParent: self)
        suggestionsHosting = hosting
        
        // Bring to front (covers keyboard)
        view.bringSubviewToFront(hosting.view)
        
        // Bring toolbar to front
        if let toolbar = toolbarHosting {
            view.bringSubviewToFront(toolbar.view)
        }
        
        print("✅ Suggestions view shown")
        
        // Track state
        lastVisiblePicker = .suggestions
    }
    
    private func hideSuggestionsView() {
        guard let hosting = suggestionsHosting else { return }
        
        // CRITICAL: Only clear state if NOT restoring
        if !isRestoringPicker {
            lastVisiblePicker = .none
            
            // ✅ Clear active states for Reply and Rewrite buttons when suggestions close
            updateToolbarButtonState(.reply, isActive: false)
            updateToolbarButtonState(.rewrite, isActive: false)
        }
        
        hosting.willMove(toParent: nil)
        hosting.view.removeFromSuperview()
        hosting.removeFromParent()
        suggestionsHosting = nil
        
        // Reset state
        suggestionsViewModel.state = .idle
        suggestionsViewModel.suggestions = []
        suggestionsViewModel.lastOperation = nil
        
        print("✅ Suggestions view hidden")
    }
    
    // MARK: - Tone Picker Management
    
    private func handleToneButtonTap() {
        print("🎨 Tone button tapped")
        
        // ✅ Check if Tone picker is already open (toggle off)
        if tonePickerHosting != nil {
            // Same button pressed - toggle off
            hideTonePicker()
            updateToolbarButtonState(.tone, isActive: false)
            print("✅ Tone picker closed (toggle off)")
            return
        }
        
        // ✅ Different button or no view open - direct switch
        _ = refreshCurrentTextForPickers()
        
        // Close any active view
        closeAnyActiveView()
        
        // Show tone picker
        showTonePicker()
        updateToolbarButtonState(.tone, isActive: true)
        print("✅ Tone picker opened (direct switch)")
    }
    
    private func showTonePicker() {
        guard tonePickerHosting == nil else { return }
        
        // Reload latest length preference before showing picker
        savedLengthPreference = loadSavedLengthPreference()
        
        if suggestionsHosting != nil {
            hideSuggestionsView()
        }
        if lengthPickerHosting != nil {
            hideLengthPicker()
        }
        if menuPickerHosting != nil {
            hideMenuPicker()
        }
        if clipboardHistoryHosting != nil {
            hideClipboardHistory()
        }
        
        let hasTextContent = !currentTextForTone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        let tonePickerView = TonePickerView(
            onApply: { [weak self] selectedTones in
                self?.applyTones(selectedTones)
            },
            onSave: { [weak self] selectedToneIDs in
                self?.saveTonePreferences(selectedToneIDs)
            },
            onCancel: { [weak self] in
                self?.hideTonePicker()
            },
            onClear: { [weak self] in
                self?.clearSavedTonePreferences()  // ✅ CALL DIRECTLY, NO DISMISS
            },
            savedPreferences: savedTonePreferences,
            hasTextContent: hasTextContent,
            showDoneButton: false
        )
        
        let hosting = UIHostingController(rootView: tonePickerView)
        hosting.view.backgroundColor = UIColor.clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        
        addChild(hosting)
        view.addSubview(hosting.view)
        
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor, constant: 44),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        hosting.didMove(toParent: self)
        tonePickerHosting = hosting
        
        view.bringSubviewToFront(hosting.view)
        
        if let toolbar = toolbarHosting {
            view.bringSubviewToFront(toolbar.view)
        }
        
        print("✅ Tone picker shown (toolbar stays expanded)")
        
        // Track state
        lastVisiblePicker = .tonePicker
    }
    
    private func hideTonePicker() {
        guard let hosting = tonePickerHosting else { return }
        
        // CRITICAL: Only clear state if NOT restoring
        if !isRestoringPicker {
            lastVisiblePicker = .none
            updateToolbarButtonState(.tone, isActive: false)
        }
        
        hosting.willMove(toParent: nil)
        hosting.view.removeFromSuperview()
        hosting.removeFromParent()
        tonePickerHosting = nil
        
        currentTextForTone = ""
        
        print("✅ Tone picker hidden (toolbar stays expanded)")
    }
    
    private func saveTonePreferences(_ toneIDs: [String]) {
        guard let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) else {
            print("❌ Cannot access App Group for saving tone preferences")
            return
        }
        
        savedTonePreferences = toneIDs
        defaults.set(toneIDs, forKey: "SavedTonePreferences")
        
        print("✅ Saved tone preferences: \(toneIDs)")
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func loadSavedTonePreferences() -> [String] {
        guard let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) else {
            print("❌ Cannot access App Group for loading tone preferences")
            return []
        }
        
        let saved = defaults.stringArray(forKey: "SavedTonePreferences") ?? []
        print("📖 Loaded saved tone preferences: \(saved)")
        return saved
    }
    
    private func clearSavedTonePreferences() {
        guard let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) else { return }
        
        defaults.removeObject(forKey: "SavedTonePreferences")
        savedTonePreferences = []
        
        print("🗑️ Cleared saved tone preferences")
    }
    
    private func applyTones(_ tones: [String]) {
        print("🎨 Applying tones: \(tones.joined(separator: ", "))")
        
        let textToChange = currentTextForTone
        
        hideTonePicker()
        
        if suggestionsHosting == nil {
            showSuggestionsView()
        }
        
        suggestionsViewModel.lastOperation = .toneChange(text: textToChange, tones: tones)
        
        applyTonesToText(textToChange, tones: tones)
    }
    
    private func applyTonesToText(_ text: String, tones: [String]) {
        let isGenerateMore = !suggestionsViewModel.suggestions.isEmpty
        
        if isGenerateMore {
            suggestionsViewModel.state = .loadingMore
        } else {
            suggestionsViewModel.state = .loading
            suggestionsViewModel.suggestions = []
            suggestionBatchCount = 0
        }
        
        Task {
            do {
                let alternatives = try await KeyboardAIService.shared.changeTone(of: text, to: tones)
                
                await MainActor.run {
                    let newSuggestions = alternatives.enumerated().map { index, text in
                        KeyboardSuggestion(
                            text: text,
                            index: suggestionBatchCount * 2 + index
                        )
                    }
                    
                    if isGenerateMore {
                        suggestionsViewModel.suggestions.insert(contentsOf: newSuggestions, at: 0)
                        print("✅ Tone applied - prepended \(newSuggestions.count) suggestions (total: \(suggestionsViewModel.suggestions.count))")
                    } else {
                        suggestionsViewModel.suggestions = newSuggestions
                        print("✅ Tone applied - initial \(newSuggestions.count) suggestions")
                    }
                    
                    suggestionBatchCount += 1
                    suggestionsViewModel.state = .success(suggestionsViewModel.suggestions)
                    
                    print("✅ Tone applied successfully - \(alternatives.count) alternatives")
                }
            } catch {
                await MainActor.run {
                    print("❌ Tone change failed: \(error)")
                    let message = (error as? KeyboardAIError)?.errorDescription ?? "Failed to change tone"
                    suggestionsViewModel.state = .error(message)
                }
            }
        }
    }
    
    // MARK: - Length Picker Management
    
    private func handleLengthButtonTap() {
        print("📏 Length button tapped")
        
        // ✅ Check if Length picker is already open (toggle off)
        if lengthPickerHosting != nil {
            // Same button pressed - toggle off
            hideLengthPicker()
            updateToolbarButtonState(.length, isActive: false)
            print("✅ Length picker closed (toggle off)")
            return
        }
        
        // ✅ Different button or no view open - direct switch
        // Close any active view
        closeAnyActiveView()
        
        // Show length picker
        showLengthPicker()
        updateToolbarButtonState(.length, isActive: true)
        print("✅ Length picker opened (direct switch)")
    }
    
    private func showLengthPicker() {
        guard lengthPickerHosting == nil else { return }
        
        if suggestionsHosting != nil {
            hideSuggestionsView()
        }
        if tonePickerHosting != nil {
            hideTonePicker()
        }
        if menuPickerHosting != nil {
            hideMenuPicker()
        }
        if clipboardHistoryHosting != nil {
            hideClipboardHistory()
        }
        
        // ✅ ALWAYS re-read current text from proxy right before building the view
        let context = getTextContext()
        currentTextForTone = context.textToImprove
        let hasTextContent = !currentTextForTone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        let lengthPickerView = LengthPickerView(
            onApply: { [weak self] selectedLength in
                self?.applyLength(selectedLength)
            },
            onSave: { [weak self] selectedLengthID in
                self?.saveLengthPreference(selectedLengthID)
            },
            onCancel: { [weak self] in
                self?.hideLengthPicker()
            },
            onClear: { [weak self] in
                self?.clearSavedLengthPreference()
            },
            savedPreference: savedLengthPreference,
            hasTextContent: hasTextContent,
            showDoneButton: false
        )
        
        let hosting = UIHostingController(rootView: lengthPickerView)
        hosting.view.backgroundColor = UIColor.clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        
        addChild(hosting)
        view.addSubview(hosting.view)
        
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor, constant: 44),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        hosting.didMove(toParent: self)
        lengthPickerHosting = hosting
        
        view.bringSubviewToFront(hosting.view)
        
        if let toolbar = toolbarHosting {
            view.bringSubviewToFront(toolbar.view)
        }
        
        print("✅ Length picker shown (toolbar stays expanded)")
        
        lastVisiblePicker = .lengthPicker
    }
    
    private func hideLengthPicker() {
        guard let hosting = lengthPickerHosting else { return }
        
        if !isRestoringPicker {
            lastVisiblePicker = .none
            updateToolbarButtonState(.length, isActive: false)
        }
        
        hosting.willMove(toParent: nil as UIViewController?)
        hosting.view.removeFromSuperview()
        hosting.removeFromParent()
        lengthPickerHosting = nil
        
        print("✅ Length picker hidden (toolbar stays expanded)")
    }
    
    private func saveLengthPreference(_ lengthID: String) {
        guard let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) else {
            print("❌ Cannot access App Group for saving length preference")
            return
        }
        
        savedLengthPreference = lengthID
        defaults.set(lengthID, forKey: "SavedLengthPreference")
        
        print("✅ Saved length preference: \(lengthID)")
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func loadSavedLengthPreference() -> String? {
        guard let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) else {
            print("❌ Cannot access App Group for loading length preference")
            return nil
        }
        
        // Force sync to ensure we get latest value
        defaults.synchronize()
        
        let saved = defaults.string(forKey: "SavedLengthPreference")
        return saved
    }
    
    private func startLengthSyncTimer() {
        // Stop existing timer if any
        lengthSyncTimer?.invalidate()
        
        // Poll for length changes every 0.5 seconds (matches TonePicker)
        lengthSyncTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Reload length from App Groups
            let previousLength = self.savedLengthPreference
            let newLength = self.loadSavedLengthPreference()
            
            // Only update if changed (prevents unnecessary updates)
            if newLength != previousLength {
                self.savedLengthPreference = newLength
                if let unwrapped = newLength {
                    print("🔄 KeyboardVC synced length: \(unwrapped)")
                } else {
                    print("🔄 KeyboardVC cleared length")
                }
                
                // If Length picker is currently open, recreate it with new value
                if self.lengthPickerHosting != nil {
                    self.refreshLengthPicker()
                }
            }
        }
        
        print("✅ Started length sync timer (0.5s polling)")
    }
    
    private func refreshLengthPicker() {
        guard lengthPickerHosting != nil else { return }
        
        print("🔄 Refreshing Length picker with updated preference")
        
        // Save current state
        let wasOpen = true
        
        // Close and reopen with new state
        hideLengthPicker()
        
        // Small delay to ensure clean state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            if wasOpen {
                self.showLengthPicker()
            }
        }
    }
    
    private func clearSavedLengthPreference() {
        guard let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) else { return }
        
        defaults.removeObject(forKey: "SavedLengthPreference")
        savedLengthPreference = nil
        
        print("🗑️ Cleared saved length preference")
    }
    
    private func applyLength(_ length: String) {
        print("📏 Applying length: \(length)")
        
        let textToChange = currentTextForTone
        
        hideLengthPicker()
        
        if suggestionsHosting == nil {
            showSuggestionsView()
        }
        
        let toneTitles = savedTonePreferences.compactMap { toneMapping[$0] }
        
        suggestionsViewModel.lastOperation = .lengthChange(
            text: textToChange,
            length: length,
            tones: toneTitles.isEmpty ? nil : toneTitles
        )
        
        applyLengthToText(textToChange, length: length, tones: toneTitles.isEmpty ? nil : toneTitles)
    }
    
    private func applyLengthToText(_ text: String, length: String, tones: [String]?) {
        let isGenerateMore = !suggestionsViewModel.suggestions.isEmpty
        
        if isGenerateMore {
            suggestionsViewModel.state = .loadingMore
        } else {
            suggestionsViewModel.state = .loading
            suggestionsViewModel.suggestions = []
            suggestionBatchCount = 0
        }
        
        Task {
            do {
                let alternatives = try await KeyboardAIService.shared.changeLength(of: text, to: length, withTones: tones)
                
                await MainActor.run {
                    let newSuggestions = alternatives.enumerated().map { index, text in
                        KeyboardSuggestion(
                            text: text,
                            index: suggestionBatchCount * 2 + index
                        )
                    }
                    
                    if isGenerateMore {
                        suggestionsViewModel.suggestions.insert(contentsOf: newSuggestions, at: 0)
                        print("✅ Length applied - prepended \(newSuggestions.count) suggestions (total: \(suggestionsViewModel.suggestions.count))")
                    } else {
                        suggestionsViewModel.suggestions = newSuggestions
                        print("✅ Length applied - initial \(newSuggestions.count) suggestions")
                    }
                    
                    suggestionBatchCount += 1
                    suggestionsViewModel.state = .success(suggestionsViewModel.suggestions)
                    
                    print("✅ Length applied successfully - \(alternatives.count) alternatives")
                }
            } catch {
                await MainActor.run {
                    print("❌ Length change failed: \(error)")
                    let message = (error as? KeyboardAIError)?.errorDescription ?? "Failed to change length"
                    suggestionsViewModel.state = .error(message)
                }
            }
        }
    }
    
    // MARK: - Photo Generation
    
    private func generateMoreFromPhoto(photos: [String], context: String?, previousMessages: [String] = [], tones: [String]?, length: String?) {
        let isGenerateMore = !suggestionsViewModel.suggestions.isEmpty
        
        if isGenerateMore {
            suggestionsViewModel.state = .loadingMore
        } else {
            suggestionsViewModel.state = .loading
            suggestionsViewModel.suggestions = []
            suggestionBatchCount = 0
        }
        
        Task {
            do {
                let toneTitles = tones ?? savedTonePreferences.compactMap { toneMapping[$0] }
                let lengthValue = length ?? savedLengthPreference ?? "Medium"
                
                let alternatives = try await KeyboardAIService.shared.generateMoreFromPhoto(
                    photos: photos,
                    context: context ?? "",
                    previousMessages: previousMessages,
                    tones: toneTitles.isEmpty ? nil : toneTitles,
                    length: lengthValue
                )
                
                await MainActor.run {
                    let newSuggestions = alternatives.enumerated().map { index, text in
                        KeyboardSuggestion(
                            text: text,
                            index: suggestionBatchCount * 2 + index
                        )
                    }
                    
                    if isGenerateMore {
                        suggestionsViewModel.suggestions.insert(contentsOf: newSuggestions, at: 0)
                        print("✅ Photo generation - prepended \(newSuggestions.count) suggestions (total: \(suggestionsViewModel.suggestions.count))")
                    } else {
                        suggestionsViewModel.suggestions = newSuggestions
                        print("✅ Photo generation - initial \(newSuggestions.count) suggestions")
                    }
                    
                    suggestionBatchCount += 1
                    suggestionsViewModel.state = .success(suggestionsViewModel.suggestions)
                    
                    suggestionsViewModel.lastOperation = .photoGeneration(
                        photos: photos,
                        context: context ?? "",
                        tones: toneTitles.isEmpty ? nil : toneTitles,
                        length: lengthValue
                    )
                    
                    print("✅ Photo generation completed - \(alternatives.count) alternatives")
                }
            } catch {
                await MainActor.run {
                    print("❌ Photo generation failed: \(error)")
                    let message = (error as? KeyboardAIError)?.errorDescription ?? "Failed to generate from photo"
                    suggestionsViewModel.state = .error(message)
                }
            }
        }
    }
    
    // MARK: - Menu Picker Management
    
    private func handleMenuButtonTap() {
        print("📋 Menu button tapped")
        
        // ✅ Check if Menu picker is already open (toggle off)
        if menuPickerHosting != nil {
            // Same button pressed - toggle off
            hideMenuPicker()
            updateToolbarButtonState(.menu, isActive: false)
            print("✅ Menu picker closed (toggle off)")
            return
        }
        
        // ✅ Different button or no view open - direct switch
        // Close any active view
        closeAnyActiveView()
        
        // Show menu picker
        showMenuPicker()
        updateToolbarButtonState(.menu, isActive: true)
        print("✅ Menu picker opened (direct switch)")
    }
    
    private func showMenuPicker() {
        guard menuPickerHosting == nil else { return }
        
        if suggestionsHosting != nil { hideSuggestionsView() }
        if tonePickerHosting != nil { hideTonePicker() }
        if lengthPickerHosting != nil { hideLengthPicker() }
        if clipboardHistoryHosting != nil { hideClipboardHistory() }
        
        let menuPickerView = MenuPickerView(
            onPaste: { [weak self] in
                self?.handlePasteAction()
            },
            onClipboard: { [weak self] in
                self?.handleClipboardAction()
            },
            onSettings: { [weak self] in
                self?.handleSettingsAction()
            },
            onCancel: { [weak self] in
                self?.hideMenuPicker()
            },
            onUpload: { [weak self] in
                self?.handleUploadButtonTap()
            },
            onReply: { [weak self] in
                self?.handleReplyButtonTap()
            },
            onRewrite: { [weak self] in
                self?.handleRewriteButtonTap()
            },
            onTone: { [weak self] in
                self?.handleToneButtonTap()
            },
            onLength: { [weak self] in
                self?.handleLengthButtonTap()
            }
        )
        
        let hosting = UIHostingController(rootView: menuPickerView)
        hosting.view.backgroundColor = UIColor.clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        
        addChild(hosting)
        view.addSubview(hosting.view)
        
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor, constant: 44),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        hosting.didMove(toParent: self)
        menuPickerHosting = hosting
        
        view.bringSubviewToFront(hosting.view)
        
        if let toolbar = toolbarHosting {
            view.bringSubviewToFront(toolbar.view)
        }
        
        print("✅ Menu picker shown")
        
        lastVisiblePicker = .menuPicker
    }
    
    private func hideMenuPicker() {
        guard let hosting = menuPickerHosting else { return }
        
        if !isRestoringPicker {
            lastVisiblePicker = .none
            updateToolbarButtonState(.menu, isActive: false)
        }
        
        hosting.willMove(toParent: nil)
        hosting.view.removeFromSuperview()
        hosting.removeFromParent()
        menuPickerHosting = nil
        
        print("✅ Menu picker hidden")
    }
    
    private func handlePasteAction() {
        // Immediately set Save button to active
        updateToolbarButtonState(.save, isActive: true)
        
        // Clear active state after ~0.4s (always clear, success or fail)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.updateToolbarButtonState(.save, isActive: false)
        }
        
        // Check if clipboard is empty before saving
        let pasteboard = UIPasteboard.general
        let hasImage = pasteboard.image != nil
        let hasText = pasteboard.string?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        
        if !hasImage && !hasText {
            // Clipboard is empty
            showStatusBanner(message: "Clipboard is empty. Copy something first.")
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            print("⚠️ Clipboard is empty")
            return
        }
        
        // Clipboard has content, try to save
        let saved = ClipboardManager.shared.saveCurrentClipboard()
        
        if saved {
            hideMenuPicker()
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            showStatusBanner(message: "Saved to Wand clipboard")
            print("✅ Saved to Wand clipboard")
        } else {
            // Duplicate or other failure
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            
            print("⚠️ Could not save to clipboard (empty or duplicate)")
        }
    }
    
    private func handleClipboardAction() {
        // Toggle behavior: if already open, close it
        if clipboardHistoryHosting != nil {
            hideClipboardHistory()
            updateToolbarButtonState(.clipboard, isActive: false)
            return
        }
        
        // Otherwise, open clipboard history
        hideMenuPicker()
        closeAnyActiveView()
        showClipboardHistory()
        updateToolbarButtonState(.clipboard, isActive: true)
    }
    
    // MARK: - Clipboard History Management
    
    private func showClipboardHistory() {
        guard clipboardHistoryHosting == nil else { return }
        
        if suggestionsHosting != nil { hideSuggestionsView() }
        if tonePickerHosting != nil { hideTonePicker() }
        if lengthPickerHosting != nil { hideLengthPicker() }
        if menuPickerHosting != nil { hideMenuPicker() }
        
        let clipboardView = ClipboardHistoryView(
            onPaste: { [weak self] clip in
                self?.pasteClipFromHistory(clip)
            },
            onClose: { [weak self] in
                self?.hideClipboardHistory()
            }
        )
        
        let hosting = UIHostingController(rootView: clipboardView)
        hosting.view.backgroundColor = UIColor.clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        
        addChild(hosting)
        view.addSubview(hosting.view)
        
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor, constant: 44),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        hosting.didMove(toParent: self)
        clipboardHistoryHosting = hosting
        
        view.bringSubviewToFront(hosting.view)
        
        if let toolbar = toolbarHosting {
            view.bringSubviewToFront(toolbar.view)
        }
        
        print("✅ Clipboard history shown")
        
        lastVisiblePicker = .clipboardHistory
    }
    
    private func hideClipboardHistory() {
        guard let hosting = clipboardHistoryHosting else { return }
        
        if !isRestoringPicker {
            lastVisiblePicker = .none
            // Clear clipboard active state when not restoring
            updateToolbarButtonState(.clipboard, isActive: false)
        }
        
        hosting.willMove(toParent: nil)
        hosting.view.removeFromSuperview()
        hosting.removeFromParent()
        clipboardHistoryHosting = nil
        
        print("✅ Clipboard history hidden")
    }
    
    private func pasteClipFromHistory(_ clip: ClipboardItem) {
        switch clip.type {
        case .text:
            if let text = clip.textContent {
                textDocumentProxy.insertText(text)
                print("✅ Pasted text: \(text.prefix(50))...")
            }
            
        case .image:
            if let imageFilename = clip.imageFilename,
               let imageURL = ClipboardManager.shared.getImageURL(filename: imageFilename) {
                
                if let imageData = try? Data(contentsOf: imageURL) {
                    UIPasteboard.general.setData(imageData, forPasteboardType: "public.png")
                    print("✅ Pasted image to clipboard: \(imageFilename)")
                }
            }
        }
        
        hideClipboardHistory()
        triggerHaptic(style: .medium)
    }
    
    private func handleSettingsAction() {
        print("⚙️ Settings action tapped - opening main app")
        
        guard hasFullAccess else {
            print("⚠️ No Full Access")
            showFullAccessAlert()
            return
        }
        
        let urlString = "socialwand://settings"
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return
        }
        
        print("🔵 Opening settings via responder chain: \(url)")
        
        var responder: UIResponder? = self
        var didOpen = false
        
        while let currentResponder = responder {
            if let application = currentResponder as? UIApplication {
                print("✅ Found UIApplication!")
                application.open(url, options: [:], completionHandler: nil)
                didOpen = true
                
                triggerHaptic(style: .medium)
                
                print("✅ App should be opening settings now!")
                break
            }
            
            let openSelector = #selector(UIApplication.open(_:options:completionHandler:))
            if currentResponder.responds(to: openSelector) {
                let options: [UIApplication.OpenExternalURLOptionsKey : Any] = [:]
                let performSelector = NSSelectorFromString("open:options:completionHandler:")
                
                if let method = class_getInstanceMethod(type(of: currentResponder), performSelector) {
                    typealias OpenURLFunction = @convention(c) (AnyObject, Selector, URL, [UIApplication.OpenExternalURLOptionsKey : Any], ((Bool) -> Void)?) -> Void
                    let implementation = method_getImplementation(method)
                    let function = unsafeBitCast(implementation, to: OpenURLFunction.self)
                    function(currentResponder, performSelector, url, options, nil)
                    didOpen = true
                    
                    triggerHaptic(style: .medium)
                    
                    break
                }
            }
            
            responder = currentResponder.next
        }
        
        if didOpen {
            hideMenuPicker()
            print("✅ SUCCESS - Settings opening!")
        } else {
            print("❌ FAILED - Could not open settings")
        }
    }
    
    // MARK: - Upload Button Handling
    
    private func handleUploadButtonTap() {
        print("🔵 Upload button tapped!")
        
        // ✅ Close any active views before opening upload flow
        closeAnyActiveView()
        
        // Set active state for visual feedback
        updateToolbarButtonState(.upload, isActive: true)
        
        guard hasFullAccess else {
            print("⚠️ No Full Access - showing alert")
            showFullAccessAlert()
            // Clear active state if access denied
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.updateToolbarButtonState(.upload, isActive: false)
            }
            return
        }
        
        print("✅ Has Full Access")
        
        guard let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) else {
            print("❌ Failed to access App Group")
            return
        }
        
        let sourceApp = "instagram"
        defaults.set(true, forKey: "PendingPhotoUpload")
        defaults.set(sourceApp, forKey: "PhotoUploadSourceApp")
        defaults.set(Date(), forKey: "PhotoUploadRequestTime")
        defaults.synchronize()
        
        print("✅ Saved photo upload request to App Group")
        print("   - PendingPhotoUpload: \(defaults.bool(forKey: "PendingPhotoUpload"))")
        print("   - PhotoUploadSourceApp: \(defaults.string(forKey: "PhotoUploadSourceApp") ?? "nil")")
        print("   - PhotoUploadRequestTime: \(defaults.object(forKey: "PhotoUploadRequestTime") ?? "nil")")
        
        let urlString = "socialwand://upload?source=\(sourceApp)"
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            showUploadInstructionBanner()
            return
        }
        
        print("🔵 Attempting to open URL via responder chain: \(url)")
        
        var responder: UIResponder? = self
        var didOpen = false
        
        while let currentResponder = responder {
            print("🔍 Checking responder: \(type(of: currentResponder))")
            
            if let application = currentResponder as? UIApplication {
                print("✅ Found UIApplication!")
                
                print("🚀 Calling open:options:completionHandler: on UIApplication")
                application.open(url, options: [:], completionHandler: nil)
                didOpen = true
                
                triggerHaptic(style: .medium)
                
                print("✅ App should be opening now via MODERN API!")
                break
            }
            
            let openSelector = #selector(UIApplication.open(_:options:completionHandler:))
            if currentResponder.responds(to: openSelector) {
                print("🔵 Found responder that responds to open:options:completionHandler:")
                
                let options: [UIApplication.OpenExternalURLOptionsKey : Any] = [:]
                let performSelector = NSSelectorFromString("open:options:completionHandler:")
                
                if let method = class_getInstanceMethod(type(of: currentResponder), performSelector) {
                    typealias OpenURLFunction = @convention(c) (AnyObject, Selector, URL, [UIApplication.OpenExternalURLOptionsKey : Any], ((Bool) -> Void)?) -> Void
                    let implementation = method_getImplementation(method)
                    let function = unsafeBitCast(implementation, to: OpenURLFunction.self)
                    function(currentResponder, performSelector, url, options, nil)
                    didOpen = true
                    
                    triggerHaptic(style: .medium)
                    
                    print("✅ Called open:options:completionHandler: on \(type(of: currentResponder))")
                    break
                }
            }
            
            responder = currentResponder.next
        }
        
        if didOpen {
            print("✅ SUCCESS - App opening via responder chain with MODERN API!")
            print("📝 Keyboard will be killed by iOS - main app will handle photo selection")
            // Clear active state after a short delay (app will open)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.updateToolbarButtonState(.upload, isActive: false)
            }
        } else {
            print("❌ FAILED - Could not find UIApplication or suitable responder in chain")
            print("⚠️ Showing fallback instruction banner")
            showUploadInstructionBanner()
            // Clear active state if failed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.updateToolbarButtonState(.upload, isActive: false)
            }
        }
    }
    
    private func detectSourceApp() -> String? {
        return "instagram"
    }
    
    private func showFullAccessAlert() {
        let banner = ErrorBannerView(message: "Full Access required for photo upload")
        banner.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(banner)
        
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: view.topAnchor, constant: 52),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            banner.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    private func showUploadInstructionBanner() {
        let banner = ErrorBannerView(message: "📸 Open Social Wand app to upload photos", backgroundColor: UIColor.systemPurple.withAlphaComponent(0.9))
        banner.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(banner)
        
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: view.topAnchor, constant: 52),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            banner.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // MARK: - Banner Detection
    
    private func checkForPendingSuggestion() {
        guard hasFullAccess else { return }
        
        if SharedSuggestionData.hasNewSuggestion() {
            hasPendingSuggestion = true
            showSuggestionBanner()
            expandToolbar()
        }
    }
    
    private func showSuggestionBanner() {
        suggestionBanner?.removeFromSuperview()
        
        let banner = SuggestionBannerView()
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.onTap = { [weak self] in
            self?.handleBannerTap()
        }
        banner.onClose = { [weak self] in
            self?.suggestionBanner?.removeFromSuperview()
            self?.suggestionBanner = nil
            self?.hasPendingSuggestion = false
            SharedSuggestionData.markAsConsumed()
        }
        
        view.addSubview(banner)
        
        let toolbarHeight: CGFloat = 44.0
        let xButtonWidth: CGFloat = 44.0
        let horizontalPadding: CGFloat = 8.0
        let gapAfterXButton: CGFloat = 12.0
        let bannerTrailingPadding: CGFloat = 12.0
        
        let bannerLeadingOffset = horizontalPadding + xButtonWidth + gapAfterXButton
        
        let bannerHeight: CGFloat = 32.0
        let bannerTopOffset = (toolbarHeight - bannerHeight) / 2.0
        
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: view.topAnchor, constant: bannerTopOffset),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: bannerLeadingOffset),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -bannerTrailingPadding),
            banner.heightAnchor.constraint(equalToConstant: bannerHeight)
        ])
        
        suggestionBanner = banner
        
        view.bringSubviewToFront(banner)
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // MARK: - Status Banner
    
    private func showStatusBanner(message: String, duration: TimeInterval = 2.0) {
        // Remove any existing status banner
        statusBanner?.removeFromSuperview()
        statusBanner = nil
        
        // Create new status banner with custom message
        let banner = SuggestionBannerView(message: message)
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.onClose = { [weak self] in
            self?.statusBanner?.removeFromSuperview()
            self?.statusBanner = nil
        }
        
        view.addSubview(banner)
        
        // Use same constraints as suggestion banner
        let toolbarHeight: CGFloat = 44.0
        let xButtonWidth: CGFloat = 44.0
        let horizontalPadding: CGFloat = 8.0
        let gapAfterXButton: CGFloat = 12.0
        let bannerTrailingPadding: CGFloat = 12.0
        
        let bannerLeadingOffset = horizontalPadding + xButtonWidth + gapAfterXButton
        
        let bannerHeight: CGFloat = 32.0
        let bannerTopOffset = (toolbarHeight - bannerHeight) / 2.0
        
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: view.topAnchor, constant: bannerTopOffset),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: bannerLeadingOffset),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -bannerTrailingPadding),
            banner.heightAnchor.constraint(equalToConstant: bannerHeight)
        ])
        
        statusBanner = banner
        
        view.bringSubviewToFront(banner)
        
        // Auto-dismiss after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self, self.statusBanner === banner else { return }
            self.statusBanner?.removeFromSuperview()
            self.statusBanner = nil
        }
    }
    
    private func handleBannerTap() {
        guard let data = SharedSuggestionData.retrieve() else { return }
        
        insertSuggestion(data.suggestion)
        
        suggestionBanner?.removeFromSuperview()
        suggestionBanner = nil
        hasPendingSuggestion = false
        
        SharedSuggestionData.markAsConsumed()
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func insertSuggestion(_ text: String) {
        textDocumentProxy.insertText(text)
    }
    
    private func expandToolbar() {
        NotificationCenter.default.post(name: NSNotification.Name("ExpandToolbar"), object: nil)
    }
    
    // MARK: - Haptic Feedback Helper
    
    // MARK: - Haptic Feedback Helper
    
    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        HapticHelper.triggerHaptic(style: style)
    }
    
    private func triggerScrollHaptic() {
        HapticHelper.triggerScrollHaptic()
    }
    
    // MARK: - Text Insertion
    
    private func applySuggestion(_ text: String) {
        let context = getTextContext()
        
        if context.hasSelection, let selected = context.selectedText {
            for _ in 0..<selected.count {
                textDocumentProxy.deleteBackward()
            }
            textDocumentProxy.insertText(text)
            print("✅ Replaced selected text: \"\(selected)\"")
        } else {
            if let fullText = textDocumentProxy.documentContextBeforeInput {
                for _ in 0..<fullText.count {
                    textDocumentProxy.deleteBackward()
                }
            }
            textDocumentProxy.insertText(text)
            print("✅ Replaced all text")
        }
        
        hideSuggestionsView()
    }
    
    // MARK: - Existing Methods
    
    private func updateFullAccessFlag() {
        guard let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) else { return }
        defaults.set(hasFullAccess, forKey: SharedConstants.fullAccessKey)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateFullAccessFlag()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        updateFullAccessFlag()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        updateFullAccessFlag()
        
        // Stop length sync timer when keyboard disappears
        lengthSyncTimer?.invalidate()
        lengthSyncTimer = nil
        print("🛑 Stopped length sync timer")
    }
    
    override func textWillChange(_ textInput: UITextInput?) {
        super.textWillChange(textInput)
        updateFullAccessFlag()
    }
    
    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateFullAccessFlag()
    }
}

// MARK: - Custom Feedback Service

private final class CustomFeedbackService: FeedbackService {
    func triggerAudioFeedback(_ feedback: Feedback.Audio) {
        print("🔊 AUDIO TRIGGERED: \(feedback)")
        switch feedback {
        case .delete:
            SoundHelper.playDeleteSound()
        case .input:
            SoundHelper.playKeyTapSound()
        case .system:
            SoundHelper.playKeyTapSound()
        case .customId(let soundID):
            SoundHelper.playSystemSound(soundID)
        case .customUrl(let url):
            // Custom sound file - use default for now
            SoundHelper.playKeyTapSound()
        case .none:
            // No audio feedback
            break
        }
    }
    
    func triggerHapticFeedback(_ feedback: Feedback.Haptic) {
        print("📳 HAPTIC TRIGGERED: \(feedback)")
        
        // Check if haptics are enabled before triggering notification/selection haptics
        switch feedback {
        case .lightImpact:
            HapticHelper.triggerHaptic(style: .light)
        case .mediumImpact:
            HapticHelper.triggerHaptic(style: .medium)
        case .heavyImpact:
            HapticHelper.triggerHaptic(style: .heavy)
        case .success:
            guard HapticHelper.isHapticsEnabled() else { return }
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .warning:
            guard HapticHelper.isHapticsEnabled() else { return }
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        case .error:
            guard HapticHelper.isHapticsEnabled() else { return }
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        case .selectionChanged:
            guard HapticHelper.isHapticsEnabled() else { return }
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        case .none:
            // No haptic feedback
            break
        }
    }
}
