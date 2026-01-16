import AppKit
import CloudKit
import CryptoKit
import Foundation

final class MacClipboardSyncService {
    static let shared = MacClipboardSyncService()
    static let autoSaveClipboardKey = "macAutoSaveClipboard"
    static let didUpdateNotification = Notification.Name("MacClipboardDidUpdate")
    static let cloudStatusDidChangeNotification = Notification.Name("MacClipboardCloudStatusDidChange")
    static let subscriptionID = "clipboard-item-changes"

    // UNIFIED: Use same App Group as iOS
    private let appGroupID = "group.com.rishimore.socialwand"
    
    // UNIFIED: Use same storage key as iOS
    private let clipboardKey = "SavedClipboardItems"
    
    // UNIFIED: Use same pending keys as iOS
    private let pendingUpsertsKey = "CloudClipboardPendingUpserts"
    private let pendingDeletesKey = "CloudClipboardPendingDeletes"
    private let migrationFlagKey = "MacToUnifiedStorageMigrated"
    
    private let container = CKContainer(identifier: "iCloud.rishi-more.social-wand")
    private let recordType = "ClipboardItem"
    private let maxTotalItems = 7

    private let fetchStateQueue = DispatchQueue(label: "mac.clipboard.fetch.state")
    private var fetchInFlight = false
    private var lastFetchAt: Date?
    private let fetchMinimumInterval: TimeInterval = 3

    private init() {
        performMigrationIfNeeded()
    }

    // MARK: - Public API

    func fetchClips(completion: @escaping ([MacClipboardItem]) -> Void) {
        let localClips = loadLocalClips()
        let localDisplay = displayItems(from: localClips)
        DispatchQueue.main.async {
            completion(localDisplay)
        }

        pushPendingChanges()

        fetchRemoteClips { [weak self] remoteClips in
            guard let self else { return }
            let merged = self.mergeRemoteClips(remoteClips, notify: false)
            let display = self.displayItems(from: merged)
            guard display != localDisplay else { return }
            DispatchQueue.main.async {
                completion(display)
            }
        }
    }

    func saveFromPasteboard(force: Bool = false, completion: ((Bool) -> Void)? = nil) {
        let pasteboard = NSPasteboard.general
        let typeList = pasteboard.types?.map { $0.rawValue } ?? []
        print("📋 Mac Pasteboard types: \(typeList)")

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

        if let jpegData = pasteboard.data(forType: NSPasteboard.PasteboardType("public.jpeg")),
           let image = NSImage(data: jpegData) {
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

        if let htmlData = pasteboard.data(forType: .html),
           let attributed = try? NSAttributedString(
            data: htmlData,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil
           ) {
            let plainText = attributed.string
            if !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                saveTextClip(plainText, force: force, completion: completion)
                return
            }
        }

        if let rtfData = pasteboard.data(forType: .rtf),
           let attributed = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
            let plainText = attributed.string
            if !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                saveTextClip(plainText, force: force, completion: completion)
                return
            }
        }

        completion?(false)
    }

    func toggleBookmark(id: String) {
        var clips = loadLocalClips()
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].isBookmarked.toggle()
        clips[index].markModified()
        enqueuePendingUpsert(clips[index].id)
        saveLocalClips(clips)
        NotificationCenter.default.post(name: Self.didUpdateNotification, object: nil)
        syncToCloud(clips[index])
    }

    func deleteClip(id: String) {
        var clips = loadLocalClips()
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].isDeleted = true
        clips[index].markModified()
        enqueuePendingUpsert(clips[index].id)
        deleteLocalFiles(clip: clips[index])
        saveLocalClips(clips)
        NotificationCenter.default.post(name: Self.didUpdateNotification, object: nil)
        syncToCloud(clips[index])
    }

    func registerCloudKitSubscription() {
        checkCloudAvailability { [weak self] available in
            guard let self, available else { return }
            let database = self.container.privateCloudDatabase
            database.fetch(withSubscriptionID: Self.subscriptionID) { existing, _ in
                guard existing == nil else { return }

                let subscription = CKQuerySubscription(
                    recordType: self.recordType,
                    predicate: NSPredicate(value: true),
                    subscriptionID: Self.subscriptionID,
                    options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
                )
                let info = CKSubscription.NotificationInfo()
                info.shouldSendContentAvailable = true
                subscription.notificationInfo = info

                database.save(subscription) { _, error in
                    if let error {
                        self.logCloudKitError(error, context: "subscription")
                    }
                }
            }
        }
    }

    func handleRemoteNotification() {
        fetchRemoteClips { [weak self] remoteClips in
            guard let self else { return }
            _ = self.mergeRemoteClips(remoteClips, notify: true)
        }
    }

    // MARK: - Private Helpers

    private func saveTextClip(_ text: String, force _: Bool, completion: ((Bool) -> Void)?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion?(false)
            return
        }

        let signature = signatureForText(trimmed)
        if isDuplicateSignature(signature, in: loadLocalClips()) {
            completion?(false)
            return
        }

        let clip = ClipboardItem(text: trimmed, contentSignature: signature)
        saveLocalClip(clip)
        syncToCloud(clip)
        DispatchQueue.main.async {
            completion?(true)
        }
    }

    private func saveImageClip(_ image: NSImage, force _: Bool, completion: ((Bool) -> Void)?) {
        guard let imageData = pngData(for: image) else {
            completion?(false)
            return
        }

        guard let signature = signatureForImage(image) else {
            completion?(false)
            return
        }

        if isDuplicateSignature(signature, in: loadLocalClips()) {
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

        let clip = ClipboardItem(
            imageFilename: imageFilename,
            thumbnailFilename: thumbFilename,
            contentSignature: signature
        )
        saveLocalClip(clip)
        syncToCloud(clip)
        DispatchQueue.main.async {
            completion?(true)
        }
    }

    private func saveLocalClip(_ clip: ClipboardItem) {
        var clips = loadLocalClips()
        clips.insert(clip, at: 0)
        enforceLimit(clips: &clips)
        saveLocalClips(clips)
        enqueuePendingUpsert(clip.id)
        NotificationCenter.default.post(name: Self.didUpdateNotification, object: nil)
    }

    private func isDuplicateSignature(_ signature: String, in clips: [ClipboardItem]) -> Bool {
        guard !signature.isEmpty else { return false }
        return clips.contains { !$0.isDeleted && $0.contentSignature == signature }
    }

    // MARK: - Storage (UNIFIED with iOS)

    private func loadLocalClips() -> [ClipboardItem] {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: clipboardKey) else {
            return []
        }

        guard var clips = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            return []
        }

        if fillMissingSignatures(in: &clips) {
            saveLocalClips(clips)
        }

        return clips
    }

    private func saveLocalClips(_ clips: [ClipboardItem]) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(clips) else {
            return
        }

        defaults.set(data, forKey: clipboardKey)
    }

    // MARK: - Display Conversion

    private func displayItems(from clips: [ClipboardItem]) -> [MacClipboardItem] {
        let filtered = clips.filter { !$0.isDeleted }
        let sorted = filtered.sorted { lhs, rhs in
            if lhs.isBookmarked != rhs.isBookmarked {
                return lhs.isBookmarked && !rhs.isBookmarked
            }
            return lhs.timestamp > rhs.timestamp
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

    // MARK: - CloudKit Sync

    private func fetchRemoteClips(completion: @escaping ([ClipboardItem]) -> Void) {
        fetchStateQueue.async { [weak self] in
            guard let self = self else { return }

            if self.fetchInFlight {
                completion([])
                return
            }

            if let lastFetchAt = self.lastFetchAt,
               Date().timeIntervalSince(lastFetchAt) < self.fetchMinimumInterval {
                completion([])
                return
            }

            self.fetchInFlight = true
            self.lastFetchAt = Date()

            self.checkCloudAvailability { [weak self] available in
                guard let self else {
                    completion([])
                    return
                }
                
                defer {
                    self.fetchStateQueue.async {
                        self.fetchInFlight = false
                    }
                }

                guard available else {
                    completion([])
                    return
                }

                let query = CKQuery(
                    recordType: self.recordType,
                    predicate: NSPredicate(format: "modifiedAt >= %@", Date.distantPast as NSDate)
                )
                query.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]

                let database = self.container.privateCloudDatabase
                database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
                    switch result {
                    case .failure(let error):
                        self.logCloudKitError(error, context: "fetch")
                        completion([])
                    case .success(let response):
                        let clips = response.matchResults.compactMap { _, recordResult -> ClipboardItem? in
                            switch recordResult {
                            case .success(let record):
                                return self.clip(from: record)
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
    }

    private func mergeRemoteClips(
        _ remoteClips: [ClipboardItem],
        notify: Bool = true
    ) -> [ClipboardItem] {
        let existingClips = loadLocalClips()
        let existingHash = clipsHash(existingClips)
        var merged = Dictionary(uniqueKeysWithValues: existingClips.map { ($0.id, $0) })
        let pendingUpserts = Set(loadPendingUpserts())

        for remote in remoteClips {
            if let existing = merged[remote.id] {
                if pendingUpserts.contains(remote.id), existing.modifiedAt > remote.modifiedAt {
                    continue
                }
                if remote.modifiedAt >= existing.modifiedAt {
                    merged[remote.id] = remote
                }
            } else {
                merged[remote.id] = remote
            }
        }

        var mergedClips = Array(merged.values)
        
        // Remove local files for deleted items
        for clip in mergedClips where clip.isDeleted && clip.type == .image {
            deleteLocalFiles(clip: clip)
        }
        
        let newlyDeleted = enforceLimit(clips: &mergedClips)
        if !newlyDeleted.isEmpty {
            newlyDeleted.forEach { enqueuePendingUpsert($0.id) }
            pushPendingChanges()
        }
        
        saveLocalClips(mergedClips)
        let mergedHash = clipsHash(mergedClips)
        if notify, mergedHash != existingHash {
            NotificationCenter.default.post(name: Self.didUpdateNotification, object: nil)
        }
        return mergedClips
    }

    private func syncToCloud(_ clip: ClipboardItem) {
        checkCloudAvailability { [weak self] available in
            guard let self, available else { return }
            guard let record = self.record(for: clip) else { return }
            self.saveRecord(record) { [weak self] success in
                guard success else { return }
                self?.removePendingUpserts([clip.id])
            }
        }
    }

    private func record(for clip: ClipboardItem) -> CKRecord? {
        let recordID = CKRecord.ID(recordName: clip.id)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record["type"] = clip.type.rawValue as CKRecordValue
        record["isBookmarked"] = clip.isBookmarked as CKRecordValue
        record["isDeleted"] = clip.isDeleted as CKRecordValue
        record["timestamp"] = clip.timestamp as CKRecordValue
        record["modifiedAt"] = clip.modifiedAt as CKRecordValue
        record["contentSignature"] = clip.contentSignature as CKRecordValue

        if clip.isDeleted {
            return record
        }

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

    private func clip(from record: CKRecord) -> ClipboardItem? {
        guard let typeString = record["type"] as? String,
              let type = ClipboardItem.ClipboardItemType(rawValue: typeString) else {
            return nil
        }

        let id = record.recordID.recordName
        let timestamp = record["timestamp"] as? Date ?? Date()
        let modifiedAt = record["modifiedAt"] as? Date ?? record.modificationDate ?? timestamp
        let isBookmarked = record["isBookmarked"] as? Bool ?? false
        let isDeleted = record["isDeleted"] as? Bool ?? false
        let storedSignature = record["contentSignature"] as? String ?? ""

        switch type {
        case .text:
            let text = record["text"] as? String ?? ""
            let signature = storedSignature.isEmpty ? signatureForText(text) : storedSignature
            return ClipboardItem(
                id: id,
                type: .text,
                timestamp: timestamp,
                modifiedAt: modifiedAt,
                isBookmarked: isBookmarked,
                isDeleted: isDeleted,
                contentSignature: signature,
                textContent: text,
                imageFilename: nil,
                thumbnailFilename: nil
            )
        case .image:
            let imageFilename = record["imageFilename"] as? String ?? "image_\(id).png"
            let thumbnailFilename = record["thumbnailFilename"] as? String ?? "thumb_\(id).png"
            let signature = storedSignature.isEmpty ? legacyImageSignature(imageFilename) : storedSignature
            
            if !isDeleted {
                if let asset = record["imageAsset"] as? CKAsset {
                    _ = persistAsset(asset, filename: imageFilename)
                }
                if let asset = record["thumbnailAsset"] as? CKAsset {
                    _ = persistAsset(asset, filename: thumbnailFilename)
                }
            }
            
            return ClipboardItem(
                id: id,
                type: .image,
                timestamp: timestamp,
                modifiedAt: modifiedAt,
                isBookmarked: isBookmarked,
                isDeleted: isDeleted,
                contentSignature: signature,
                textContent: nil,
                imageFilename: imageFilename,
                thumbnailFilename: thumbnailFilename
            )
        }
    }

    private func saveRecord(_ record: CKRecord, completion: ((Bool) -> Void)? = nil) {
        let database = container.privateCloudDatabase
        let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        operation.modifyRecordsResultBlock = { [weak self] result in
            switch result {
            case .success:
                completion?(true)
            case .failure(let error):
                self?.logCloudKitError(error, context: "save")
                completion?(false)
            }
        }
        database.add(operation)
    }

    private func pushPendingChanges() {
        let pendingDeletes = Set(loadPendingDeletes())
        let pendingUpserts = Set(loadPendingUpserts()).subtracting(pendingDeletes)

        guard !pendingDeletes.isEmpty || !pendingUpserts.isEmpty else { return }

        checkCloudAvailability { [weak self] available in
            guard let self, available else { return }

            let database = self.container.privateCloudDatabase
            let group = DispatchGroup()
            let lockQueue = DispatchQueue(label: "mac.clipboard.pending.lock")
            var successfulDeletes: [String] = []
            var successfulUpserts: [String] = []

            for id in pendingDeletes {
                group.enter()
                database.delete(withRecordID: CKRecord.ID(recordName: id)) { _, error in
                    if error == nil {
                        lockQueue.async {
                            successfulDeletes.append(id)
                            group.leave()
                        }
                    } else {
                        if let error {
                            self.logCloudKitError(error, context: "delete \(id)")
                        }
                        group.leave()
                    }
                }
            }

            group.notify(queue: .global(qos: .utility)) {
                if !successfulDeletes.isEmpty {
                    self.removePendingDeletes(successfulDeletes)
                }

                let localClips = self.loadLocalClips()
                let localByID = Dictionary(uniqueKeysWithValues: localClips.map { ($0.id, $0) })
                let recordsToSave: [CKRecord] = pendingUpserts.compactMap { id in
                    guard let clip = localByID[id] else { return nil }
                    return self.record(for: clip)
                }

                guard !recordsToSave.isEmpty else { return }

                let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
                operation.savePolicy = .changedKeys
                operation.perRecordSaveBlock = { recordID, result in
                    switch result {
                    case .success:
                        lockQueue.async {
                            successfulUpserts.append(recordID.recordName)
                        }
                    case .failure(let error):
                        self.logCloudKitError(error, context: "save \(recordID.recordName)")
                    }
                }
                operation.modifyRecordsResultBlock = { _ in
                    if !successfulUpserts.isEmpty {
                        self.removePendingUpserts(successfulUpserts)
                    }
                }
                database.add(operation)
            }
        }
    }

    // MARK: - File Management (UNIFIED with iOS)

    private func clipboardDirectory() -> URL? {
        // UNIFIED: Use App Group container like iOS
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            print("⚠️ Mac: Failed to get App Group container")
            return nil
        }

        let clipboardDir = containerURL.appendingPathComponent("clipboard", isDirectory: true)
        if !FileManager.default.fileExists(atPath: clipboardDir.path) {
            do {
                try FileManager.default.createDirectory(at: clipboardDir, withIntermediateDirectories: true)
            } catch {
                print("⚠️ Mac: Failed to create clipboard directory: \(error)")
                return nil
            }
        }

        return clipboardDir
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

    private func deleteLocalFiles(clip: ClipboardItem) {
        guard let directory = clipboardDirectory() else { return }
        if let filename = clip.imageFilename {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
        }
        if let filename = clip.thumbnailFilename {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
        }
    }

    private func enforceLimit(clips: inout [ClipboardItem]) -> [ClipboardItem] {
        let active = clips.filter { !$0.isDeleted }
        let bookmarked = active.filter { $0.isBookmarked }
        let regular = active.filter { !$0.isBookmarked }.sorted { $0.timestamp > $1.timestamp }
        let allowedRegular = max(0, maxTotalItems - bookmarked.count)

        var deletedClips: [ClipboardItem] = []
        if regular.count > allowedRegular {
            let overflow = regular.suffix(regular.count - allowedRegular)
            for clip in overflow {
                if let index = clips.firstIndex(where: { $0.id == clip.id }) {
                    if clips[index].type == .image {
                        deleteLocalFiles(clip: clips[index])
                    }
                    clips[index].isDeleted = true
                    clips[index].markModified()
                    deletedClips.append(clips[index])
                }
            }
        }
        return deletedClips
    }

    // MARK: - Pending Queue (UNIFIED with iOS)

    private func enqueuePendingUpsert(_ id: String) {
        var pending = Set(loadPendingUpserts())
        pending.insert(id)
        savePendingUpserts(Array(pending))
    }

    private func removePendingUpserts(_ ids: [String]) {
        var pending = Set(loadPendingUpserts())
        pending.subtract(ids)
        savePendingUpserts(Array(pending))
    }

    private func loadPendingUpserts() -> [String] {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return [] }
        return defaults.stringArray(forKey: pendingUpsertsKey) ?? []
    }

    private func savePendingUpserts(_ ids: [String]) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(ids, forKey: pendingUpsertsKey)
    }

    private func enqueuePendingDelete(_ id: String) {
        var pending = Set(loadPendingDeletes())
        pending.insert(id)
        savePendingDeletes(Array(pending))
    }

    private func removePendingDeletes(_ ids: [String]) {
        var pending = Set(loadPendingDeletes())
        pending.subtract(ids)
        savePendingDeletes(Array(pending))
    }

    private func loadPendingDeletes() -> [String] {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return [] }
        return defaults.stringArray(forKey: pendingDeletesKey) ?? []
    }

    private func savePendingDeletes(_ ids: [String]) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(ids, forKey: pendingDeletesKey)
    }

    // MARK: - Utilities

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

    private func checkCloudAvailability(completion: @escaping (Bool) -> Void) {
        container.accountStatus { status, error in
            if let error {
                self.logCloudKitError(error, context: "account status")
            }
            let available = status == .available
            if available {
                self.updateCloudStatus(message: nil)
            } else {
                self.updateCloudStatus(message: "CloudKit unavailable. Showing local clipboard.")
            }
            completion(available)
        }
    }

    private func logCloudKitError(_ error: Error, context: String) {
        if let ckError = error as? CKError {
            print("MacClipboardSync \(context) failed: \(ckError.code.rawValue) \(ckError.localizedDescription)")
        } else {
            print("MacClipboardSync \(context) failed: \(error.localizedDescription)")
        }
        updateCloudStatus(message: "CloudKit error. Showing local clipboard.")
    }

    private func updateCloudStatus(message: String?) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Self.cloudStatusDidChangeNotification,
                object: nil,
                userInfo: ["message": message as Any]
            )
        }
    }

    private func clipsHash(_ clips: [ClipboardItem]) -> Int {
        let joined = clips.map {
            "\($0.id)|\($0.modifiedAt.timeIntervalSince1970)|\($0.isBookmarked)|\($0.isDeleted)|\($0.textContent ?? "")|\($0.imageFilename ?? "")|\($0.thumbnailFilename ?? "")"
        }.joined(separator: "||")
        return joined.hashValue
    }

    private func signatureForText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hash = SHA256.hash(data: Data(trimmed.utf8))
        return "text:\(hash.hexString)"
    }

    private func signatureForImage(_ image: NSImage) -> String? {
        let data = imageSignatureData(image) ?? pngData(for: image)
        guard let data else { return nil }
        let hash = SHA256.hash(data: data)
        return "image:\(data.count):\(hash.hexString)"
    }

    private func imageSignatureData(_ image: NSImage) -> Data? {
        let targetSize = CGSize(width: 32, height: 32)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        let bytesPerRow = width * 4
        var data = Data(count: height * bytesPerRow)

        let success = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            context.interpolationQuality = .low
            context.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))
            return true
        }

        return success ? data : nil
    }

    private func legacyImageSignature(_ filename: String) -> String {
        "image:legacy:\(filename)"
    }

    private func fillMissingSignatures(in clips: inout [ClipboardItem]) -> Bool {
        var updated = false
        for index in clips.indices {
            if !clips[index].contentSignature.isEmpty {
                continue
            }
            switch clips[index].type {
            case .text:
                if let text = clips[index].textContent {
                    clips[index].contentSignature = signatureForText(text)
                    updated = true
                }
            case .image:
                guard let filename = clips[index].imageFilename,
                      let directory = clipboardDirectory() else { break }
                let url = directory.appendingPathComponent(filename)
                if let image = NSImage(contentsOf: url),
                   let signature = signatureForImage(image) {
                    clips[index].contentSignature = signature
                } else {
                    clips[index].contentSignature = legacyImageSignature(filename)
                }
                updated = true
            }
        }
        return updated
    }

    // MARK: - Migration

    private func performMigrationIfNeeded() {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              !defaults.bool(forKey: migrationFlagKey) else {
            return
        }

        print("🔄 Mac: Starting migration to unified storage...")

        // Try to load old Mac clipboard items from standard UserDefaults
        let oldKey = "MacSavedClipboardItems"
        if let oldData = UserDefaults.standard.data(forKey: oldKey),
           let oldClips = try? JSONDecoder().decode([MacLocalClipboardItem].self, from: oldData) {
            
            print("📦 Mac: Found \(oldClips.count) items in old storage")
            
            // Convert MacLocalClipboardItem to ClipboardItem
            let convertedClips: [ClipboardItem] = oldClips.map { old in
                let signature: String
                switch old.type {
                case .text:
                    if let text = old.textContent {
                        signature = signatureForText(text)
                    } else {
                        signature = ""
                    }
                case .image:
                    if let filename = old.imageFilename {
                        signature = legacyImageSignature(filename)
                    } else {
                        signature = ""
                    }
                }
                return ClipboardItem(
                    id: old.id,
                    type: old.type == .text ? .text : .image,
                    timestamp: old.timestamp,
                    modifiedAt: old.modifiedAt,
                    isBookmarked: old.isBookmarked,
                    isDeleted: old.isDeleted,
                    contentSignature: signature,
                    textContent: old.textContent,
                    imageFilename: old.imageFilename,
                    thumbnailFilename: old.thumbnailFilename
                )
            }
            
            // Migrate files from Application Support to App Group
            migrateFilesToAppGroup(clips: convertedClips)
            
            // Save to new unified storage
            saveLocalClips(convertedClips)
            
            // Mark all as pending upserts to sync to cloud
            convertedClips.forEach { enqueuePendingUpsert($0.id) }
            
            print("✅ Mac: Migration complete. Migrated \(convertedClips.count) items")
        } else {
            print("ℹ️ Mac: No old items to migrate")
        }

        // Mark migration as complete
        defaults.set(true, forKey: migrationFlagKey)
    }

    private func migrateFilesToAppGroup(clips: [ClipboardItem]) {
        // Old path: Application Support/SocialWandMac/clipboard
        guard let oldBase = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let oldDirectory = oldBase
            .appendingPathComponent("SocialWandMac", isDirectory: true)
            .appendingPathComponent("clipboard", isDirectory: true)
        
        guard FileManager.default.fileExists(atPath: oldDirectory.path),
              let newDirectory = clipboardDirectory() else {
            return
        }
        
        print("📁 Mac: Migrating files from \(oldDirectory.path) to \(newDirectory.path)")
        
        for clip in clips where clip.type == .image {
            if let imageFilename = clip.imageFilename {
                let oldURL = oldDirectory.appendingPathComponent(imageFilename)
                let newURL = newDirectory.appendingPathComponent(imageFilename)
                if FileManager.default.fileExists(atPath: oldURL.path) {
                    try? FileManager.default.copyItem(at: oldURL, to: newURL)
                    print("  ✓ Migrated: \(imageFilename)")
                }
            }
            if let thumbFilename = clip.thumbnailFilename {
                let oldURL = oldDirectory.appendingPathComponent(thumbFilename)
                let newURL = newDirectory.appendingPathComponent(thumbFilename)
                if FileManager.default.fileExists(atPath: oldURL.path) {
                    try? FileManager.default.copyItem(at: oldURL, to: newURL)
                    print("  ✓ Migrated: \(thumbFilename)")
                }
            }
        }
    }
}

private extension SHA256.Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
