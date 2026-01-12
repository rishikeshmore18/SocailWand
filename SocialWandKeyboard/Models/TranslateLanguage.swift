//
//  TranslateLanguage.swift
//  SocialWandKeyboard
//

import Foundation

struct TranslateLanguage: Identifiable, Hashable {
    let id: String
    let name: String
    let flag: String
}

enum TranslateLanguageCatalog {
    static let languages: [TranslateLanguage] = [
        TranslateLanguage(id: "ar", name: "Arabic", flag: "🇸🇦"),
        TranslateLanguage(id: "bn", name: "Bangla", flag: "🇧🇩"),
        TranslateLanguage(id: "bg", name: "Bulgarian", flag: "🇧🇬"),
        TranslateLanguage(id: "zh-CN", name: "Chinese (CN)", flag: "🇨🇳"),
        TranslateLanguage(id: "zh-TW", name: "Chinese (TW)", flag: "🇹🇼"),
        TranslateLanguage(id: "hr", name: "Croatian", flag: "🇭🇷"),
        TranslateLanguage(id: "cs", name: "Czech", flag: "🇨🇿"),
        TranslateLanguage(id: "da", name: "Danish", flag: "🇩🇰"),
        TranslateLanguage(id: "nl", name: "Dutch", flag: "🇳🇱"),
        TranslateLanguage(id: "en-GB", name: "English (GB)", flag: "🇬🇧"),
        TranslateLanguage(id: "en-US", name: "English (US)", flag: "🇺🇸"),
        TranslateLanguage(id: "et", name: "Estonian", flag: "🇪🇪"),
        TranslateLanguage(id: "fi", name: "Finnish", flag: "🇫🇮"),
        TranslateLanguage(id: "fr", name: "French", flag: "🇫🇷"),
        TranslateLanguage(id: "de", name: "German", flag: "🇩🇪"),
        TranslateLanguage(id: "el", name: "Greek", flag: "🇬🇷"),
        TranslateLanguage(id: "he", name: "Hebrew", flag: "🇮🇱"),
        TranslateLanguage(id: "hi", name: "Hindi", flag: "🇮🇳"),
        TranslateLanguage(id: "hu", name: "Hungarian", flag: "🇭🇺"),
        TranslateLanguage(id: "id", name: "Indonesian", flag: "🇮🇩"),
        TranslateLanguage(id: "it", name: "Italian", flag: "🇮🇹"),
        TranslateLanguage(id: "ja", name: "Japanese", flag: "🇯🇵"),
        TranslateLanguage(id: "ko", name: "Korean", flag: "🇰🇷"),
        TranslateLanguage(id: "lv", name: "Latvian", flag: "🇱🇻"),
        TranslateLanguage(id: "lt", name: "Lithuanian", flag: "🇱🇹"),
        TranslateLanguage(id: "ms", name: "Malay", flag: "🇲🇾"),
        TranslateLanguage(id: "mr", name: "Marathi", flag: "🇮🇳"),
        TranslateLanguage(id: "no", name: "Norwegian", flag: "🇳🇴"),
        TranslateLanguage(id: "fa", name: "Persian", flag: "🇮🇷"),
        TranslateLanguage(id: "pl", name: "Polish", flag: "🇵🇱"),
        TranslateLanguage(id: "pt", name: "Portuguese", flag: "🇵🇹"),
        TranslateLanguage(id: "ro", name: "Romanian", flag: "🇷🇴"),
        TranslateLanguage(id: "ru", name: "Russian", flag: "🇷🇺"),
        TranslateLanguage(id: "sr", name: "Serbian", flag: "🇷🇸"),
        TranslateLanguage(id: "sk", name: "Slovak", flag: "🇸🇰"),
        TranslateLanguage(id: "sl", name: "Slovenian", flag: "🇸🇮"),
        TranslateLanguage(id: "es", name: "Spanish", flag: "🇪🇸"),
        TranslateLanguage(id: "sv", name: "Swedish", flag: "🇸🇪"),
        TranslateLanguage(id: "tl", name: "Tagalog", flag: "🇵🇭"),
        TranslateLanguage(id: "ta", name: "Tamil", flag: "🇮🇳"),
        TranslateLanguage(id: "te", name: "Telugu", flag: "🇮🇳"),
        TranslateLanguage(id: "th", name: "Thai", flag: "🇹🇭"),
        TranslateLanguage(id: "tr", name: "Turkish", flag: "🇹🇷"),
        TranslateLanguage(id: "uk", name: "Ukrainian", flag: "🇺🇦"),
        TranslateLanguage(id: "vi", name: "Vietnamese", flag: "🇻🇳")
    ]

    static func language(for id: String) -> TranslateLanguage? {
        languages.first { $0.id == id }
    }
}
