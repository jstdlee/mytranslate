import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

/// A language identified by a BCP-47 code such as "en", "zh-Hans" or "ja".
public struct Language: Codable, Hashable, Sendable, Identifiable {
    public var code: String
    public var id: String { code }

    public init(_ code: String) { self.code = code }

    /// "zh-Hans" → "zh".
    public var baseCode: String {
        String(code.split(separator: "-").first ?? Substring(code)).lowercased()
    }

    /// Same base language. Script and region are ignored, so zh-Hans matches zh-Hant.
    public func matches(_ other: Language) -> Bool { baseCode == other.baseCode }

    /// The name used inside prompts, in English: "Japanese", "Chinese, Simplified".
    public var englishName: String {
        Locale(identifier: "en").localizedString(forIdentifier: code) ?? code
    }

    /// The short name for a chip, in the language itself: "English", "中文", "日本語".
    public var chipLabel: String {
        switch code {
        case "zh-Hans": return "简体中文"
        case "zh-Hant": return "繁體中文"
        default:
            let name = Locale(identifier: code).localizedString(forLanguageCode: baseCode) ?? code
            return name.prefix(1).uppercased() + name.dropFirst()
        }
    }

    public static let english = Language("en")
    public static let chineseSimplified = Language("zh-Hans")
    public static let japanese = Language("ja")

    /// Languages offered in the pickers.
    public static let all: [Language] = [
        "en", "zh-Hans", "zh-Hant", "ja", "ko", "fr", "de", "es", "it", "pt",
        "ru", "ar", "hi", "vi", "th", "id", "tr", "nl", "pl", "uk",
    ].map(Language.init)
}

/// The user's languages: the chips in the sheet and the pair used to pick a target automatically.
public struct LanguagePrefs: Codable, Hashable, Sendable {
    /// Chips shown on the sheet, in order.
    public var pinned: [Language]
    /// The usual target.
    public var primary: Language
    /// The target when the text is already in the primary language.
    public var secondary: Language

    public init(pinned: [Language], primary: Language, secondary: Language) {
        self.pinned = pinned
        self.primary = primary
        self.secondary = secondary
    }

    public static let `default` = LanguagePrefs(
        pinned: [.chineseSimplified, .english, .japanese],
        primary: .english,
        secondary: .chineseSimplified
    )

    /// Target for text in `source`: the primary language, or the secondary one when the text is
    /// already in the primary language (zh → en, en → zh).
    public func autoTarget(for source: Language?) -> Language {
        guard let source, source.matches(primary) else { return primary }
        return secondary
    }
}

public protocol LanguageDetecting: Sendable {
    func detect(_ text: String) -> Language?
}

/// Detects the dominant language with NaturalLanguage, on the device.
public struct SystemLanguageDetector: LanguageDetecting {
    public init() {}

    public func detect(_ text: String) -> Language? {
        #if canImport(NaturalLanguage)
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage, language != .undetermined else { return nil }
        return Language(language.rawValue)
        #else
        return nil
        #endif
    }
}
