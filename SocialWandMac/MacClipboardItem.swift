import AppKit
import CloudKit

struct MacClipboardItem: Identifiable, Hashable {
    enum ClipType: String {
        case text
        case image
    }

    let id: String
    let type: ClipType
    let timestamp: Date
    let modifiedAt: Date
    let isBookmarked: Bool
    let isDeleted: Bool
    let textContent: String?
    let imageURL: URL?
    let thumbnailURL: URL?

    init(
        id: String,
        type: ClipType,
        timestamp: Date,
        modifiedAt: Date,
        isBookmarked: Bool,
        isDeleted: Bool,
        textContent: String?,
        imageURL: URL?,
        thumbnailURL: URL?
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.modifiedAt = modifiedAt
        self.isBookmarked = isBookmarked
        self.isDeleted = isDeleted
        self.textContent = textContent
        self.imageURL = imageURL
        self.thumbnailURL = thumbnailURL
    }

    init?(record: CKRecord) {
        guard let typeRaw = record["type"] as? String,
              let type = ClipType(rawValue: typeRaw) else {
            return nil
        }

        let id = record.recordID.recordName
        let timestamp = record["timestamp"] as? Date ?? Date()
        let modifiedAt = record["modifiedAt"] as? Date ?? record.modificationDate ?? timestamp
        let isBookmarked = record["isBookmarked"] as? Bool ?? false
        let isDeleted = record["isDeleted"] as? Bool ?? false

        let textContent = record["text"] as? String
        let imageURL = (record["imageAsset"] as? CKAsset)?.fileURL
        let thumbnailURL = (record["thumbnailAsset"] as? CKAsset)?.fileURL

        self.init(
            id: id,
            type: type,
            timestamp: timestamp,
            modifiedAt: modifiedAt,
            isBookmarked: isBookmarked,
            isDeleted: isDeleted,
            textContent: textContent,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL
        )
    }

    var displayText: String {
        if type == .text {
            return textContent ?? ""
        }
        return "Image"
    }

    var displayImage: NSImage? {
        guard type == .image else { return nil }
        if let url = thumbnailURL ?? imageURL {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}
