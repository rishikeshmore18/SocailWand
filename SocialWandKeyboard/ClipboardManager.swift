//
//  ClipboardManager.swift
//  SocialWandKeyboard
//

import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

// MARK: - Clipboard Manager

class ClipboardManager {
    static let shared = ClipboardManager()
    
    private let appGroupID = "group.com.rishimore.socialwand"
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
        var allClips = retrieveAllClips()
        
        // Check for duplicates
        if allClips.contains(where: { $0.type == .text && $0.textContent == text && !$0.isDeleted }) {
            print("⚠️ Text already saved")
            return false
        }
        
        let newClip = ClipboardItem(text: text)
        allClips.insert(newClip, at: 0)
        let deletedClips = enforceLimit(clips: &allClips)
        let saved = saveClips(allClips)
        if saved {
            CloudClipboardSyncService.shared.handleLocalUpsert(newClip, requiresOpenAccess: true)
            deletedClips.forEach {
                CloudClipboardSyncService.shared.handleLocalUpsert($0, requiresOpenAccess: true)
            }
        }
        return saved
    }
    
    private func saveImage(_ image: UIImage) -> Bool {
        guard let clipboardDir = clipboardDirectory() else { return false }
        
        let uuid = UUID().uuidString
        let normalized = normalizedImage(image)
        
        // 1. Save full-size image (compressed, visually lossless)
        guard let fullEncoded = encodeImage(normalized, preferHEIC: true, quality: 0.9) else {
            print("❌ Failed to encode full image")
            return false
        }

        let fullFilename = "image_\(uuid).\(fullEncoded.fileExtension)"
        let fullURL = clipboardDir.appendingPathComponent(fullFilename)
        
        do {
            try fullEncoded.data.write(to: fullURL)
            print("✅ Saved full image: \(fullFilename)")
        } catch {
            print("❌ Failed to save full image: \(error)")
            return false
        }
        
        // 2. Generate and save thumbnail (100x100)
        let thumbnail = resizeImage(normalized, targetSize: CGSize(width: 100, height: 100))
        guard let thumbEncoded = encodeThumbnail(thumbnail) else {
            print("❌ Failed to encode thumbnail")
            return false
        }

        let thumbFilename = "thumb_\(uuid).\(thumbEncoded.fileExtension)"
        let thumbURL = clipboardDir.appendingPathComponent(thumbFilename)
        
        do {
            try thumbEncoded.data.write(to: thumbURL)
            print("✅ Saved thumbnail: \(thumbFilename)")
        } catch {
            print("❌ Failed to save thumbnail: \(error)")
            return false
        }
        
        // 3. Save metadata only
        var allClips = retrieveAllClips()
        let newClip = ClipboardItem(imageFilename: fullFilename, thumbnailFilename: thumbFilename)
        allClips.insert(newClip, at: 0)
        let deletedClips = enforceLimit(clips: &allClips)
        let saved = saveClips(allClips)
        if saved {
            CloudClipboardSyncService.shared.handleLocalUpsert(newClip, requiresOpenAccess: true)
            deletedClips.forEach {
                CloudClipboardSyncService.shared.handleLocalUpsert($0, requiresOpenAccess: true)
            }
        }
        return saved
    }
    
    // MARK: - Retrieve Clips
    
    func retrieveClips() -> [ClipboardItem] {
        let clips = retrieveAllClips()
        let activeClips = clips.filter { !$0.isDeleted }

        // Sort: bookmarked first, then by timestamp
        let bookmarked = activeClips.filter { $0.isBookmarked }.sorted { $0.timestamp > $1.timestamp }
        let regular = activeClips.filter { !$0.isBookmarked }.sorted { $0.timestamp > $1.timestamp }

        return bookmarked + regular
    }

    func retrieveAllClips() -> [ClipboardItem] {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: clipboardKey) else {
            return []
        }
        
        guard let clips = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            print("❌ Failed to decode clipboard items")
            return []
        }

        return clips
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
        var clips = retrieveAllClips()
        guard let index = clips.firstIndex(where: { $0.id == clipID && !$0.isDeleted }) else {
            return false
        }
        clips[index].isBookmarked.toggle()
        clips[index].markModified()
        let saved = saveClips(clips)
        if saved {
            CloudClipboardSyncService.shared.handleLocalUpsert(clips[index], requiresOpenAccess: true)
        }
        return saved
    }
    
    // MARK: - Delete Clip
    
    func deleteClip(clipID: String) -> Bool {
        var clips = retrieveAllClips()
        
        guard let index = clips.firstIndex(where: { $0.id == clipID && !$0.isDeleted }) else {
            return false
        }

        if clips[index].type == .image {
            deleteImageFiles(clip: clips[index])
        }

        clips[index].isDeleted = true
        clips[index].markModified()
        let saved = saveClips(clips)
        if saved {
            CloudClipboardSyncService.shared.handleLocalUpsert(clips[index], requiresOpenAccess: true)
        }
        return saved
    }
    
    // MARK: - Clear All
    
    func clearAll() -> Bool {
        var clips = retrieveAllClips()
        
        // Delete all image files
        for index in clips.indices where !clips[index].isDeleted {
            if clips[index].type == .image {
                deleteImageFiles(clip: clips[index])
            }
            clips[index].isDeleted = true
            clips[index].markModified()
        }
        
        let saved = saveClips(clips)
        if saved {
            clips.forEach {
                CloudClipboardSyncService.shared.handleLocalUpsert($0, requiresOpenAccess: true)
            }
        }
        return saved
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
    
    private func enforceLimit(clips: inout [ClipboardItem]) -> [ClipboardItem] {
        let activeClips = clips.filter { !$0.isDeleted }
        let bookmarked = activeClips.filter { $0.isBookmarked }
        var regular = activeClips.filter { !$0.isBookmarked }
        
        // Calculate allowed regular items
        let allowedRegular = max(0, maxTotalItems - bookmarked.count)
        
        // Remove excess regular items and delete their files
        var deletedClips: [ClipboardItem] = []
        if regular.count > allowedRegular {
            let toRemove = regular.suffix(regular.count - allowedRegular)
            for clip in toRemove {
                if let index = clips.firstIndex(where: { $0.id == clip.id }) {
                    if clips[index].type == .image {
                        deleteImageFiles(clip: clips[index])
                    }
                    clips[index].isDeleted = true
                    clips[index].markModified()
                    deletedClips.append(clips[index])
                }
            }
            regular = Array(regular.prefix(allowedRegular))
        }
        
        return deletedClips
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

    private func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? image
    }

    private func encodeImage(
        _ image: UIImage,
        preferHEIC: Bool,
        quality: CGFloat
    ) -> (data: Data, fileExtension: String)? {
        if imageHasAlpha(image) {
            guard let data = image.pngData() else { return nil }
            return (data, "png")
        }

        if preferHEIC, let data = heicData(from: image, quality: quality) {
            return (data, "heic")
        }

        guard let data = image.jpegData(compressionQuality: quality) else { return nil }
        return (data, "jpg")
    }

    private func encodeThumbnail(_ image: UIImage) -> (data: Data, fileExtension: String)? {
        if imageHasAlpha(image) {
            guard let data = image.pngData() else { return nil }
            return (data, "png")
        }
        guard let data = image.jpegData(compressionQuality: 0.75) else { return nil }
        return (data, "jpg")
    }

    private func imageHasAlpha(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        switch cgImage.alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }

    private func heicData(from image: UIImage, quality: CGFloat) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
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
