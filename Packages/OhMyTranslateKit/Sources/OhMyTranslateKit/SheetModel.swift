import Foundation
import Observation

/// State of the selection sheet: source and target, the chips, the running request and the result.
///
/// The source is detected from the text unless the user picks one. Tapping a chip cancels the
/// running request and starts the new one. Finished results are cached per action, source,
/// language and model, so going back to a chip shows its result at once.
@MainActor
@Observable
public final class SheetModel: Identifiable {
    public enum Phase: Equatable, Sendable {
        case idle
        case running
        case done
        case failed(String)
    }

    public let input: String
    /// Language the text was detected as; nil when detection is unsure.
    public let detectedSource: Language?
    /// The source the user picked; nil means "detect".
    public private(set) var sourceChoice: Language?
    public let actions: [WritingAction]
    /// Languages the source menu offers.
    public var sourceOptions: [Language] { Language.all }
    public let searchEngine: SearchEngine

    public private(set) var action: WritingAction
    public private(set) var target: Language
    public private(set) var output = ""
    public private(set) var phase: Phase = .idle
    /// The one-off instruction typed on the sheet.
    public var quickPrompt = ""

    /// Why nothing can run (no key, no model), shown instead of a result.
    public let unavailableReason: String?
    /// Called with the action id after each run, so the next sheet opens with it.
    @ObservationIgnored public var onActionUsed: ((String) -> Void)?

    @ObservationIgnored private let provider: (any LLMProvider)?
    @ObservationIgnored private let prefs: LanguagePrefs
    @ObservationIgnored private var cache: [String: String] = [:]
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var runID = 0
    /// After a language is picked, the target stops following the detected source.
    @ObservationIgnored private var languageChosen = false

    public init(
        input: String,
        settings: AppSettings,
        provider: Result<any LLMProvider, ProviderError>,
        detector: any LanguageDetecting = SystemLanguageDetector()
    ) {
        self.input = input.trimmingCharacters(in: .whitespacesAndNewlines)
        self.prefs = settings.languages
        self.searchEngine = settings.searchEngine
        let detected = detector.detect(input)
        self.detectedSource = detected
        let actions = settings.pinnedActions.isEmpty ? [WritingAction.translate] : settings.pinnedActions
        self.actions = actions
        self.action = actions.first { $0.id == settings.lastActionID } ?? actions[0]
        self.target = settings.languages.autoTarget(for: detected)
        switch provider {
        case .success(let provider):
            self.provider = provider
            self.unavailableReason = nil
        case .failure(let error):
            self.provider = nil
            self.unavailableReason = error.errorDescription
        }
    }

    /// The source in use: the user's pick, else the detected language.
    public var source: Language? { sourceChoice ?? detectedSource }

    /// Chips for the target, in order; the current target is always one of them.
    public var languages: [Language] {
        var list = prefs.pinned
        if !list.contains(target) { list.insert(target, at: 0) }
        return list
    }

    /// The language the current action writes in.
    public var outputLanguage: Language {
        if action.languageMode == .keepSource, !languageChosen, let source { return source }
        return target
    }

    /// Lets the app present the sheet with `sheet(item:)`.
    nonisolated public var id: ObjectIdentifier { ObjectIdentifier(self) }

    public var isRunning: Bool { phase == .running }
    public var canReplace: Bool { phase == .done && action.output == .replace && !output.isEmpty }

    /// Runs the current chip. Call when the sheet appears.
    public func start() {
        run()
    }

    /// Picks the source language, or detects it again when `language` is nil.
    public func selectSource(_ language: Language?) {
        guard language != sourceChoice else { return }
        sourceChoice = language
        if !languageChosen { target = prefs.autoTarget(for: source) }
        run()
    }

    public func select(_ language: Language) {
        languageChosen = true
        guard language != target || phase != .done else { return }
        target = language
        run()
    }

    public func select(_ action: WritingAction) {
        guard action != self.action || phase != .done else { return }
        self.action = action
        run()
    }

    public func submitQuickPrompt() {
        let instruction = quickPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else { return }
        action = .quickPrompt(instruction)
        run()
    }

    /// Runs again, skipping the cache.
    public func retry() {
        cache[cacheKey] = nil
        run()
    }

    public func cancel() {
        task?.cancel()
        task = nil
        runID += 1
        if phase == .running { phase = output.isEmpty ? .idle : .done }
    }

    /// Waits for the running request. For tests.
    public func waitUntilFinished() async {
        await task?.value
    }

    private var cacheKey: String {
        [provider?.cacheID ?? "-", action.id, source?.code ?? "-", outputLanguage.code, String(input.hashValue)]
            .joined(separator: "|")
    }

    private func run() {
        task?.cancel()
        runID += 1
        let id = runID
        guard !input.isEmpty else {
            output = ""
            phase = .failed("No text was selected.")
            return
        }
        guard let provider else {
            output = ""
            phase = .failed(unavailableReason ?? "No engine is set up.")
            return
        }
        let key = cacheKey
        if let cached = cache[key] {
            output = cached
            phase = .done
            if !action.id.hasPrefix("quick:") { onActionUsed?(action.id) }
            return
        }
        let request = PromptBuilder.request(
            action: action, text: input, output: outputLanguage, source: source, target: target
        )
        let actionID = action.id
        output = ""
        phase = .running
        task = Task { [weak self] in
            do {
                for try await piece in provider.stream(request) {
                    guard let self, self.runID == id else { return }
                    self.output += piece
                }
                guard let self, self.runID == id else { return }
                self.output = self.output.trimmingCharacters(in: .whitespacesAndNewlines)
                self.cache[key] = self.output
                self.phase = .done
                if !actionID.hasPrefix("quick:") { self.onActionUsed?(actionID) }
            } catch {
                guard let self, self.runID == id, !(error is CancellationError) else { return }
                self.phase = .failed(error.localizedDescription)
            }
        }
    }
}
