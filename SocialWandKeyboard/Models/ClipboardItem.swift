//
//  ClipboardItem.swift
//  SocialWandKeyboard
//

import Foundation

struct ClipboardItem: Codable, Identifiable {
    let id: String
    let type: ClipboardItemType
    let timestamp: Date
    var modifiedAt: Date
    var isBookmarked: Bool
    var isDeleted: Bool
    var contentSignature: String

    let textContent: String?
    let imageFilename: String?
    let thumbnailFilename: String?

    enum ClipboardItemType: String, Codable {
        case text
        case image
    }

    init(text: String, isBookmarked: Bool = false, contentSignature: String = "") {
        self.id = UUID().uuidString
        self.type = .text
        let now = Date()
        self.timestamp = now
        self.modifiedAt = now
        self.isBookmarked = isBookmarked
        self.isDeleted = false
        self.contentSignature = contentSignature
        self.textContent = text
        self.imageFilename = nil
        self.thumbnailFilename = nil
    }

    init(
        imageFilename: String,
        thumbnailFilename: String,
        isBookmarked: Bool = false,
        contentSignature: String = ""
    ) {
        self.id = UUID().uuidString
        self.type = .image
        let now = Date()
        self.timestamp = now
        self.modifiedAt = now
        self.isBookmarked = isBookmarked
        self.isDeleted = false
        self.contentSignature = contentSignature
        self.textContent = nil
        self.imageFilename = imageFilename
        self.thumbnailFilename = thumbnailFilename
    }

    init(
        id: String,
        type: ClipboardItemType,
        timestamp: Date,
        modifiedAt: Date? = nil,
        isBookmarked: Bool,
        isDeleted: Bool = false,
        contentSignature: String = "",
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
        self.contentSignature = contentSignature
        self.textContent = textContent
        self.imageFilename = imageFilename
        self.thumbnailFilename = thumbnailFilename
    }

    mutating func markModified(_ date: Date = Date()) {
        modifiedAt = date
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case timestamp
        case modifiedAt
        case isBookmarked
        case isDeleted
        case contentSignature
        case textContent
        case imageFilename
        case thumbnailFilename
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(ClipboardItemType.self, forKey: .type)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? timestamp
        isBookmarked = try container.decodeIfPresent(Bool.self, forKey: .isBookmarked) ?? false
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        contentSignature = try container.decodeIfPresent(String.self, forKey: .contentSignature) ?? ""
        textContent = try container.decodeIfPresent(String.self, forKey: .textContent)
        imageFilename = try container.decodeIfPresent(String.self, forKey: .imageFilename)
        thumbnailFilename = try container.decodeIfPresent(String.self, forKey: .thumbnailFilename)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(modifiedAt, forKey: .modifiedAt)
        try container.encode(isBookmarked, forKey: .isBookmarked)
        try container.encode(isDeleted, forKey: .isDeleted)
        try container.encode(contentSignature, forKey: .contentSignature)
        try container.encodeIfPresent(textContent, forKey: .textContent)
        try container.encodeIfPresent(imageFilename, forKey: .imageFilename)
        try container.encodeIfPresent(thumbnailFilename, forKey: .thumbnailFilename)
    }
}
