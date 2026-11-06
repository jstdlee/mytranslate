import ExtensionKit
import OhMyTranslateKit
import OhMyTranslateUI
import SwiftUI
import TranslationUIProvider

/// Opens from the system "Translate" item in the text-selection menu, once OhMyTranslate is
/// the default translation app (Settings › Apps › Default Apps › Translation).
@main
final class OhMyTranslateExtension: TranslationUIProviderExtension {
    required init() {}

    var body: some TranslationUIProviderExtensionScene {
        TranslationUIProviderSelectedTextScene { context in
            ExtensionRoot(context: context)
        }
    }
}

struct ExtensionRoot: View {
    let context: any TranslationUIProviderContext
    @State private var model: SheetModel?

    var body: some View {
        Group {
            if let model {
                SheetView(
                    model: model,
                    allowsReplacement: context.allowsReplacement,
                    onReplace: { text in context.finish(translation: AttributedString(text)) },
                    onExpand: { context.expandSheet() }
                )
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard model == nil else { return }
        SharedStorage.markExtensionOpened()
        let settings = SharedStorage.load()
        let text = context.inputText.map { String($0.characters) } ?? ""
        let model = SheetModel(
            input: text, settings: settings,
            provider: Engines.provider(for: settings.engine)
        )
        model.onActionUsed = { id in
            var latest = SharedStorage.load()
            latest.lastActionID = id
            SharedStorage.save(latest)
        }
        self.model = model
    }
}
