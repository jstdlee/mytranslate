#if os(iOS)
import SwiftUI
import OhMyTranslateKit
#if canImport(UIKit)
import UIKit
#endif

/// The selection sheet: source and target languages, writing actions, the source and the result
/// (each with a read-aloud button), a quick prompt, search, and Copy / Replace.
/// The extension and the app's Try it screen both show it.
public struct SheetView: View {
    @Bindable var model: SheetModel
    let allowsReplacement: Bool
    let onReplace: (String) -> Void
    let onExpand: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var speaker = Speaker()
    @State private var sourceExpanded = false
    @State private var copied = false
    @FocusState private var promptFocused: Bool

    public init(
        model: SheetModel, allowsReplacement: Bool,
        onReplace: @escaping (String) -> Void, onExpand: @escaping () -> Void = {}
    ) {
        self.model = model
        self.allowsReplacement = allowsReplacement
        self.onReplace = onReplace
        self.onExpand = onExpand
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            languageBar
            actionBar
            sourceCard
            resultCard
            promptField
            toolbar
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .onAppear { model.start() }
        .onDisappear {
            model.cancel()
            speaker.stop()
        }
    }

    // MARK: Languages and actions

    private var languageBar: some View {
        HStack(spacing: 6) {
            sourceMenu
            Image(systemName: "arrow.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(model.languages) { language in
                        Chip(title: language.chipLabel, selected: language == model.outputLanguage) {
                            model.select(language)
                        }
                        .accessibilityIdentifier("lang-\(language.code)")
                    }
                }
            }
        }
    }

    /// "Auto · English" until the user picks a source; then the chosen language.
    private var sourceMenu: some View {
        Menu {
            Button {
                model.selectSource(nil)
            } label: {
                Label("Detect language", systemImage: model.sourceChoice == nil ? "checkmark" : "sparkles")
            }
            Divider()
            // Short list first; the rest sit in a submenu so the menu stays easy to scan.
            ForEach(model.languages) { language in
                sourceItem(language)
            }
            Menu("All languages") {
                ForEach(model.sourceOptions) { language in
                    sourceItem(language)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(sourceTitle).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
            .foregroundStyle(.primary)
        }
        .accessibilityLabel("Source language, \(sourceTitle)")
        .accessibilityIdentifier("source-menu")
    }

    private func sourceItem(_ language: Language) -> some View {
        Button {
            model.selectSource(language)
        } label: {
            if language == model.sourceChoice {
                Label(language.chipLabel, systemImage: "checkmark")
            } else {
                Text(language.chipLabel)
            }
        }
    }

    private var sourceTitle: String {
        if let choice = model.sourceChoice { return choice.chipLabel }
        if let detected = model.detectedSource { return "Auto · \(detected.chipLabel)" }
        return "Auto"
    }

    private var actionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(model.actions) { action in
                    Chip(title: action.title, symbol: action.symbol, selected: action.id == model.action.id) {
                        model.select(action)
                    }
                    .accessibilityIdentifier("action-\(action.id)")
                }
            }
        }
    }

    // MARK: Source and result

    private var sourceCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(model.input)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(sourceExpanded ? nil : 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { sourceExpanded.toggle() }
                .accessibilityIdentifier("source-text")
            VStack(spacing: 4) {
                speakButton(.source, text: model.input, language: model.source)
                searchButton(for: model.input, identifier: "search-source")
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView {
                resultText
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("result")
            }
            HStack {
                Spacer()
                speakButton(.result, text: model.output, language: model.outputLanguage, enabled: model.phase == .done)
                searchButton(for: model.output, identifier: "search-result", enabled: model.phase == .done)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor.opacity(0.07)))
        .animation(.default, value: model.phase)
    }

    @ViewBuilder
    private var resultText: some View {
        switch model.phase {
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        case .running where model.output.isEmpty:
            ProgressView()
        default:
            Text(model.output)
                .font(.body)
                .textSelection(.enabled)
        }
    }

    private func speakButton(
        _ channel: Speaker.Channel, text: String, language: Language?, enabled: Bool = true
    ) -> some View {
        let playing = speaker.current == channel
        return Button {
            speaker.toggle(text, language: language, channel: channel)
        } label: {
            Image(systemName: playing ? "speaker.wave.2.fill" : "speaker.wave.2")
                .font(.body)
                .frame(width: 32, height: 32)
                .symbolEffect(.variableColor.iterative, isActive: playing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(playing ? Color.accentColor : Color.secondary)
        .disabled(!enabled || text.isEmpty)
        .accessibilityLabel(playing ? "Stop reading" : "Read aloud")
        .accessibilityIdentifier("speak-\(channel.rawValue)")
    }

    /// Searches `text` on the default engine, as web or image results. Shown on the source and the result.
    private func searchButton(for text: String, identifier: String, enabled: Bool = true) -> some View {
        Menu {
            ForEach(SearchKind.allCases) { kind in
                Button {
                    search(kind, text)
                } label: {
                    Label("\(kind.title) on \(model.searchEngine.title)", systemImage: kind.symbol)
                }
            }
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.body)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.secondary)
        .disabled(!enabled || text.isEmpty)
        .accessibilityLabel("Search this text")
        .accessibilityIdentifier(identifier)
    }

    // MARK: Quick prompt and toolbar

    private var promptField: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.cursor")
                .foregroundStyle(.secondary)
            TextField("Tell it what to change…", text: $model.quickPrompt)
                .focused($promptFocused)
                .submitLabel(.send)
                .onSubmit { model.submitQuickPrompt() }
                .accessibilityIdentifier("quick-prompt")
            Button {
                promptFocused = false
                model.submitQuickPrompt()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(model.quickPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("Run")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.1)))
        .onChange(of: promptFocused) { _, focused in
            if focused { onExpand() }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 2) {
            iconButton(copied ? "checkmark" : "doc.on.doc", label: copied ? "Copied" : "Copy") {
                copy(model.output)
            }
            .disabled(model.phase != .done || model.output.isEmpty)
            .accessibilityIdentifier("copy")

            iconButton("arrow.clockwise", label: "Retry") {
                model.retry()
            }
            .disabled(model.isRunning || model.unavailableReason != nil)

            Spacer(minLength: 8)

            if allowsReplacement && model.action.output == .replace {
                Button {
                    onReplace(model.output)
                } label: {
                    Label("Replace", systemImage: "checkmark")
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canReplace)
                .accessibilityIdentifier("replace")
            }
        }
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func search(_ kind: SearchKind, _ text: String) {
        guard let url = SearchURL.url(for: text, engine: model.searchEngine, kind: kind) else { return }
        openURL(url)
    }

    private func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}

/// A capsule button for a language or an action.
struct Chip: View {
    let title: String
    var symbol: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let symbol { Image(systemName: symbol).imageScale(.small) }
                Text(title).lineLimit(1)
            }
            .font(.subheadline.weight(selected ? .semibold : .regular))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(
                Capsule().fill(selected ? Color.accentColor : Color.secondary.opacity(0.12))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
#endif
