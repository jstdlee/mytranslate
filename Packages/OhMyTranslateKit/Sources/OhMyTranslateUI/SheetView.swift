import SwiftUI
import OhMyTranslateKit
#if canImport(UIKit)
import UIKit
#endif

/// The selection sheet: language chips, action chips, the streamed result, a quick prompt,
/// and Copy / Replace. The extension and the app's Try it screen both show it.
public struct SheetView: View {
    @Bindable var model: SheetModel
    let allowsReplacement: Bool
    let onReplace: (String) -> Void
    let onExpand: () -> Void

    @FocusState private var promptFocused: Bool
    @State private var copied = false

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
        VStack(alignment: .leading, spacing: 12) {
            languageRow
            actionRow
            Divider()
            result
            promptField
            buttons
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .onAppear { model.start() }
        .onDisappear { model.cancel() }
    }

    // MARK: Chips

    private var languageRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let source = model.source {
                    Text("\(source.chipLabel) →")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("From \(source.englishName)")
                }
                ForEach(model.languages) { language in
                    Chip(
                        title: language.chipLabel,
                        selected: language == model.outputLanguage
                    ) { model.select(language) }
                    .accessibilityIdentifier("lang-\(language.code)")
                }
            }
        }
    }

    private var actionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.actions) { action in
                    Chip(title: action.title, symbol: action.symbol, selected: action.id == model.action.id) {
                        model.select(action)
                    }
                    .accessibilityIdentifier("action-\(action.id)")
                }
            }
        }
    }

    // MARK: Result

    @ViewBuilder
    private var result: some View {
        ScrollView {
            Group {
                switch model.phase {
                case .failed(let message):
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                case .running where model.output.isEmpty:
                    Text(model.input)
                        .redacted(reason: .placeholder)
                default:
                    Text(model.output)
                        .textSelection(.enabled)
                }
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("result")
        }
        .frame(minHeight: 80)
        .animation(.default, value: model.phase)
    }

    private var promptField: some View {
        HStack(spacing: 8) {
            TextField("Tell it what to do…", text: $model.quickPrompt, axis: .vertical)
                .lineLimit(1...4)
                .focused($promptFocused)
                .submitLabel(.send)
                .onSubmit { model.submitQuickPrompt() }
                .accessibilityIdentifier("quick-prompt")
            Button {
                promptFocused = false
                model.submitQuickPrompt()
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title2)
            }
            .disabled(model.quickPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("Run")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .onChange(of: promptFocused) { _, focused in
            if focused { onExpand() }
        }
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button {
                copy(model.output)
            } label: {
                Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
            }
            .disabled(model.phase != .done || model.output.isEmpty)
            .accessibilityIdentifier("copy")

            Button {
                model.retry()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .disabled(model.isRunning || model.unavailableReason != nil)

            Spacer()

            if allowsReplacement && model.action.output == .replace {
                Button {
                    onReplace(model.output)
                } label: {
                    Label("Replace", systemImage: "checkmark")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canReplace)
                .accessibilityIdentifier("replace")
            }
        }
        .labelStyle(.titleAndIcon)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(
                Capsule().fill(selected ? Color.accentColor : Color.secondary.opacity(0.15))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
