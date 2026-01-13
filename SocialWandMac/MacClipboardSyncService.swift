import AppKit
import CloudKit
import Foundation

final class MacClipboardSyncService {
    static let shared = MacClipboardSyncService()
    static let autoSaveClipboardKey = "macAutoSaveClipboard"
    static let lastSavedSignatureKey = "macLastSavedClipboardSignature"
    static let didUpdateNotification = Notification.Name("MacClipboardDidUpdate")

    private let container = CKContainer(identifier: "iCloud.rishi-more.social-wand")
    private let recordType = "ClipboardItem"
    private let localClipboardKey = "MacSavedClipboardItems"
    private let maxTotalItems = 7

    private init() {}

    func fetchClips(completion: @escaping ([MacClipboardItem]) -> Void) {
        let localClips = loadLocalClips()
        let localDisplay = displayItems(from: localClips)
        DispatchQueue.main.async {
            completion(localDisplay)
        }

        fetchRemoteClips { [weak self] remoteClips in
            guard let self else { return }
            let merged = self.mergeRemoteClips(remoteClips)
            let display = self.displayItems(from: merged)
            DispatchQueue.main.async {
                completion(display)
            }
        }
    }

    func saveFromPasteboard(force: Bool = false, completion: ((Bool) -> Void)? = nil) {
        let pasteboard = NSPasteboard.general

        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first {
            saveImageClip(image, force: force, completion: completion)
            return
        }

        if let imageData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png),
           let image = NSImage(data: imageData) {
            saveImageClip(image, force: force, completion: completion)
            return
        }

        if let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL],
           let url = fileURLs.first,
           let image = NSImage(contentsOf: url) {
            saveImageClip(image, force: force, completion: completion)
            return
        }

        if let strings = pasteboard.readObjects(forClasses: [NSString.self], options: nil) as? [NSString],
           let text = strings.first as String? {
            saveTextClip(text, force: force, completion: completion)
            return
        }

        if let text = pasteboard.string(forType: .string) {
            saveTextClip(text, force: force, completion: completion)
            return
        }

        completion?(false)
    }

    private func saveTextClip(_ text: String, force: Bool, completion: ((Bool) -> Void)?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion?(false)
            return
        }

        if isDuplicateText(trimmed) {
            completion?(false)
            return
        }

        let signature = "text:\(trimmed)"
        if !force, isDuplicateSignature(signature) {
            completion?(false)
            return
        }

        let clip = MacLocalClipboardItem(text: trimmed)
        saveLocalClip(clip, signature: signature)
        syncToCloud(clip)
        DispatchQueue.main.async {
            completion?(true)
        }
    }

    private func saveImageClip(_ image: NSImage, force: Bool, completion: ((Bool) -> Void)?) {
        guard let imageData = pngData(for: image) else {
            completion?(false)
            return
        }

        let signature = imageSignature(from: imageData)
        if isDuplicateImageSignature(signature) {
            completion?(false)
            return
        }
        if !force, isDuplicateSignature(signature) {
            completion?(false)
            return
        }

        guard let directory = clipboardDirectory() else {
            completion?(false)
            return
        }

        let id = UUID().uuidString
        let imageFilename = "image_\(id).png"
        let thumbFilename = "thumb_\(id).png"
        let imageURL = directory.appendingPathComponent(imageFilename)
        let thumbURL = directory.appendingPathComponent(thumbFilename)

        do {
            try imageData.write(to: imageURL)
        } catch {
            completion?(false)
            return
        }

        let thumbnailImage = resizedImage(image, targetSize: CGSize(width: 100, height: 100))
        if let thumbData = pngData(for: thumbnailImage) {
            try? thumbData.write(to: thumbURL)
        }

        let clip = MacLocalClipboardItem(
            id: id,
            type: .image,
            timestamp: Date(),
            modifiedAt: nil,
            isBookmarked: false,
            isDeleted: false,
            textContent: nil,
            imageFilename: imageFilename,
            thumbnailFilename: thumbFilename
        )
        saveLocalClip(clip, signature: signature)
        syncToCloud(clip)
        DispatchQueue.main.async {
            completion?(true)
        }
    }

    private func isDuplicateSignature(_ signature: String) -> Bool {
        let lastSignature = UserDefaults.standard.string(forKey: Self.lastSavedSignatureKey)
        return signature == lastSignature
    }

    private func isDuplicateText(_ text: String) -> Bool {
        loadLocalClips().contains {
            !$0.isDeleted && $0.type == .text && $0.textContent == text
        }
    }

    private func isDuplicateImageSignature(_ signature: String) -> Bool {
        let clips = loadLocalClips().filter { !$0.isDeleted && $0.type == .image }
        guard let directory = clipboardDirectory() else { return false }

        for clip in clips {
            guard let filename = clip.imageFilename else { continue }
            let url = directory.appendingPathComponent(filename)
            guard let data = try? Data(contentsOf: url) else { continue }
            let existingSignature = imageSignature(from: data)
            if existingSignature == signature {
                return true
            }
        }

        return false
    }

    private func removeDuplicateEntries(for clip: MacLocalClipboardItem, signature: String, in clips: inout [MacLocalClipboardItem]) {
        switch clip.type {
        case .text:
            guard let text = clip.textContent else { return }
            clips.removeAll { existing in
                !existing.isDeleted && existing.type == .text && existing.textContent == text
            }
        case .image:
            guard let directory = clipboardDirectory() else { return }
            clips.removeAll { existing in
                guard !existing.isDeleted, existing.type == .image, let filename = existing.imageFilename else {
                    return false
                }
                let url = directory.appendingPathComponent(filename)
                guard let data = try? Data(contentsOf: url) else { return false }
                return imageSignature(from: data) == signature
            }
        }
    }

    private func imageSignature(from data: Data) -> String {
        "image:\(data.count):\(hexPrefix(for: data, length: 24))"
    }

    private func clipboardDirectory() -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = base
            .appendingPathComponent("SocialWandMac", isDirectory: true)
            .appendingPathComponent("clipboard", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                return nil
            }
        }
        return directory
    }

    private func pngData(for image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    private func resizedImage(_ image: NSImage, targetSize: CGSize) -> NSImage {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let scale = min(widthRatio, heightRatio)

        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize), from: .zero, operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }

    private func hexPrefix(for data: Data, length: Int) -> String {
        let prefix = data.prefix(length)
        return prefix.map { String(format: "%02x", $0) }.joined()
    }

    private func saveLocalClip(_ clip: MacLocalClipboardItem, signature: String) {
        var clips = loadLocalClips()
        removeDuplicateEntries(for: clip, signature: signature, in: &clips)
        clips.insert(clip, at: 0)
        enforceLimit(clips: &clips)
        saveLocalClips(clips)
        UserDefaults.standard.set(signature, forKey: Self.lastSavedSignatureKey)
        NotificationCenter.default.post(name: Self.didUpdateNotification, object: nil)
    }

    private func loadLocalClips() -> [MacLocalClipboardItem] {
        guard let data = UserDefaults.standard.data(forKey: localClipboardKey) else {
            return []
        }
        return (try? JSONDecoder().decode([MacLocalClipboardItem].self, from: data)) ?? []
    }

    private func saveLocalClips(_ clips: [MacLocalClipboardItem]) {
        guard let data = try? JSONEncoder().encode(clips) else { return }
        UserDefaults.standard.set(data, forKey: localClipboardKey)
    }

    private func displayItems(from clips: [MacLocalClipboardItem]) -> [MacClipboardItem] {
        let filtered = clips.filter { !$0.isDeleted }
        let sorted = filtered.sorted { lhs, rhs in
            if lhs.isBookmarked != rhs.isBookmarked {
                return lhs.isBookmarked && !rhs.isBookmarked
            }
            return lhs.modifiedAt > rhs.modifiedAt
        }

        let directory = clipboardDirectory()
        return sorted.map { clip in
            let imageURL = clip.imageFilename.flatMap { directory?.appendingPathComponent($0) }
            let thumbURL = clip.thumbnailFilename.flatMap { directory?.appendingPathComponent($0) }
            return MacClipboardItem(
                id: clip.id,
                type: clip.type == .image ? .image : .text,
                timestamp: clip.timestamp,
                modifiedAt: clip.modifiedAt,
                isBookmarked: clip.isBookmarked,
                isDeleted: clip.isDeleted,
                textContent: clip.textContent,
                imageURL: imageURL,
                thumbnailURL: thumbURL
            )
        }
    }

    private func fetchRemoteClips(completion: @escaping ([MacLocalClipboardItem]) -> Void) {
        checkCloudAvailability { [weak self] available in
            guard let self else { return }
            guard available else {
                completion([])
                return
            }

            let query = CKQuery(recordType: self.recordType, predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]

            let database = self.container.privateCloudDatabase
            database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
                switch result {
                case .failure(let error):
                    self.logCloudKitError(error, context: "fetch")
                    completion([])
                case .success(let response):
                    let clips = response.matchResults.compactMap { _, recordResult -> MacLocalClipboardItem? in
                        switch recordResult {
                        case .success(let record):
                            return self.localItem(from: record)
                        case .failure(let error):
                            self.logCloudKitError(error, context: "fetch record")
                            return nil
                        }
                    }
                    completion(clips)
                }
            }
        }
    }

    private func mergeRemoteClips(_ remoteClips: [MacLocalClipboardItem]) -> [MacLocalClipboardItem] {
        var merged = Dictionary(uniqueKeysWithValues: loadLocalClips().map { ($0.id, $0) })

        for remote in remoteClips {
            if let existing = merged[remote.id] {
                if remote.modifiedAt >= existing.modifiedAt {
                    merged[remote.id] = remote
                }
            } else {
                merged[remote.id] = remote
            }
        }

        var mergedClips = Array(merged.values)
        enforceLimit(clips: &mergedClips)
        saveLocalClips(mergedClips)
        NotificationCenter.default.post(name: Self.didUpdateNotification, object: nil)
        return mergedClips
    }

    func toggleBookmark(id: String) {
        var clips = loadLocalClips()
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].isBookmarked.toggle()
        clips[index].markModified()
        saveLocalClips(clips)
        NotificationCenter.default.post(name: Self.didUpdateNotification, object: nil)
        syncToCloud(clips[index])
    }

    func deleteClip(id: String) {
        var clips = loadLocalClips()
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].isDeleted = true
        clips[index].markModified()
        deleteLocalFiles(clip: clips[index])
        saveLocalClips(clips)
        NotificationCenter.default.post(name: Self.didUpdateNotification, object: nil)
        syncToCloud(clips[index])
    }

    private func enforceLimit(clips: inout [MacLocalClipboardItem]) {
        let active = clips.filter { !$0.isDeleted }
        let bookmarked = active.filter { $0.isBookmarked }
        let regular = active.filter { !$0.isBookmarked }
        let allowedRegular = max(0, maxTotalItems - bookmarked.count)

        if regular.count > allowedRegular {
            let overflow = regular.suffix(regular.count - allowedRegular)
            for clip in overflow {
                if let index = clips.firstIndex(where: { $0.id == clip.id }) {
                    clips[index].isDeleted = true
                    clips[index].markModified()
                    deleteLocalFiles(clip: clips[index])
                }
            }
        }
    }

    private func deleteLocalFiles(clip: MacLocalClipboardItem) {
        guard let directory = clipboardDirectory() else { return }
        if let filename = clip.imageFilename {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
        }
        if let filename = clip.thumbnailFilename {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
        }
    }

    private func syncToCloud(_ clip: MacLocalClipboardItem) {
        checkCloudAvailability { [weak self] available in
            guard let self, available else { return }
            guard let record = self.record(for: clip) else { return }
            self.saveRecord(record)
        }
    }

    private func record(for clip: MacLocalClipboardItem) -> CKRecord? {
        let recordID = CKRecord.ID(recordName: clip.id)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record["type"] = clip.type.rawValue as CKRecordValue
        record["isBookmarked"] = clip.isBookmarked as CKRecordValue
        record["isDeleted"] = clip.isDeleted as CKRecordValue
        record["timestamp"] = clip.timestamp as CKRecordValue
        record["modifiedAt"] = clip.modifiedAt as CKRecordValue

        switch clip.type {
        case .text:
            if let text = clip.textContent {
                record["text"] = text as CKRecordValue
            }
        case .image:
            guard let directory = clipboardDirectory() else { return nil }
            if let filename = clip.imageFilename {
                let url = directory.appendingPathComponent(filename)
                if FileManager.default.fileExists(atPath: url.path) {
                    record["imageAsset"] = CKAsset(fileURL: url)
                    record["imageFilename"] = filename as CKRecordValue
                }
            }
            if let filename = clip.thumbnailFilename {
                let url = directory.appendingPathComponent(filename)
                if FileManager.default.fileExists(atPath: url.path) {
                    record["thumbnailAsset"] = CKAsset(fileURL: url)
                    record["thumbnailFilename"] = filename as CKRecordValue
                }
            }
        }
        return record
    }

    private func localItem(from record: CKRecord) -> MacLocalClipboardItem? {
        guard let typeRaw = record["type"] as? String,
              let type = MacLocalClipboardItem.ClipType(rawValue: typeRaw) else {
            return nil
        }

        let id = record.recordID.recordName
        let timestamp = record["timestamp"] as? Date ?? Date()
        let modifiedAt = record["modifiedAt"] as? Date ?? record.modificationDate ?? timestamp
        let isBookmarked = record["isBookmarked"] as? Bool ?? false
        let isDeleted = record["isDeleted"] as? Bool ?? false
        let text = record["text"] as? String

        var imageFilename = record["imageFilename"] as? String
        var thumbnailFilename = record["thumbnailFilename"] as? String

        if type == .image {
            if imageFilename == nil {
                imageFilename = "image_\(id).png"
            }
            if thumbnailFilename == nil {
                thumbnailFilename = "thumb_\(id).png"
            }

            if let asset = record["imageAsset"] as? CKAsset, let filename = imageFilename {
                _ = persistAsset(asset, filename: filename)
            }

            if let asset = record["thumbnailAsset"] as? CKAsset, let filename = thumbnailFilename {
                _ = persistAsset(asset, filename: filename)
            }
        }

        return MacLocalClipboardItem(
            id: id,
            type: type,
            timestamp: timestamp,
            modifiedAt: modifiedAt,
            isBookmarked: isBookmarked,
            isDeleted: isDeleted,
            textContent: text,
            imageFilename: imageFilename,
            thumbnailFilename: thumbnailFilename
        )
    }

    private func persistAsset(_ asset: CKAsset, filename: String) -> Bool {
        guard let sourceURL = asset.fileURL,
              let directory = clipboardDirectory() else {
            return false
        }
        let destinationURL = directory.appendingPathComponent(filename)
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return true
        } catch {
            return false
        }
    }

    private func saveRecord(_ record: CKRecord) {
        let database = container.privateCloudDatabase
        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        operation.modifyRecordsResultBlock = { [weak self] result in
            if case .failure(let error) = result {
                self?.logCloudKitError(error, context: "save")
            }
        }
        database.add(operation)
    }

    private func checkCloudAvailability(completion: @escaping (Bool) -> Void) {
        container.accountStatus { status, error in
            if let error {
                self.logCloudKitError(error, context: "account status")
            }
            completion(status == .available)
        }
    }

    private func logCloudKitError(_ error: Error, context: String) {
        if let ckError = error as? CKError {
            print("MacClipboardSync \(context) failed: \(ckError.code.rawValue) \(ckError.localizedDescription)")
        } else {
            print("MacClipboardSync \(context) failed: \(error.localizedDescription)")
        }
    }
}
