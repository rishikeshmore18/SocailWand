import Foundation

struct MacLocalClipboardItem: Codable, Identifiable {
    enum ClipType: String, Codable {
        case text
        case image
    }

    let id: String
    let type: ClipType
    let timestamp: Date
    var modifiedAt: Date
    var isBookmarked: Bool
    var isDeleted: Bool
    let textContent: String?
    let imageFilename: String?
    let thumbnailFilename: String?

    init(text: String, isBookmarked: Bool = false) {
        let now = Date()
        self.id = UUID().uuidString
        self.type = .text
        self.timestamp = now
        self.modifiedAt = now
        self.isBookmarked = isBookmarked
        self.isDeleted = false
        self.textContent = text
        self.imageFilename = nil
        self.thumbnailFilename = nil
    }

    init(imageFilename: String, thumbnailFilename: String, isBookmarked: Bool = false) {
        let now = Date()
        self.id = UUID().uuidString
        self.type = .image
        self.timestamp = now
        self.modifiedAt = now
        self.isBookmarked = isBookmarked
        self.isDeleted = false
        self.textContent = nil
        self.imageFilename = imageFilename
        self.thumbnailFilename = thumbnailFilename
    }

    init(
        id: String,
        type: ClipType,
        timestamp: Date,
        modifiedAt: Date? = nil,
        isBookmarked: Bool,
        isDeleted: Bool,
        textContent: String?,
        imageFilename: String?,
        thumbnailFilename: String?
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.modifiedAt = modifiedAt ?? timestamp
        self.isBookmarked = isBookmarked
        self.isDeleted = isDeleted
        self.textContent = textContent
        self.imageFilename = imageFilename
        self.thumbnailFilename = thumbnailFilename
    }

    mutating func markModified(_ date: Date = Date()) {
        modifiedAt = date
    }
}
