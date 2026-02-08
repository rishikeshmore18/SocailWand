//
//  CloudClipboardSyncService.swift
//  SocialWandKeyboard
//

import CloudKit
import CryptoKit
import Foundation
import ImageIO
import CoreImage
import UIKit

final class CloudClipboardSyncService {
    static let shared = CloudClipboardSyncService()
    static let subscriptionID = "clipboard-item-changes"
    static let didSyncNotification = Notification.Name("CloudClipboardDidSync")

    private let appGroupID = "group.com.rishimore.socialwand"
    private let clipboardKey = "SavedClipboardItems"
    private let pendingUpsertsKey = "CloudClipboardPendingUpserts"
    private let pendingDeletesKey = "CloudClipboardPendingDeletes"
    private let migrationFlagKey = "CloudClipboardDidMigrateModifiedAt"
    private let signatureCleanupFlagKey = "CloudClipboardDidCleanupSignatures"
    private let disableContentSignatureUploadKey = "CloudClipboardDisableContentSignatureUpload"
    private let maxTotalItems = 7
    private let recordType = "ClipboardItem"

    private let container: CKContainer
    private let database: CKDatabase
    private enum FetchMode {
        case normal
        case activeUI
    }

    private let fetchStateQueue = DispatchQueue(label: "cloud.clipboard.fetch.state")
    private var fetchInFlight = false
    private var lastFetchAt: Date?
    private var fetchMode: FetchMode = .normal
    private var lastUserSaveAt: Date?
    private let fetchMinimumInterval: TimeInterval = 2
    private let fastFetchMinimumInterval: TimeInterval = 1
    private let userSaveBypassInterval: TimeInterval = 3

    private init(container: CKContainer = CKContainer(identifier: "iCloud.rishi-more.social-wand")) {
        self.container = container
        self.database = container.privateCloudDatabase
        resetContentSignatureUploadIfNeeded()
    }

    enum Availability {
        case available
        case noOpenAccess
        case noICloud
        case restricted
        case unknown
    }

    func checkSyncAvailability(requiresOpenAccess: Bool, completion: @escaping (Availability) -> Void) {
        if requiresOpenAccess && !isOpenAccessEnabled() {
            completion(.noOpenAccess)
            return
        }

        container.accountStatus { status, error in
            if let error = error {
                self.logCloudKitError(error, context: "account status")
            }
            switch status {
            case .available:
                completion(.available)
            case .noAccount:
                completion(.noICloud)
            case .restricted:
                completion(.restricted)
            default:
                completion(.unknown)
            }
        }
    }

    func handleLocalUpsert(_ clip: ClipboardItem, requiresOpenAccess: Bool) {
        noteUserSave()
        enqueueUpsert(id: clip.id)
        pushLocalChanges(requiresOpenAccess: requiresOpenAccess)
    }

    func handleLocalDelete(id: String, requiresOpenAccess: Bool) {
        noteUserSave()
        var localClips = loadLocalClips()
        if let index = localClips.firstIndex(where: { $0.id == id }) {
            localClips[index].isDeleted = true
            localClips[index].markModified()
            saveLocalClips(localClips)
            enqueueUpsert(id: id)
        } else {
            enqueueDelete(id: id)
        }
        pushLocalChanges(requiresOpenAccess: requiresOpenAccess)
    }

    func handleLocalClear(ids: [String], requiresOpenAccess: Bool) {
        noteUserSave()
        var localClips = loadLocalClips()
        var updated = false
        for id in ids {
            if let index = localClips.firstIndex(where: { $0.id == id }) {
                localClips[index].isDeleted = true
                localClips[index].markModified()
                enqueueUpsert(id: id)
                updated = true
            } else {
                enqueueDelete(id: id)
            }
        }
        if updated {
            saveLocalClips(localClips)
        }
        pushLocalChanges(requiresOpenAccess: requiresOpenAccess)
    }

    func pushLocalChanges(requiresOpenAccess: Bool, completion: ((Bool) -> Void)? = nil) {
        performModifiedAtMigrationIfNeeded()
        performSignatureCleanupIfNeeded()

        checkSyncAvailability(requiresOpenAccess: requiresOpenAccess) { [weak self] availability in
            guard let self = self, availability == .available else {
                completion?(false)
                return
            }

            DispatchQueue.global(qos: .utility).async {
                let pendingDeletes = Set(self.loadPendingIDs(forKey: self.pendingDeletesKey))
                let pendingUpserts = Set(self.loadPendingIDs(forKey: self.pendingUpsertsKey))
                let upserts = pendingUpserts.subtracting(pendingDeletes)

                guard !pendingDeletes.isEmpty || !upserts.isEmpty else {
                    completion?(true)
                    return
                }

                let group = DispatchGroup()
                let lockQueue = DispatchQueue(label: "cloud.clipboard.sync.lock")
                var successfulDeletes: [String] = []
                var successfulUpserts: [String] = []

                for id in pendingDeletes {
                    group.enter()
                    let recordID = CKRecord.ID(recordName: id)
                    self.database.delete(withRecordID: recordID) { _, error in
                        if error == nil {
                            lockQueue.async {
                                successfulDeletes.append(id)
                                group.leave()
                            }
                        } else {
                            if let error = error {
                                self.logCloudKitError(error, context: "delete \(id)")
                            }
                            group.leave()
                        }
                    }
                }

                group.notify(queue: .global(qos: .utility)) {
                    if !successfulDeletes.isEmpty {
                        self.removePending(ids: successfulDeletes, forKey: self.pendingDeletesKey)
                    }

                    let localClips = self.loadLocalClips()
                    let localByID = Dictionary(uniqueKeysWithValues: localClips.map { ($0.id, $0) })

                    let recordsToSave: [CKRecord] = upserts.compactMap { id in
                        guard let clip = localByID[id] else {
                            return nil
                        }
                        return self.record(for: clip)
                    }

                    guard !recordsToSave.isEmpty else {
                        completion?(true)
                        return
                    }

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
                            self.removePending(ids: successfulUpserts, forKey: self.pendingUpsertsKey)
                        }
                        completion?(true)
                    }

                    self.database.add(operation)
                }
            }
        }
    }

    func fetchRemoteChanges(completion: ((Bool) -> Void)? = nil) {
        fetchStateQueue.async { [weak self] in
            guard let self = self else { return }
            let now = Date()

            if self.fetchInFlight {
                completion?(true)
                return
            }

            let minimumInterval = (self.fetchMode == .activeUI) ? self.fastFetchMinimumInterval : self.fetchMinimumInterval
            let shouldBypass = self.lastUserSaveAt.map { now.timeIntervalSince($0) < self.userSaveBypassInterval } ?? false
            if !shouldBypass,
               let lastFetchAt = self.lastFetchAt,
               now.timeIntervalSince(lastFetchAt) < minimumInterval {
                completion?(true)
                return
            }

            self.fetchInFlight = true
            self.lastFetchAt = now

            self.checkSyncAvailability(requiresOpenAccess: false) { [weak self] availability in
                guard let self = self else {
                    completion?(false)
                    return
                }
                guard availability == .available else {
                    self.fetchStateQueue.async {
                        self.fetchInFlight = false
                    }
                    completion?(false)
                    return
                }

                // Query by a queryable field instead of matching all
                // This avoids CloudKit trying to use recordName
                let query = CKQuery(
                    recordType: self.recordType,
                    predicate: NSPredicate(format: "modifiedAt >= %@", Date.distantPast as NSDate)
                )
                let sort = NSSortDescriptor(key: "modifiedAt", ascending: false)
                query.sortDescriptors = [sort]

                self.database.perform(query, inZoneWith: nil) { records, error in
                    defer {
                        self.fetchStateQueue.async {
                            self.fetchInFlight = false
                        }
                    }

                    guard let records = records, error == nil else {
                        if let error = error {
                            self.logCloudKitError(error, context: "fetch")
                        }
                        completion?(false)
                        return
                    }

                    let remoteClips = records.compactMap { self.clip(from: $0) }
                    self.mergeRemoteClips(remoteClips)
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: Self.didSyncNotification, object: nil)
                    }
                    completion?(true)
                }
            }
        }
    }

    func setFetchMode(active: Bool) {
        fetchStateQueue.async { [weak self] in
            self?.fetchMode = active ? .activeUI : .normal
        }
    }

    private func noteUserSave() {
        fetchStateQueue.async { [weak self] in
            self?.lastUserSaveAt = Date()
        }
    }

    func registerSubscription() {
        database.fetch(withSubscriptionID: Self.subscriptionID) { [weak self] existing, _ in
            guard let self = self, existing == nil else { return }

            let subscription = CKQuerySubscription(
                recordType: self.recordType,
                predicate: NSPredicate(value: true),
                subscriptionID: Self.subscriptionID,
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )

            let info = CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true
            subscription.notificationInfo = info

            self.database.save(subscription) { _, _ in }
        }
    }

    // MARK: - Record Mapping

    private func record(for clip: ClipboardItem) -> CKRecord? {
        let recordID = CKRecord.ID(recordName: clip.id)
        let record = CKRecord(recordType: recordType, recordID: recordID)

        record["type"] = clip.type.rawValue as CKRecordValue
        record["isBookmarked"] = clip.isBookmarked as CKRecordValue
        record["timestamp"] = clip.timestamp as CKRecordValue
        record["modifiedAt"] = clip.modifiedAt as CKRecordValue
        record["isDeleted"] = clip.isDeleted as CKRecordValue
        if shouldUploadContentSignature, clip.contentSignature.isEmpty == false {
            record["contentSignature"] = clip.contentSignature as CKRecordValue
        }

        if clip.isDeleted {
            return record
        }

        switch clip.type {
        case .text:
            if let text = clip.textContent {
                record["text"] = text as CKRecordValue
            }
        case .image:
            guard let clipboardDir = clipboardDirectory() else { return nil }

            guard let imageFilename = clip.imageFilename else {
                print("⚠️ Missing image filename for clip \(clip.id)")
                return nil
            }
            let imageURL = clipboardDir.appendingPathComponent(imageFilename)
            guard FileManager.default.fileExists(atPath: imageURL.path) else {
                print("⚠️ Missing image file for clip \(clip.id)")
                return nil
            }

            record["imageAsset"] = CKAsset(fileURL: imageURL)
            record["imageFilename"] = imageFilename as CKRecordValue

            if let thumbFilename = clip.thumbnailFilename {
                let thumbURL = clipboardDir.appendingPathComponent(thumbFilename)
                if FileManager.default.fileExists(atPath: thumbURL.path) {
                    record["thumbnailAsset"] = CKAsset(fileURL: thumbURL)
                    record["thumbnailFilename"] = thumbFilename as CKRecordValue
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
        let isBookmarked = record["isBookmarked"] as? Bool ?? false
        let isDeleted = record["isDeleted"] as? Bool ?? false
        let timestamp = record["timestamp"] as? Date ?? Date()
        let modifiedAt = record["modifiedAt"] as? Date ?? record.modificationDate ?? timestamp
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
                if let imageAsset = record["imageAsset"] as? CKAsset {
                    _ = persistAsset(imageAsset, filename: imageFilename)
                }
                if let thumbAsset = record["thumbnailAsset"] as? CKAsset {
                    _ = persistAsset(thumbAsset, filename: thumbnailFilename)
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

    // MARK: - Local Cache

    private func mergeRemoteClips(_ remoteClips: [ClipboardItem]) {
        enableContentSignatureUploadIfAvailable(remoteClips)

        let local = loadLocalClips()
        let pendingUpserts = Set(loadPendingIDs(forKey: pendingUpsertsKey))

        var merged: [String: ClipboardItem] = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })

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

        let repairedIDs = repairImageSignatures(in: &mergedClips)
        if !repairedIDs.isEmpty {
            repairedIDs.forEach { enqueueUpsert(id: $0) }
        }

        let dedupeResult = dedupeClipsBySignature(mergedClips)
        mergedClips = dedupeResult.clips
        var pendingDeletes = dedupeResult.newlyDeleted

        // Remove local files for deleted items
        for clip in mergedClips where clip.isDeleted && clip.type == .image {
            deleteLocalFiles(clip: clip)
        }

        let newlyDeleted = enforceLimit(clips: &mergedClips)
        pendingDeletes.append(contentsOf: newlyDeleted)
        if !pendingDeletes.isEmpty {
            pendingDeletes.forEach { enqueueUpsert(id: $0.id) }
            pushLocalChanges(requiresOpenAccess: false)
        }

        mergedClips.sort {
            if $0.isBookmarked != $1.isBookmarked {
                return $0.isBookmarked && !$1.isBookmarked
            }
            if $0.timestamp != $1.timestamp {
                return $0.timestamp > $1.timestamp
            }
            return $0.id < $1.id
        }
        saveLocalClips(mergedClips)
    }

    private func enableContentSignatureUploadIfAvailable(_ remoteClips: [ClipboardItem]) {
        guard shouldUploadContentSignature == false else { return }
        guard remoteClips.contains(where: { !$0.contentSignature.isEmpty }) else { return }

        clearContentSignatureUploadDisableFlag()
        enqueueSignatureBackfill()
    }

    private func clearContentSignatureUploadDisableFlag() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(false, forKey: disableContentSignatureUploadKey)
    }

    private func enqueueSignatureBackfill() {
        let local = loadLocalClips()
        let ids = local.filter { !$0.contentSignature.isEmpty }.map { $0.id }
        guard !ids.isEmpty else { return }
        ids.forEach { enqueueUpsert(id: $0) }
        pushLocalChanges(requiresOpenAccess: false)
    }

    private func dedupeClipsBySignature(_ clips: [ClipboardItem]) -> (clips: [ClipboardItem], newlyDeleted: [ClipboardItem]) {
        var bestBySignature: [String: ClipboardItem] = [:]
        var keepIds = Set<String>()
        var newlyDeleted: [ClipboardItem] = []

        for clip in clips {
            let signature = clip.contentSignature
            guard !signature.isEmpty else {
                keepIds.insert(clip.id)
                continue
            }

            if let existing = bestBySignature[signature] {
                let preferred = choosePreferredClip(existing, clip)
                bestBySignature[signature] = preferred
                keepIds.insert(preferred.id)
                if preferred.id != existing.id {
                    keepIds.remove(existing.id)
                }
            } else {
                bestBySignature[signature] = clip
                keepIds.insert(clip.id)
            }
        }

        var updatedClips: [ClipboardItem] = []
        for var clip in clips {
            if keepIds.contains(clip.id) {
                updatedClips.append(clip)
                continue
            }

            if !clip.isDeleted {
                if clip.type == .image {
                    deleteLocalFiles(clip: clip)
                }
                clip.isDeleted = true
                clip.markModified()
                newlyDeleted.append(clip)
            }
            updatedClips.append(clip)
        }

        return (updatedClips, newlyDeleted)
    }

    private func choosePreferredClip(_ lhs: ClipboardItem, _ rhs: ClipboardItem) -> ClipboardItem {
        if lhs.isDeleted != rhs.isDeleted {
            return lhs.isDeleted ? rhs : lhs
        }
        if lhs.modifiedAt != rhs.modifiedAt {
            return lhs.modifiedAt > rhs.modifiedAt ? lhs : rhs
        }
        if lhs.timestamp != rhs.timestamp {
            return lhs.timestamp > rhs.timestamp ? lhs : rhs
        }
        if lhs.isBookmarked != rhs.isBookmarked {
            return lhs.isBookmarked ? lhs : rhs
        }
        return lhs.id < rhs.id ? lhs : rhs
    }

    private func repairImageSignatures(in clips: inout [ClipboardItem]) -> [String] {
        guard let directory = clipboardDirectory() else { return [] }
        var updatedIDs: [String] = []

        for index in clips.indices {
            guard clips[index].type == .image else { continue }
            let signature = clips[index].contentSignature
            if !signature.isEmpty, signature.hasPrefix("image:ahash:") {
                continue
            }
            guard let filename = clips[index].imageFilename else { continue }
            let url = directory.appendingPathComponent(filename)
            guard let image = UIImage(contentsOfFile: url.path),
                  let newSignature = signatureForImage(image) else {
                continue
            }
            if clips[index].contentSignature != newSignature {
                clips[index].contentSignature = newSignature
                clips[index].markModified()
                updatedIDs.append(clips[index].id)
            }
        }

        return updatedIDs
    }

    private func performSignatureCleanupIfNeeded() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        guard defaults.bool(forKey: signatureCleanupFlagKey) == false else { return }

        let local = loadLocalClips()
        let dedupeResult = dedupeClipsBySignature(local)
        let updated = dedupeResult.newlyDeleted.isEmpty == false

        if updated {
            saveLocalClips(dedupeResult.clips)
            dedupeResult.newlyDeleted.forEach { enqueueUpsert(id: $0.id) }
        }

        defaults.set(true, forKey: signatureCleanupFlagKey)
    }

    private func signatureForImage(_ image: UIImage) -> String? {
        guard let hash = averageHash(for: image) else { return nil }
        return "image:ahash:\(hash)"
    }

    private func imageSignatureData(_ image: UIImage) -> Data? {
        let targetSize = CGSize(width: 32, height: 32)
        guard let cgImage = normalizedCGImage(from: image) else { return nil }
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

        var data = Data(count: height * bytesPerRow)
        let success = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
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

    private func normalizedPngSignatureData(_ image: UIImage) -> Data? {
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: 32, height: 32),
            format: UIGraphicsImageRendererFormat.default()
        )
        let output = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: CGSize(width: 32, height: 32)))
        }
        return output.pngData()
    }

    private func averageHash(for image: UIImage) -> String? {
        guard let cgImage = normalizedCGImage(from: image) else { return nil }
        let size = 8
        let bytesPerRow = size
        let colorSpace = CGColorSpaceCreateDeviceGray()

        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))

        guard let data = context.data else { return nil }
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        var sum = 0
        for i in 0..<(size * size) {
            sum += Int(pixels[i])
        }
        let average = UInt8(sum / (size * size))

        var hash: UInt64 = 0
        for i in 0..<(size * size) {
            if pixels[i] > average {
                hash |= (1 << UInt64(i))
            }
        }

        return String(format: "%016llx", hash)
    }

    private func normalizedCGImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cgImage = image.cgImage {
            return cgImage
        }
        let ciImage = image.ciImage ?? CIImage(image: image)
        guard let source = ciImage else { return nil }
        let oriented = source.oriented(forExifOrientation: exifOrientation(from: image.imageOrientation))
        return CIContext().createCGImage(oriented, from: oriented.extent)
    }

    private func exifOrientation(from orientation: UIImage.Orientation) -> Int32 {
        switch orientation {
        case .up: return Int32(CGImagePropertyOrientation.up.rawValue)
        case .down: return Int32(CGImagePropertyOrientation.down.rawValue)
        case .left: return Int32(CGImagePropertyOrientation.left.rawValue)
        case .right: return Int32(CGImagePropertyOrientation.right.rawValue)
        case .upMirrored: return Int32(CGImagePropertyOrientation.upMirrored.rawValue)
        case .downMirrored: return Int32(CGImagePropertyOrientation.downMirrored.rawValue)
        case .leftMirrored: return Int32(CGImagePropertyOrientation.leftMirrored.rawValue)
        case .rightMirrored: return Int32(CGImagePropertyOrientation.rightMirrored.rawValue)
        @unknown default:
            return Int32(CGImagePropertyOrientation.up.rawValue)
        }
    }

    private func loadLocalClips() -> [ClipboardItem] {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: clipboardKey) else {
            return []
        }

        guard let clips = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            return []
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

    private func enforceLimit(clips: inout [ClipboardItem]) -> [ClipboardItem] {
        let activeClips = clips.filter { !$0.isDeleted }
        let bookmarked = activeClips.filter { $0.isBookmarked }.sorted { $0.timestamp > $1.timestamp }
        var regular = activeClips.filter { !$0.isBookmarked }.sorted { $0.timestamp > $1.timestamp }
        let allowedRegular = max(0, maxTotalItems - bookmarked.count)

        var deletedClips: [ClipboardItem] = []
        if regular.count > allowedRegular {
            let toRemove = regular.suffix(regular.count - allowedRegular)
            for clip in toRemove {
                if let index = clips.firstIndex(where: { $0.id == clip.id }) {
                    if clips[index].type == .image {
                        deleteLocalFiles(clip: clips[index])
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

    private func performModifiedAtMigrationIfNeeded() {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              !defaults.bool(forKey: migrationFlagKey) else {
            return
        }

        let clips = loadLocalClips()
        guard !clips.isEmpty else {
            defaults.set(true, forKey: migrationFlagKey)
            return
        }

        // Queue upserts so existing records get a modifiedAt field
        clips.forEach { enqueueUpsert(id: $0.id) }
        defaults.set(true, forKey: migrationFlagKey)
    }

    // MARK: - Pending Queue

    private func enqueueUpsert(id: String) {
        var pending = Set(loadPendingIDs(forKey: pendingUpsertsKey))
        pending.insert(id)
        savePendingIDs(Array(pending), forKey: pendingUpsertsKey)
    }

    private func enqueueDelete(id: String) {
        var pending = Set(loadPendingIDs(forKey: pendingDeletesKey))
        pending.insert(id)
        savePendingIDs(Array(pending), forKey: pendingDeletesKey)
    }

    private func removePending(ids: [String], forKey key: String) {
        var pending = Set(loadPendingIDs(forKey: key))
        pending.subtract(ids)
        savePendingIDs(Array(pending), forKey: key)
    }

    private func loadPendingIDs(forKey key: String) -> [String] {
        let defaults = UserDefaults(suiteName: appGroupID)
        return defaults?.stringArray(forKey: key) ?? []
    }

    private func savePendingIDs(_ ids: [String], forKey key: String) {
        let defaults = UserDefaults(suiteName: appGroupID)
        defaults?.set(ids, forKey: key)
    }

    // MARK: - File Helpers

    private func clipboardDirectory() -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            return nil
        }

        let clipboardDir = containerURL.appendingPathComponent("clipboard", isDirectory: true)
        if !FileManager.default.fileExists(atPath: clipboardDir.path) {
            try? FileManager.default.createDirectory(at: clipboardDir, withIntermediateDirectories: true)
        }

        return clipboardDir
    }

    private func persistAsset(_ asset: CKAsset, filename: String) -> Bool {
        guard let sourceURL = asset.fileURL,
              let clipboardDir = clipboardDirectory() else { return false }

        let destinationURL = clipboardDir.appendingPathComponent(filename)
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
        guard let clipboardDir = clipboardDirectory() else { return }

        if let imageFile = clip.imageFilename {
            let imageURL = clipboardDir.appendingPathComponent(imageFile)
            try? FileManager.default.removeItem(at: imageURL)
        }

        if let thumbFile = clip.thumbnailFilename {
            let thumbURL = clipboardDir.appendingPathComponent(thumbFile)
            try? FileManager.default.removeItem(at: thumbURL)
        }
    }

    private func signatureForText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hash = SHA256.hash(data: Data(trimmed.utf8))
        return "text:\(hash.hexString)"
    }

    private func legacyImageSignature(_ filename: String) -> String {
        "image:legacy:\(filename)"
    }

    // MARK: - Open Access

    private func isOpenAccessEnabled() -> Bool {
        let defaults = UserDefaults(suiteName: appGroupID)
        return defaults?.bool(forKey: "KeyboardFullAccess") ?? false
    }

    private var shouldUploadContentSignature: Bool {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return true }
        return defaults.bool(forKey: disableContentSignatureUploadKey) == false
    }

    private func disableContentSignatureUpload() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(true, forKey: disableContentSignatureUploadKey)
    }

    private func resetContentSignatureUploadIfNeeded() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        guard defaults.bool(forKey: disableContentSignatureUploadKey) else { return }
        defaults.set(false, forKey: disableContentSignatureUploadKey)
    }

    private func isContentSignatureSchemaError(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        guard ckError.code == .serverRejectedRequest else { return false }
        let message = ckError.localizedDescription.lowercased()
        return message.contains("contentsignature")
    }

    private func logCloudKitError(_ error: Error, context: String) {
        if let ckError = error as? CKError {
            print("CloudClipboardSync \(context) failed: \(ckError.code.rawValue) \(ckError.localizedDescription)")
            if isContentSignatureSchemaError(ckError) {
                disableContentSignatureUpload()
                if context.hasPrefix("save ") {
                    pushLocalChanges(requiresOpenAccess: false)
                }
            }
        } else {
            print("CloudClipboardSync \(context) failed: \(error.localizedDescription)")
        }
    }
}

private extension SHA256.Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
