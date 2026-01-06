//
//  ClipboardItem.swift
//  social wand
//

import Foundation

struct ClipboardItem: Codable, Identifiable {
    let id: String
    let type: ClipboardItemType
    let timestamp: Date
    var isBookmarked: Bool

    let textContent: String?
    let imageFilename: String?
    let thumbnailFilename: String?

    enum ClipboardItemType: String, Codable {
        case text
        case image
    }

    init(text: String, isBookmarked: Bool = false) {
        self.id = UUID().uuidString
        self.type = .text
        self.timestamp = Date()
        self.isBookmarked = isBookmarked
        self.textContent = text
        self.imageFilename = nil
        self.thumbnailFilename = nil
    }

    init(imageFilename: String, thumbnailFilename: String, isBookmarked: Bool = false) {
        self.id = UUID().uuidString
        self.type = .image
        self.timestamp = Date()
        self.isBookmarked = isBookmarked
        self.textContent = nil
        self.imageFilename = imageFilename
        self.thumbnailFilename = thumbnailFilename
    }

    init(
        id: String,
        type: ClipboardItemType,
        timestamp: Date,
        isBookmarked: Bool,
        textContent: String?,
        imageFilename: String?,
        thumbnailFilename: String?
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.isBookmarked = isBookmarked
        self.textContent = textContent
        self.imageFilename = imageFilename
        self.thumbnailFilename = thumbnailFilename
    }
}
