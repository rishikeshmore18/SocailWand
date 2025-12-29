//
//  ClipboardManager.swift
//  SocialWandKeyboard
//

import Foundation
import UIKit

// MARK: - Clipboard Item Model

struct ClipboardItem: Codable, Identifiable {
    let id: String
    let content: String
    let type: ClipboardItemType
    let timestamp: Date
    var isBookmarked: Bool
    
    enum ClipboardItemType: String, Codable {
        case text
        case image
    }
    
    init(content: String, type: ClipboardItemType, isBookmarked: Bool = false) {
        self.id = UUID().uuidString
        self.content = content
        self.type = type
        self.timestamp = Date()
        self.isBookmarked = isBookmarked
    }
}

// MARK: - Clipboard Manager

class ClipboardManager {
    static let shared = ClipboardManager()
    
    private let appGroupID = "group.rishi-more.social-wand"
    private let clipboardKey = "SavedClipboardItems"
    private let maxRegularItems = 15
    
    private init() {}
    
    // MARK: - Save Clip
    
    func saveCurrentClipboard() -> Bool {
        guard let content = UIPasteboard.general.string, !content.isEmpty else {
            print("⚠️ Clipboard is empty, nothing to save")
            return false
        }
        
        // Check if content already exists
        let existingClips = retrieveClips()
        if existingClips.contains(where: { $0.content == content }) {
            print("⚠️ Clip already saved")
            return false
        }
        
        let newClip = ClipboardItem(content: content, type: .text)
        var allClips = existingClips
        
        // Insert at beginning (newest first)
        allClips.insert(newClip, at: 0)
        
        // Enforce FIFO for non-bookmarked items
        let bookmarkedClips = allClips.filter { $0.isBookmarked }
        var regularClips = allClips.filter { !$0.isBookmarked }
        
        if regularClips.count > maxRegularItems {
            regularClips = Array(regularClips.prefix(maxRegularItems))
        }
        
        allClips = bookmarkedClips + regularClips
        
        return saveClips(allClips)
    }
    
    // MARK: - Retrieve Clips
    
    func retrieveClips() -> [ClipboardItem] {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: clipboardKey) else {
            return []
        }
        
        guard let clips = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            print("❌ Failed to decode clipboard items")
            return []
        }
        
        // Sort: bookmarked first, then regular by timestamp
        let bookmarked = clips.filter { $0.isBookmarked }.sorted { $0.timestamp > $1.timestamp }
        let regular = clips.filter { !$0.isBookmarked }.sorted { $0.timestamp > $1.timestamp }
        
        return bookmarked + regular
    }
    
    // MARK: - Toggle Bookmark
    
    func toggleBookmark(clipID: String) -> Bool {
        var clips = retrieveClips()
        
        guard let index = clips.firstIndex(where: { $0.id == clipID }) else {
            return false
        }
        
        clips[index].isBookmarked.toggle()
        
        return saveClips(clips)
    }
    
    // MARK: - Delete Clip
    
    func deleteClip(clipID: String) -> Bool {
        var clips = retrieveClips()
        clips.removeAll { $0.id == clipID }
        return saveClips(clips)
    }
    
    // MARK: - Clear All
    
    func clearAll() -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return false
        }
        defaults.removeObject(forKey: clipboardKey)
        return true
    }
    
    // MARK: - Private Helpers
    
    private func saveClips(_ clips: [ClipboardItem]) -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            print("❌ Cannot access App Group")
            return false
        }
        
        guard let data = try? JSONEncoder().encode(clips) else {
            print("❌ Failed to encode clipboard items")
            return false
        }
        
        defaults.set(data, forKey: clipboardKey)
        print("✅ Saved \(clips.count) clipboard items")
        return true
    }
}

