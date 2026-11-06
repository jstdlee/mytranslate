import Foundation

/// One chip on the sheet: a prompt template applied to the selected text.
public struct WritingAction: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case translate
        case transform
    }

    /// Which language the result is written in.
    public enum LanguageMode: String, Codable, Sendable {
        /// The target language chip.
        case target
        /// The language of the selected text, unless the user taps a language chip.
        case keepSource
    }

    public enum Output: String, Codable, Sendable {
        /// The result can replace the selection.
        case replace
        /// The result is for reading only (explain, summarize).
        case showOnly
    }

    public var id: String
    public var title: String
    /// SF Symbol name.
    public var symbol: String
    public var kind: Kind
    /// Instruction with {{variables}}; see `PromptBuilder.Variable`.
    public var template: String
    public var languageMode: LanguageMode
    public var output: Output
    public var pinned: Bool

    public init(
        id: String, title: String, symbol: String, kind: Kind = .transform, template: String,
        languageMode: LanguageMode = .keepSource, output: Output = .replace, pinned: Bool = true
    ) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.kind = kind
        self.template = template
        self.languageMode = languageMode
        self.output = output
        self.pinned = pinned
    }
}

public extension WritingAction {
    static let translate = WritingAction(
        id: "translate", title: "Translate", symbol: "translate", kind: .translate,
        template: "Translate the text into {{output_language}}. Keep the meaning, tone and formatting.",
        languageMode: .target
    )

    static let builtIn: [WritingAction] = [
        translate,
        WritingAction(
            id: "polish", title: "Polish", symbol: "wand.and.stars",
            template: "Rewrite the text so it reads clearly and naturally in {{output_language}}. Keep the meaning, tone and formatting. Fix any mistakes."
        ),
        WritingAction(
            id: "grammar", title: "Fix grammar", symbol: "checkmark.circle",
            template: "Fix only spelling, grammar and punctuation, in {{output_language}}. Change as little as possible."
        ),
        WritingAction(
            id: "formal", title: "Formal", symbol: "briefcase",
            template: "Rewrite the text in {{output_language}} in a polite, professional tone. Keep the meaning."
        ),
        WritingAction(
            id: "casual", title: "Casual", symbol: "face.smiling",
            template: "Rewrite the text in {{output_language}} in a friendly, relaxed tone. Keep the meaning."
        ),
        WritingAction(
            id: "shorter", title: "Shorter", symbol: "arrow.down.right.and.arrow.up.left",
            template: "Rewrite the text in {{output_language}} so it is about half as long. Keep every key point."
        ),
        WritingAction(
            id: "reply", title: "Reply", symbol: "arrowshape.turn.up.left",
            template: "The text is a message I received. Write my reply to it in {{output_language}}: short, friendly and clear. Write only the reply."
        ),
        WritingAction(
            id: "explain", title: "Explain", symbol: "lightbulb",
            template: "Explain what the text means in {{output_language}}, in plain words. Mention idioms, tone or anything a reader might miss.",
            languageMode: .target, output: .showOnly
        ),
    ]

    /// A one-off instruction typed on the sheet.
    static func quickPrompt(_ instruction: String) -> WritingAction {
        WritingAction(
            id: "quick:" + instruction, title: "Custom", symbol: "text.cursor",
            template: instruction + "\nWrite the result in {{output_language}}.", pinned: false
        )
    }
}
