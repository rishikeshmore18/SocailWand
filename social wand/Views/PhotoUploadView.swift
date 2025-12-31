//
//  PhotoUploadView.swift
//  social wand
//

import SwiftUI

struct PhotoUploadView: View {
    enum UploadState {
        case pickingPhotos
        case addingContext
        case generating
        case success([[String]])  // ✅ CHANGED: Array of generations, each containing [safe, bold]
    }
    
    @State private var state: UploadState = .pickingPhotos
    @State private var selectedPhotos: [UIImage] = []
    @State private var context: String = ""
    @State private var errorMessage: String?
    @State private var showPhotoPicker = true
    @State private var selectedTones: [String] = []
    @State private var selectedLength: String? = nil
    @State private var showTonePicker = false
    @State private var showLengthPicker = false
    @State private var returnToApp: String = "Instagram"
    @State private var allGenerations: [[String]] = []  // ✅ NEW: Store all generations
    
    let sourceApp: String
    
    @Environment(\.dismiss) var dismiss
    
    init(sourceApp: String) {
        self.sourceApp = sourceApp
        self.returnToApp = sourceApp.capitalized
    }
    
    // Tone ID to Title mapping
    private let toneMapping: [String: String] = [
        "assertive": "Assertive",
        "confident": "Confident",
        "playful": "Playful",
        "empathetic": "Empathetic",
        "flirtatious": "Flirtatious",
        "professional": "Professional",
        "casual": "Casual"
    ]
    
    // Length ID to Title mapping
    private let lengthMapping: [String: String] = [
        "short": "Short",
        "medium": "Medium",
        "long": "Long"
    ]
    
    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .pickingPhotos:
                    photoPickerView
                case .addingContext:
                    contextView
                case .generating:
                    generatingView
                case .success(let allGenerations):
                    GenerationSuccessView(
                        allGenerations: allGenerations,
                        sourceApp: sourceApp,
                        onGenerateAnother: { regenerateCaption() },
                        onGoBack: { state = .addingContext },
                        onGoHome: { dismiss() }
                    )
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showTonePicker) { tonePickerSheet }
            .sheet(isPresented: $showLengthPicker) { lengthPickerSheet }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if case .success = state {
                        EmptyView()
                    } else {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .onAppear {
                resetIfStale()
                loadSavedPreferences()
            }
        }
    }
    
    private var navigationTitle: String {
        switch state {
        case .pickingPhotos: return "Select Photos"
        case .addingContext: return "Add Context"
        case .generating:    return "Generating..."
        case .success:       return "Success"
        }
    }

    private func loadSavedPreferences() {
        guard let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) else {
            print("⚠️ Cannot access App Group for loading preferences")
            return
        }
        if let savedTones = defaults.stringArray(forKey: "SavedTonePreferences"), !savedTones.isEmpty {
            selectedTones = savedTones
            print("✅ Loaded saved tones: \(savedTones)")
        }
        if let savedLength = defaults.string(forKey: "SavedLengthPreference") {
            selectedLength = savedLength
            print("✅ Loaded saved length: \(savedLength)")
        }
    }
    
    private var photoPickerView: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5)
                Text("Opening photo picker...")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .onAppear {
            print("📸 PhotoUploadView appeared - auto-opening picker")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showPhotoPicker = true
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(selectedPhotos: $selectedPhotos)
        }
        .onChange(of: selectedPhotos) { oldValue, newValue in
            if !newValue.isEmpty && oldValue.isEmpty {
                print("✅ PhotoUploadView: Photos loaded (\(newValue.count)), advancing to context screen")
                state = .addingContext
            } else if newValue.isEmpty && !oldValue.isEmpty {
                print("⚠️ PhotoUploadView: All photos removed, returning to picker")
                state = .pickingPhotos
            } else if newValue.isEmpty && oldValue.isEmpty && !showPhotoPicker {
                print("❌ PhotoUploadView: User canceled without selecting photos")
                dismiss()
            }
        }
    }
    
    private var contextView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    // 1. PHOTO SECTION
                    if !selectedPhotos.isEmpty {
                        photoPreviewGrid
                            .padding(.top, 20)
                            .padding(.bottom, 20)
                    }
                    
                    // 2. HEADING
                    HStack {
                        Text("Add Context (Optional)")
                            .font(.system(size: 17, weight: .semibold))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    
                    // 3. BUTTONS
                    HStack(spacing: 12) {
                        Button(action: { showTonePicker = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "waveform").font(.system(size: 14))
                                Text("Tone").font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(hex: "8B5CF6"))
                            .cornerRadius(10)
                        }
                        
                        Button(action: { showLengthPicker = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "text.alignleft").font(.system(size: 14))
                                Text("Length").font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(hex: "8B5CF6"))
                            .cornerRadius(10)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    
                    // ⭐ 3.5 NEW: PREFERENCES CONTAINER (FIXED WITH PROPER FLOWLAYOUT)
                    preferencesContainer
                    
                    // 4. TEXT FIELD
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("E.g., beach day, birthday party...", text: $context, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(8...12)
                            .frame(minHeight: 200)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // 5. ERROR MESSAGE
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                    }
                }
            }
            
            Spacer()
            
            // 6. GENERATE BUTTON
            Button(action: generateCaption) {
                Text("Generate")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "8B5CF6"), Color(hex: "7C3AED")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }
    
    // ⭐ FIXED: PREFERENCES CONTAINER (Using proper FlowLayout from Opus)
    @ViewBuilder
    private var preferencesContainer: some View {
        let hasPreferences = !selectedTones.isEmpty || selectedLength != nil
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected Preferences:")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            if hasPreferences {
                // ✅ PROPER FLOW LAYOUT (from Opus 4.5)
                FlowLayout(spacing: 8) {
                    // Tone chips
                    ForEach(selectedTones, id: \.self) { toneID in
                        PreferenceChip(
                            title: toneMapping[toneID] ?? toneID.capitalized,
                            onRemove: { removeTone(toneID) }
                        )
                    }
                    
                    // Length chip
                    if let lengthID = selectedLength {
                        PreferenceChip(
                            title: lengthMapping[lengthID] ?? lengthID.capitalized,
                            onRemove: { removeLength() }
                        )
                    }
                }
            } else {
                Text("No preferences selected")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
    
    private var photoPreviewGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(selectedPhotos.indices, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: selectedPhotos[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Button(action: {
                            selectedPhotos.remove(at: index)
                            if selectedPhotos.isEmpty { state = .pickingPhotos }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .offset(x: 8, y: -8)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var generatingView: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView().scaleEffect(1.5)
            Text("Analyzing photos...")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
            Text("This may take a few seconds")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private var tonePickerSheet: some View {
        NavigationStack {
            TonePickerView(
                onApply: { _ in },
                onSave: { handleToneSave($0) },
                onCancel: { showTonePicker = false },
                onClear: { handleToneClear() },
                savedPreferences: selectedTones,
                hasTextContent: false,
                showDoneButton: true
            )
            .navigationTitle("Choose Tone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { showTonePicker = false }
                }
            }
        }
    }
    
    private var lengthPickerSheet: some View {
        NavigationStack {
            LengthPickerView(
                onApply: { _ in },
                onSave: { handleLengthSave($0) },
                onCancel: { showLengthPicker = false },
                onClear: { handleLengthClear() },
                savedPreference: selectedLength,
                hasTextContent: false,
                showDoneButton: true
            )
            .navigationTitle("Choose Length")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { showLengthPicker = false }
                }
            }
        }
    }
    
    private func handleToneSave(_ toneIDs: [String]) {
        selectedTones = toneIDs
        if let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) {
            defaults.set(toneIDs, forKey: "SavedTonePreferences")
            print("✅ Saved tones: \(toneIDs)")
        }
    }
    
    private func handleToneClear() {
        selectedTones = []
        if let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) {
            defaults.removeObject(forKey: "SavedTonePreferences")
            print("✅ Cleared tone preferences")
        }
    }
    
    private func handleLengthSave(_ lengthID: String) {
        selectedLength = lengthID
        if let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) {
            defaults.set(lengthID, forKey: "SavedLengthPreference")
            print("✅ Saved length: \(lengthID)")
        }
    }
    
    private func handleLengthClear() {
        selectedLength = nil
        if let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) {
            defaults.removeObject(forKey: "SavedLengthPreference")
            print("✅ Cleared length preference")
        }
    }
    
    private func removeTone(_ toneID: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            selectedTones.removeAll { $0 == toneID }
        }
        
        if let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) {
            defaults.set(selectedTones, forKey: "SavedTonePreferences")
            print("✅ Removed tone: \(toneID)")
        }
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func removeLength() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            selectedLength = nil
        }
        
        if let defaults = UserDefaults(suiteName: SharedConstants.appGroupID) {
            defaults.removeObject(forKey: "SavedLengthPreference")
            print("✅ Removed length preference")
        }
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func generateCaption() {
        state = .generating
        errorMessage = nil
        
        Task {
            do {
                let compressedPhotos = try await compressPhotos(selectedPhotos)
                let toneMapping: [String: String] = [
                    "assertive": "Assertive",
                    "confident": "Confident",
                    "playful": "Playful",
                    "empathetic": "Empathetic",
                    "flirtatious": "Flirtatious",
                    "professional": "Professional",
                    "casual": "Casual"
                ]
                let toneTitles = selectedTones.compactMap { toneMapping[$0] }
                let lengthTitle = selectedLength != nil
                    ? (selectedLength!.prefix(1).uppercased() + selectedLength!.dropFirst())
                    : "Medium"
                
                let alternatives = try await callUploadAPI(
                    photos: compressedPhotos,
                    context: context.isEmpty ? nil : context,
                    tones: toneTitles.isEmpty ? nil : toneTitles,
                    length: lengthTitle
                )
                
                await MainActor.run {
                    // ✅ NEW: Prepend new generation to array
                    allGenerations.insert(alternatives, at: 0)
                    state = .success(allGenerations)
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to generate: \(error.localizedDescription)"
                    state = .addingContext
                }
            }
        }
    }
    
    private func compressPhotos(_ photos: [UIImage]) async throws -> [String] {
        var base64Photos: [String] = []
        for photo in photos {
            let resized = photo.resized(toMaxDimension: 1024)
            guard let jpegData = resized.jpegData(compressionQuality: 0.7) else {
                throw NSError(domain: "PhotoCompression", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress photo"])
            }
            let base64 = "data:image/jpeg;base64," + jpegData.base64EncodedString()
            base64Photos.append(base64)
        }
        return base64Photos
    }
    
    private func callUploadAPI(photos: [String], context: String?, tones: [String]?, length: String?) async throws -> [String] {
        #if DEBUG
        let baseURL = "http://192.168.1.248:3000"
        #else
        let baseURL = "https://your-production-url.com"
        #endif
        
        guard let url = URL(string: "\(baseURL)/api/upload") else {
            throw NSError(domain: "API", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "photos": photos,
            "context": context ?? "",
            "tones": tones ?? [],
            "length": length ?? "Medium"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "API", code: 2, userInfo: [NSLocalizedDescriptionKey: "Server error"])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        if let alternatives = json?["alternatives"] as? [String], alternatives.count >= 2 {
            return Array(alternatives.prefix(2))
        }
        
        if let result = json?["result"] as? String {
            let parts = result.split(separator: "|").map { String($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count >= 2 {
                return Array(parts.prefix(2))
            }
            return [result, result]
        }
        
        throw NSError(domain: "API", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
    }
    
    private func regenerateCaption() {
        state = .generating
        errorMessage = nil
        
        Task {
            do {
                let compressedPhotos = try await compressPhotos(selectedPhotos)
                let toneMapping: [String: String] = [
                    "assertive": "Assertive",
                    "confident": "Confident",
                    "playful": "Playful",
                    "empathetic": "Empathetic",
                    "flirtatious": "Flirtatious",
                    "professional": "Professional",
                    "casual": "Casual"
                ]
                let toneTitles = selectedTones.compactMap { toneMapping[$0] }
                let lengthTitle = selectedLength != nil
                    ? (selectedLength!.prefix(1).uppercased() + selectedLength!.dropFirst())
                    : "Medium"
                
                let alternatives = try await callUploadAPI(
                    photos: compressedPhotos,
                    context: context.isEmpty ? nil : context,
                    tones: toneTitles.isEmpty ? nil : toneTitles,
                    length: lengthTitle
                )
                
                await MainActor.run {
                    // ✅ NEW: Prepend new generation to array
                    allGenerations.insert(alternatives, at: 0)
                    state = .success(allGenerations)
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to generate: \(error.localizedDescription)"
                    state = .addingContext
                }
            }
        }
    }
    
    private func resetIfStale() {
        guard case .success = state else { return }
        print("🔄 PhotoUploadView reopened while in success state - resetting to picker")
        state = .pickingPhotos
        selectedPhotos = []
        context = ""
        allGenerations = []  // ✅ NEW: Reset generations when starting fresh
        errorMessage = nil
        showPhotoPicker = true
        print("✅ Reset complete - picker will appear")
    }
}

// MARK: - PreferenceChip Component

struct PreferenceChip: View {
    let title: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "8B5CF6").opacity(0.3), lineWidth: 1.5)
        )
    }
}

// MARK: - ⭐ WORKING: Flow Layout (from Opus 4.5)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            // Check if we need to wrap to next line
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }
        
        totalHeight = currentY + lineHeight
        
        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}

// MARK: - Helpers

extension UIImage {
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let size = self.size
        let aspectRatio = size.width / size.height
        var newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
