//
//  ClipboardManager.swift
//  SocialWandKeyboard
//

import Foundation
import UIKit

// MARK: - Clipboard Item Model

struct ClipboardItem: Codable, Identifiable {
    let id: String
    let type: ClipboardItemType
    let timestamp: Date
    var isBookmarked: Bool
    
    // For text items
    let textContent: String?
    
    // For image items (filenames only, not base64)
    let imageFilename: String?
    let thumbnailFilename: String?
    
    enum ClipboardItemType: String, Codable {
        case text
        case image
    }
    
    // Text item initializer
    init(text: String, isBookmarked: Bool = false) {
        self.id = UUID().uuidString
        self.type = .text
        self.timestamp = Date()
        self.isBookmarked = isBookmarked
        self.textContent = text
        self.imageFilename = nil
        self.thumbnailFilename = nil
    }
    
    // Image item initializer
    init(imageFilename: String, thumbnailFilename: String, isBookmarked: Bool = false) {
        self.id = UUID().uuidString
        self.type = .image
        self.timestamp = Date()
        self.isBookmarked = isBookmarked
        self.textContent = nil
        self.imageFilename = imageFilename
        self.thumbnailFilename = thumbnailFilename
    }
}

// MARK: - Clipboard Manager

class ClipboardManager {
    static let shared = ClipboardManager()
    
    private let appGroupID = "group.rishi-more.social-wand"
    private let clipboardKey = "SavedClipboardItems"
    private let maxTotalItems = 7  // Reduced from 15
    
    private init() {}
    
    // MARK: - File Paths
    
    private func clipboardDirectory() -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            print("❌ Cannot access App Group container")
            return nil
        }
        
        let clipboardDir = containerURL.appendingPathComponent("clipboard", isDirectory: true)
        
        // Create directory if doesn't exist
        if !FileManager.default.fileExists(atPath: clipboardDir.path) {
            try? FileManager.default.createDirectory(at: clipboardDir, withIntermediateDirectories: true)
        }
        
        return clipboardDir
    }
    
    // MARK: - Save Clip
    
    func saveCurrentClipboard() -> Bool {
        let pasteboard = UIPasteboard.general
        
        // Priority: Try image first, then text
        if let image = pasteboard.image {
            return saveImage(image)
        } else if let text = pasteboard.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return saveText(text)
        } else {
            print("⚠️ Clipboard is empty")
            return false
        }
    }
    
    private func saveText(_ text: String) -> Bool {
        var allClips = retrieveClips()
        
        // Check for duplicates
        if allClips.contains(where: { $0.type == .text && $0.textContent == text }) {
            print("⚠️ Text already saved")
            return false
        }
        
        let newClip = ClipboardItem(text: text)
        allClips.insert(newClip, at: 0)
        
        return enforceLimit(clips: &allClips) && saveClips(allClips)
    }
    
    private func saveImage(_ image: UIImage) -> Bool {
        guard let clipboardDir = clipboardDirectory() else { return false }
        
        let uuid = UUID().uuidString
        
        // 1. Save full-size image (never loaded by keyboard)
        let fullFilename = "image_\(uuid).png"
        let fullURL = clipboardDir.appendingPathComponent(fullFilename)
        
        guard let fullData = image.pngData() else {
            print("❌ Failed to convert image to PNG")
            return false
        }
        
        do {
            try fullData.write(to: fullURL)
            print("✅ Saved full image: \(fullFilename)")
        } catch {
            print("❌ Failed to save full image: \(error)")
            return false
        }
        
        // 2. Generate and save thumbnail (100x100)
        let thumbnail = resizeImage(image, targetSize: CGSize(width: 100, height: 100))
        let thumbFilename = "thumb_\(uuid).png"
        let thumbURL = clipboardDir.appendingPathComponent(thumbFilename)
        
        guard let thumbData = thumbnail.pngData() else {
            print("❌ Failed to create thumbnail")
            return false
        }
        
        do {
            try thumbData.write(to: thumbURL)
            print("✅ Saved thumbnail: \(thumbFilename)")
        } catch {
            print("❌ Failed to save thumbnail: \(error)")
            return false
        }
        
        // 3. Save metadata only
        var allClips = retrieveClips()
        let newClip = ClipboardItem(imageFilename: fullFilename, thumbnailFilename: thumbFilename)
        allClips.insert(newClip, at: 0)
        
        return enforceLimit(clips: &allClips) && saveClips(allClips)
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
        
        // Sort: bookmarked first, then by timestamp
        let bookmarked = clips.filter { $0.isBookmarked }.sorted { $0.timestamp > $1.timestamp }
        let regular = clips.filter { !$0.isBookmarked }.sorted { $0.timestamp > $1.timestamp }
        
        return bookmarked + regular
    }
    
    // MARK: - Load Thumbnail
    
    func loadThumbnail(filename: String) -> UIImage? {
        guard let clipboardDir = clipboardDirectory() else { return nil }
        let url = clipboardDir.appendingPathComponent(filename)
        
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            print("⚠️ Failed to load thumbnail: \(filename)")
            return nil
        }
        
        return image
    }
    
    // MARK: - Get Full Image URL
    
    func getImageURL(filename: String) -> URL? {
        guard let clipboardDir = clipboardDirectory() else { return nil }
        return clipboardDir.appendingPathComponent(filename)
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
        
        // Find clip and delete associated files
        if let clip = clips.first(where: { $0.id == clipID }), clip.type == .image {
            deleteImageFiles(clip: clip)
        }
        
        clips.removeAll { $0.id == clipID }
        return saveClips(clips)
    }
    
    // MARK: - Clear All
    
    func clearAll() -> Bool {
        let clips = retrieveClips()
        
        // Delete all image files
        for clip in clips where clip.type == .image {
            deleteImageFiles(clip: clip)
        }
        
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return false
        }
        defaults.removeObject(forKey: clipboardKey)
        return true
    }
    
    // MARK: - Memory Management
    
    func getProcessMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0
        }
        return 0
    }
    
    // MARK: - Private Helpers
    
    private func enforceLimit(clips: inout [ClipboardItem]) -> Bool {
        let bookmarked = clips.filter { $0.isBookmarked }
        var regular = clips.filter { !$0.isBookmarked }
        
        // Calculate allowed regular items
        let allowedRegular = max(0, maxTotalItems - bookmarked.count)
        
        // Remove excess regular items and delete their files
        if regular.count > allowedRegular {
            let toRemove = regular.suffix(regular.count - allowedRegular)
            for clip in toRemove where clip.type == .image {
                deleteImageFiles(clip: clip)
            }
            regular = Array(regular.prefix(allowedRegular))
        }
        
        clips = bookmarked + regular
        return true
    }
    
    private func deleteImageFiles(clip: ClipboardItem) {
        guard let clipboardDir = clipboardDirectory() else { return }
        
        if let imageFile = clip.imageFilename {
            let imageURL = clipboardDir.appendingPathComponent(imageFile)
            try? FileManager.default.removeItem(at: imageURL)
            print("🗑️ Deleted image: \(imageFile)")
        }
        
        if let thumbFile = clip.thumbnailFilename {
            let thumbURL = clipboardDir.appendingPathComponent(thumbFile)
            try? FileManager.default.removeItem(at: thumbURL)
            print("🗑️ Deleted thumbnail: \(thumbFile)")
        }
    }
    
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
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        let newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        let rect = CGRect(origin: .zero, size: newSize)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
}
