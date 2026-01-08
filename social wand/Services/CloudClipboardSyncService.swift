//
//  CloudClipboardSyncService.swift
//  social wand
//

import CloudKit
import Foundation
import UIKit

final class CloudClipboardSyncService {
    static let shared = CloudClipboardSyncService()
    static let subscriptionID = "clipboard-item-changes"

    private let appGroupID = "group.com.rishimore.socialwand"
    private let clipboardKey = "SavedClipboardItems"
    private let pendingUpsertsKey = "CloudClipboardPendingUpserts"
    private let pendingDeletesKey = "CloudClipboardPendingDeletes"
    private let maxTotalItems = 7
    private let recordType = "ClipboardItem"

    private let container: CKContainer
    private let database: CKDatabase

    private init(container: CKContainer = CKContainer(identifier: "iCloud.rishi-more.social-wand")) {
        self.container = container
        self.database = container.privateCloudDatabase
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

        container.accountStatus { status, _ in
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
        enqueueUpsert(id: clip.id)
        pushLocalChanges(requiresOpenAccess: requiresOpenAccess)
    }

    func handleLocalDelete(id: String, requiresOpenAccess: Bool) {
        enqueueDelete(id: id)
        pushLocalChanges(requiresOpenAccess: requiresOpenAccess)
    }

    func handleLocalClear(ids: [String], requiresOpenAccess: Bool) {
        for id in ids {
            enqueueDelete(id: id)
        }
        pushLocalChanges(requiresOpenAccess: requiresOpenAccess)
    }

    func pushLocalChanges(requiresOpenAccess: Bool, completion: ((Bool) -> Void)? = nil) {
        checkSyncAvailability(requiresOpenAccess: requiresOpenAccess) { [weak self] availability in
            guard let self = self, availability == .available else {
                completion?(false)
                return
            }

            DispatchQueue.global(qos: .utility).async {
                let pendingDeletes = Set(self.loadPendingIDs(forKey: self.pendingDeletesKey))
                let pendingUpserts = Set(self.loadPendingIDs(forKey: self.pendingUpsertsKey))
                let upserts = pendingUpserts.subtracting(pendingDeletes)

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

                    let upsertGroup = DispatchGroup()
                    for id in upserts {
                        guard let clip = localByID[id],
                              let record = self.record(for: clip) else {
                            continue
                        }
                        upsertGroup.enter()
                        self.database.save(record) { _, error in
                            if error == nil {
                                lockQueue.async {
                                    successfulUpserts.append(id)
                                    upsertGroup.leave()
                                }
                            } else {
                                upsertGroup.leave()
                            }
                        }
                    }

                    upsertGroup.notify(queue: .global(qos: .utility)) {
                        if !successfulUpserts.isEmpty {
                            self.removePending(ids: successfulUpserts, forKey: self.pendingUpsertsKey)
                        }
                        completion?(true)
                    }
                }
            }
        }
    }

    func fetchRemoteChanges(completion: ((Bool) -> Void)? = nil) {
        checkSyncAvailability(requiresOpenAccess: false) { [weak self] availability in
            guard let self = self, availability == .available else {
                completion?(false)
                return
            }

            let query = CKQuery(recordType: self.recordType, predicate: NSPredicate(value: true))
            let sort = NSSortDescriptor(key: "modifiedAt", ascending: false)
            query.sortDescriptors = [sort]

            self.database.perform(query, inZoneWith: nil) { records, error in
                guard let records = records, error == nil else {
                    completion?(false)
                    return
                }

                let remoteClips = records.compactMap { self.clip(from: $0) }
                self.mergeRemoteClips(remoteClips)
                completion?(true)
            }
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
        record["modifiedAt"] = Date() as CKRecordValue

        switch clip.type {
        case .text:
            if let text = clip.textContent {
                record["text"] = text as CKRecordValue
            }
        case .image:
            guard let clipboardDir = clipboardDirectory() else { return nil }

            if let imageFilename = clip.imageFilename {
                let imageURL = clipboardDir.appendingPathComponent(imageFilename)
                if FileManager.default.fileExists(atPath: imageURL.path) {
                    record["imageAsset"] = CKAsset(fileURL: imageURL)
                }
            }

            if let thumbFilename = clip.thumbnailFilename {
                let thumbURL = clipboardDir.appendingPathComponent(thumbFilename)
                if FileManager.default.fileExists(atPath: thumbURL.path) {
                    record["thumbnailAsset"] = CKAsset(fileURL: thumbURL)
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
        let timestamp = record["timestamp"] as? Date ?? Date()

        switch type {
        case .text:
            let text = record["text"] as? String ?? ""
            return ClipboardItem(
                id: id,
                type: .text,
                timestamp: timestamp,
                isBookmarked: isBookmarked,
                textContent: text,
                imageFilename: nil,
                thumbnailFilename: nil
            )
        case .image:
            let imageFilename = "image_\(id).png"
            let thumbnailFilename = "thumb_\(id).png"
            if let imageAsset = record["imageAsset"] as? CKAsset {
                _ = persistAsset(imageAsset, filename: imageFilename)
            }
            if let thumbAsset = record["thumbnailAsset"] as? CKAsset {
                _ = persistAsset(thumbAsset, filename: thumbnailFilename)
            }
            return ClipboardItem(
                id: id,
                type: .image,
                timestamp: timestamp,
                isBookmarked: isBookmarked,
                textContent: nil,
                imageFilename: imageFilename,
                thumbnailFilename: thumbnailFilename
            )
        }
    }

    // MARK: - Local Cache

    private func mergeRemoteClips(_ remoteClips: [ClipboardItem]) {
        let local = loadLocalClips()
        let pendingUpserts = Set(loadPendingIDs(forKey: pendingUpsertsKey))
        let pendingDeletes = Set(loadPendingIDs(forKey: pendingDeletesKey))

        var merged: [String: ClipboardItem] = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        let remoteIDs = Set(remoteClips.map { $0.id })

        for remote in remoteClips {
            if let existing = merged[remote.id] {
                if remote.timestamp > existing.timestamp {
                    merged[remote.id] = remote
                }
            } else {
                merged[remote.id] = remote
            }
        }

        for clip in local {
            if !remoteIDs.contains(clip.id) && !pendingUpserts.contains(clip.id) {
                if clip.type == .image {
                    deleteLocalFiles(clip: clip)
                }
                merged.removeValue(forKey: clip.id)
            }
        }

        for id in pendingDeletes {
            merged.removeValue(forKey: id)
        }

        var mergedClips = Array(merged.values)
        enforceLimit(clips: &mergedClips)
        saveLocalClips(mergedClips)
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

    private func enforceLimit(clips: inout [ClipboardItem]) {
        let bookmarked = clips.filter { $0.isBookmarked }
        var regular = clips.filter { !$0.isBookmarked }
        let allowedRegular = max(0, maxTotalItems - bookmarked.count)

        if regular.count > allowedRegular {
            let toRemove = regular.suffix(regular.count - allowedRegular)
            for clip in toRemove where clip.type == .image {
                deleteLocalFiles(clip: clip)
            }
            regular = Array(regular.prefix(allowedRegular))
        }

        clips = bookmarked + regular
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

    // MARK: - Open Access

    private func isOpenAccessEnabled() -> Bool {
        let defaults = UserDefaults(suiteName: appGroupID)
        return defaults?.bool(forKey: "KeyboardFullAccess") ?? false
    }
}
