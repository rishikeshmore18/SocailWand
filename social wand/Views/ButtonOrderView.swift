//
//  ButtonOrderView.swift
//  social wand
//

import SwiftUI

struct ButtonOrderView: View {
    @Environment(\.dismiss) private var dismiss
    
    // All available buttons (Upload, Reply, Rewrite, Tone, Length)
    @State private var buttonOrder: [ToolbarButtonItem] = []
    
    private let appGroupID = "group.rishi-more.social-wand"
    private let maxVisibleButtons = 4  // First 4 in toolbar, rest in menu
    
    var body: some View {
        VStack(spacing: 0) {
            // Instructions
            VStack(spacing: 8) {
                Text("Drag to Reorder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("First 4 buttons appear in toolbar\nRemaining buttons move to Menu")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 16)
            .padding(.bottom, 24)
            
            // Reorderable list
            List {
                ForEach(Array(buttonOrder.enumerated()), id: \.element.id) { index, button in
                    buttonRow(button)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    
                    // Insert separator after 4th button (index 3, 0-indexed)
                    if index == maxVisibleButtons - 1 && buttonOrder.count > maxVisibleButtons {
                        separatorRow
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                    }
                }
                .onMove { from, to in
                    buttonOrder.move(fromOffsets: from, toOffset: to)
                    saveButtonOrder()
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))  // Always in edit mode
            
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Button Order")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 17))
                    }
                    .foregroundStyle(Color(hex: "8B5CF6"))
                }
            }
        }
        .onAppear {
            loadButtonOrder()
        }
    }
    
    @ViewBuilder
    private func buttonRow(_ button: ToolbarButtonItem) -> some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.gray)
            
            // Icon
            Image(systemName: button.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "8B5CF6"))
                .frame(width: 24)
            
            // Label
            Text(button.label)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            // Location indicator
            if let index = buttonOrder.firstIndex(where: { $0.id == button.id }) {
                Text(index < maxVisibleButtons ? "Toolbar" : "Menu")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(index < maxVisibleButtons ? Color(hex: "8B5CF6") : .gray)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var separatorRow: some View {
        HStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
            
            Text("Toolbar ↑  |  Menu ↓")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
                .padding(.horizontal, 12)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
    }
    
    private func loadButtonOrder() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            // Use default order if can't access App Group
            buttonOrder = defaultButtonOrder()
            return
        }
        
        if let savedOrder = defaults.stringArray(forKey: "ToolbarButtonOrder") {
            // Map saved IDs to button items
            buttonOrder = savedOrder.compactMap { id in
                defaultButtonOrder().first(where: { $0.id == id })
            }
            
            // Add any missing buttons to end (in case new buttons were added)
            let savedIDs = Set(savedOrder)
            let missingButtons = defaultButtonOrder().filter { !savedIDs.contains($0.id) }
            buttonOrder.append(contentsOf: missingButtons)
            
            print("📖 Loaded button order: \(buttonOrder.map { $0.label })")
        } else {
            // No saved order - use default
            buttonOrder = defaultButtonOrder()
            saveButtonOrder()  // Save default order
        }
    }
    
    private func saveButtonOrder() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            print("❌ Cannot save button order - no App Group access")
            return
        }
        
        let orderIDs = buttonOrder.map { $0.id }
        defaults.set(orderIDs, forKey: "ToolbarButtonOrder")
        defaults.synchronize()
        
        print("✅ Saved button order: \(buttonOrder.map { $0.label })")
        
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func defaultButtonOrder() -> [ToolbarButtonItem] {
        return [
            ToolbarButtonItem(id: "upload", label: "Upload", icon: "photo.on.rectangle"),
            ToolbarButtonItem(id: "reply", label: "Reply", icon: "arrowshape.turn.up.left"),
            ToolbarButtonItem(id: "rewrite", label: "Rewrite", icon: "pencil.line"),
            ToolbarButtonItem(id: "tone", label: "Tone", icon: "waveform"),
            ToolbarButtonItem(id: "length", label: "Length", icon: "text.alignleft"),
            // ✅ NEW: Menu buttons (positions 5-7 by default)
            ToolbarButtonItem(id: "save", label: "Save", icon: "square.and.arrow.down"),
            ToolbarButtonItem(id: "clipboard", label: "Clipboard", icon: "list.clipboard"),
            ToolbarButtonItem(id: "settings", label: "Settings", icon: "gearshape")
        ]
    }
}

struct ToolbarButtonItem: Identifiable, Equatable {
    let id: String
    let label: String
    let icon: String
}

#Preview {
    NavigationStack {
        ButtonOrderView()
    }
}

