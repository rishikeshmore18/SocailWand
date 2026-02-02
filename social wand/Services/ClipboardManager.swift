//
//  ClipboardManager.swift
//  social wand
//

import Foundation
import CryptoKit
import CoreImage
import ImageIO
import UIKit
import UniformTypeIdentifiers

// MARK: - Clipboard Manager

class ClipboardManager {
    static let shared = ClipboardManager()
    
    private let appGroupID = "group.com.rishimore.socialwand"
    private let clipboardKey = "SavedClipboardItems"
    private let maxTotalItems = 7  // Reduced from 15
    
    private init() {
        migrateMissingSignaturesIfNeeded()
    }
    
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
        return saveCurrentClipboardReturningClip() != nil
    }
    
    func saveCurrentClipboardReturningClip() -> ClipboardItem? {
        let pasteboard = UIPasteboard.general
        
        // Priority: Try image first, then text
        if let image = pasteboard.image {
            return saveImage(image)
        } else if let text = pasteboard.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return saveText(text)
        } else {
            print("⚠️ Clipboard is empty")
            return nil
        }
    }
    
    private func saveText(_ text: String) -> ClipboardItem? {
        var allClips = retrieveAllClips()

        let signature = signatureForText(text)
        if isDuplicateSignature(signature, in: allClips) {
            print("⚠️ Text already saved")
            return nil
        }
        if isSignaturePendingUpsert(signature, in: allClips) {
            print("⚠️ Text already pending sync")
            return nil
        }

        let newClip = ClipboardItem(text: text, contentSignature: signature)
        allClips.insert(newClip, at: 0)
        let deletedClips = enforceLimit(clips: &allClips)
        let saved = saveClips(allClips)
        if saved {
            CloudClipboardSyncService.shared.handleLocalUpsert(newClip, requiresOpenAccess: true)
            deletedClips.forEach {
                CloudClipboardSyncService.shared.handleLocalUpsert($0, requiresOpenAccess: true)
            }
            CloudClipboardSyncService.shared.fetchRemoteChanges(completion: nil)
        }
        return saved ? newClip : nil
    }
    
    private func saveImage(_ image: UIImage) -> ClipboardItem? {
        guard let clipboardDir = clipboardDirectory() else { return nil }
        
        let uuid = UUID().uuidString
        let normalized = normalizedImage(image)
        var allClips = retrieveAllClips()

        guard let signature = signatureForImage(normalized) else {
            print("❌ Failed to generate image signature")
            return nil
        }

        if isDuplicateSignature(signature, in: allClips) {
            print("⚠️ Image already saved")
            return nil
        }
        if isSignaturePendingUpsert(signature, in: allClips) {
            print("⚠️ Image already pending sync")
            return nil
        }
        
        // 1. Save full-size image (compressed, visually lossless)
        guard let fullEncoded = encodeImage(normalized, preferHEIC: true, quality: 0.9) else {
            print("❌ Failed to encode full image")
            return nil
        }

        let fullFilename = "image_\(uuid).\(fullEncoded.fileExtension)"
        let fullURL = clipboardDir.appendingPathComponent(fullFilename)
        
        do {
            try fullEncoded.data.write(to: fullURL)
            print("✅ Saved full image: \(fullFilename)")
        } catch {
            print("❌ Failed to save full image: \(error)")
            return nil
        }
        
        // 2. Generate and save thumbnail (100x100)
        let thumbnail = resizeImage(normalized, targetSize: CGSize(width: 100, height: 100))
        guard let thumbEncoded = encodeThumbnail(thumbnail) else {
            print("❌ Failed to encode thumbnail")
            return nil
        }

        let thumbFilename = "thumb_\(uuid).\(thumbEncoded.fileExtension)"
        let thumbURL = clipboardDir.appendingPathComponent(thumbFilename)
        
        do {
            try thumbEncoded.data.write(to: thumbURL)
            print("✅ Saved thumbnail: \(thumbFilename)")
        } catch {
            print("❌ Failed to save thumbnail: \(error)")
            return nil
        }
        
        // 3. Save metadata only
        let newClip = ClipboardItem(
            imageFilename: fullFilename,
            thumbnailFilename: thumbFilename,
            contentSignature: signature
        )
        allClips.insert(newClip, at: 0)
        let deletedClips = enforceLimit(clips: &allClips)
        let saved = saveClips(allClips)
        if saved {
            CloudClipboardSyncService.shared.handleLocalUpsert(newClip, requiresOpenAccess: true)
            deletedClips.forEach {
                CloudClipboardSyncService.shared.handleLocalUpsert($0, requiresOpenAccess: true)
            }
            CloudClipboardSyncService.shared.fetchRemoteChanges(completion: nil)
        }
        return saved ? newClip : nil
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
        
        guard var clips = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            print("❌ Failed to decode clipboard items")
            return []
        }

        if fillMissingSignatures(in: &clips) {
            _ = saveClips(clips)
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
    
    // MARK: - Delete Clip
    
    func deleteClip(clipID: String) -> Bool {
        var clips = retrieveAllClips()
        
        guard let index = clips.firstIndex(where: { $0.id == clipID }) else {
            return false
        }
        
        clips[index].isDeleted = true
        clips[index].markModified()
        
        if clips[index].type == .image, let imageFile = clips[index].imageFilename {
            deleteImageFiles(clip: clips[index])
            print("🧹 Deleted image file: \(imageFile)")
        }
        
        let saved = saveClips(clips)
        if saved {
            CloudClipboardSyncService.shared.handleLocalUpsert(clips[index], requiresOpenAccess: true)
        }
        return saved
    }
    
    // MARK: - Toggle Bookmark
    
    func toggleBookmark(clipID: String) -> Bool {
        var clips = retrieveAllClips()
        
        guard let index = clips.firstIndex(where: { $0.id == clipID }) else {
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
    
    // MARK: - Local Save
    
    private func saveClips(_ clips: [ClipboardItem]) -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
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
    
    // MARK: - Enforce Limit
    
    private func enforceLimit(clips: inout [ClipboardItem]) -> [ClipboardItem] {
        var deletedClips: [ClipboardItem] = []
        
        while clips.count > maxTotalItems {
            if let index = clips.lastIndex(where: { !$0.isBookmarked }) {
                var clip = clips.remove(at: index)
                clip.isDeleted = true
                clip.markModified()
                deletedClips.append(clip)
                deleteImageFiles(clip: clip)
            } else {
                break
            }
        }
        
        return deletedClips
    }
    
    private func deleteImageFiles(clip: ClipboardItem) {
        guard let clipboardDir = clipboardDirectory() else { return }
        guard let imageFile = clip.imageFilename,
              let thumbFile = clip.thumbnailFilename else { return }
        
        let imageURL = clipboardDir.appendingPathComponent(imageFile)
        let thumbURL = clipboardDir.appendingPathComponent(thumbFile)
        
        try? FileManager.default.removeItem(at: imageURL)
        try? FileManager.default.removeItem(at: thumbURL)
    }
    
    // MARK: - Signatures
    
    private func signatureForText(_ text: String) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let data = normalized.data(using: .utf8) ?? Data()
        let hash = SHA256.hash(data: data)
        return "text:\(normalized.count):\(hash.hexString)"
    }
    
    private func signatureForImage(_ image: UIImage) -> String? {
        guard let data = imageSignatureData(image) else { return nil }
        let hash = SHA256.hash(data: data)
        return "image:\(data.count):\(hash.hexString)"
    }
    
    private func imageSignatureData(_ image: UIImage) -> Data? {
        guard let cgImage = normalizedCGImage(from: image) else { return nil }
        
        let targetSize = CGSize(width: 32, height: 32)
        let bytesPerPixel = 4
        let bytesPerRow = Int(targetSize.width) * bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        
        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))
        
        guard let data = context.data else { return nil }
        return Data(bytes: data, count: bytesPerRow * Int(targetSize.height))
    }
    
    private func normalizedCGImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cgImage = image.cgImage {
            return cgImage
        }
        let ciImage = image.ciImage ?? CIImage(image: image)
        guard let source = ciImage else { return nil }
        let oriented = source.oriented(forExifOrientation: exifOrientation(from: image.imageOrientation))
        let context = CIContext(options: nil)
        return context.createCGImage(oriented, from: oriented.extent)
    }
    
    private func exifOrientation(from orientation: UIImage.Orientation) -> Int32 {
        switch orientation {
        case .up: return 1
        case .down: return 3
        case .left: return 8
        case .right: return 6
        case .upMirrored: return 2
        case .downMirrored: return 4
        case .leftMirrored: return 5
        case .rightMirrored: return 7
        @unknown default: return 1
        }
    }
    
    // MARK: - Image Helpers
    
    private struct EncodedImage {
        let data: Data
        let fileExtension: String
        let uti: UTType
    }
    
    private func encodeImage(_ image: UIImage, preferHEIC: Bool, quality: CGFloat) -> EncodedImage? {
        if preferHEIC, let heicData = encode(image, uti: .heic, quality: quality) {
            return EncodedImage(data: heicData, fileExtension: "heic", uti: .heic)
        }
        if let jpegData = encode(image, uti: .jpeg, quality: quality) {
            return EncodedImage(data: jpegData, fileExtension: "jpg", uti: .jpeg)
        }
        return nil
    }
    
    private func encodeThumbnail(_ image: UIImage) -> EncodedImage? {
        if let pngData = encode(image, uti: .png, quality: 1.0) {
            return EncodedImage(data: pngData, fileExtension: "png", uti: .png)
        }
        return nil
    }
    
    private func encode(_ image: UIImage, uti: UTType, quality: CGFloat) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, uti.identifier as CFString, 1, nil) else {
            return nil
        }
        let options = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, options)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    private func normalizedImage(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
    
    // MARK: - Signature Cleanup
    
    private func isDuplicateSignature(_ signature: String, in clips: [ClipboardItem]) -> Bool {
        clips.contains { $0.contentSignature == signature && !$0.isDeleted }
    }
    
    private func isSignaturePendingUpsert(_ signature: String, in clips: [ClipboardItem]) -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return false }
        let pendingIDs = defaults.stringArray(forKey: "CloudClipboardPendingUpserts") ?? []
        return pendingIDs.contains(signature)
    }
    
    private func migrateMissingSignaturesIfNeeded() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        let flagKey = "CloudClipboardDidCleanupSignatures"
        if defaults.bool(forKey: flagKey) {
            return
        }
        defaults.set(true, forKey: flagKey)
    }
    
    private func fillMissingSignatures(in clips: inout [ClipboardItem]) -> Bool {
        var didUpdate = false
        for index in clips.indices {
            if clips[index].contentSignature.isEmpty {
                if clips[index].type == .text, let text = clips[index].textContent {
                    clips[index].contentSignature = signatureForText(text)
                    didUpdate = true
                } else if clips[index].type == .image, let imageFilename = clips[index].imageFilename,
                          let imageURL = getImageURL(filename: imageFilename),
                          let imageData = try? Data(contentsOf: imageURL),
                          let image = UIImage(data: imageData),
                          let signature = signatureForImage(image) {
                    clips[index].contentSignature = signature
                    didUpdate = true
                }
            }
        }
        return didUpdate
    }
}

private extension Digest {
    var hexString: String {
        self.map { String(format: "%02x", $0) }.joined()
    }
}
