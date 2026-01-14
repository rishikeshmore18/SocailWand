//
//  ButtonOrderView.swift
//  social wand
//

import SwiftUI

struct ButtonOrderView: View {
    @Environment(\.dismiss) private var dismiss
    
    // All available buttons (Upload, Reply, Rewrite, Translate, Email, Tone, Length)
    @State private var buttonOrder: [ToolbarButtonItem] = []
    @State private var toolbarCount: Int = 4
    
    private let appGroupID = "group.com.rishimore.socialwand"
    private let toolbarCountKey = "ToolbarButtonCount"
    
    var body: some View {
        VStack(spacing: 0) {
            // Instructions
            VStack(spacing: 8) {
                Text("Drag to Reorder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Drag the divider to set Toolbar vs Menu")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 16)
            .padding(.bottom, 24)
            
            // Reorderable list
            List {
                ForEach(rowIDs, id: \.self) { rowID in
                    if rowID == dividerRowID {
                        separatorRow
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                    } else if let button = buttonOrder.first(where: { $0.id == rowID }) {
                        buttonRow(button)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .moveDisabled(button.id == "settings")
                    }
                }
                .onMove { from, to in
                    var updatedRowIDs = rowIDs
                    updatedRowIDs.move(fromOffsets: from, toOffset: to)

                    updatedRowIDs.removeAll { $0 == "settings" }
                    updatedRowIDs.append("settings")

                    toolbarCount = updatedRowIDs.firstIndex(of: dividerRowID) ?? 0

                    let lookup = Dictionary(uniqueKeysWithValues: buttonOrder.map { ($0.id, $0) })
                    let orderedButtons = updatedRowIDs.compactMap { lookup[$0] }
                    buttonOrder = enforceSettingsLast(orderedButtons)
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
                Text(index < toolbarCount ? "Toolbar" : "Menu")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(index < toolbarCount ? Color(hex: "8B5CF6") : .gray)
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
    
    private var dividerRowID: String {
        "toolbar-divider"
    }

    private var rowIDs: [String] {
        var ids = buttonOrder.map { $0.id }
        let clampedCount = min(max(toolbarCount, 0), ids.count)
        ids.insert(dividerRowID, at: clampedCount)
        return ids
    }

    private func loadButtonOrder() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            // Use default order if can't access App Group
            buttonOrder = defaultButtonOrder()
            toolbarCount = min(4, buttonOrder.count)
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

            buttonOrder = enforceSettingsLast(buttonOrder)
            
            print("📖 Loaded button order: \(buttonOrder.map { $0.label })")
        } else {
            // No saved order - use default
            buttonOrder = enforceSettingsLast(defaultButtonOrder())
            toolbarCount = min(4, buttonOrder.count)
            saveButtonOrder()  // Save default order
        }

        let storedCount = defaults.object(forKey: toolbarCountKey) as? Int
        toolbarCount = min(max(storedCount ?? 4, 0), buttonOrder.count)
    }
    
    private func saveButtonOrder() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            print("❌ Cannot save button order - no App Group access")
            return
        }

        let sanitizedOrder = enforceSettingsLast(buttonOrder)
        if sanitizedOrder != buttonOrder {
            buttonOrder = sanitizedOrder
        }

        let orderIDs = sanitizedOrder.map { $0.id }
        defaults.set(orderIDs, forKey: "ToolbarButtonOrder")
        defaults.set(toolbarCount, forKey: toolbarCountKey)
        defaults.synchronize()
        
        print("✅ Saved button order: \(buttonOrder.map { $0.label })")
        
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func defaultButtonOrder() -> [ToolbarButtonItem] {
        return [
            ToolbarButtonItem(id: "upload", label: "Upload Context", icon: "photo.on.rectangle"),
            ToolbarButtonItem(id: "reply", label: "Reply", icon: "arrowshape.turn.up.left"),
            ToolbarButtonItem(id: "rewrite", label: "Rewrite", icon: "pencil.line"),
            ToolbarButtonItem(id: "translate", label: "Translate", icon: "globe"),
            ToolbarButtonItem(id: "email", label: "Email", icon: "envelope"),
            ToolbarButtonItem(id: "tone", label: "Tone", icon: "waveform"),
            ToolbarButtonItem(id: "length", label: "Length", icon: "text.alignleft"),
            // ✅ NEW: Menu buttons (positions 5-7 by default)
            ToolbarButtonItem(id: "save", label: "Save to Clipboard", icon: "square.and.arrow.down"),
            ToolbarButtonItem(id: "clipboard", label: "Clipboard", icon: "list.clipboard"),
            ToolbarButtonItem(id: "settings", label: "Settings", icon: "gearshape")
        ]
    }

    private func enforceSettingsLast(_ order: [ToolbarButtonItem]) -> [ToolbarButtonItem] {
        var filtered = order.filter { $0.id != "settings" }
        if let settings = order.first(where: { $0.id == "settings" })
            ?? defaultButtonOrder().first(where: { $0.id == "settings" }) {
            filtered.append(settings)
        }
        return filtered
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
