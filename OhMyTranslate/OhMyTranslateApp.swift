import OhMyTranslateKit
import SwiftUI

@main
struct OhMyTranslateApp: App {
    /// UI tests and screenshots: the demo engine, no network, fresh settings on each launch.
    private let demo: Bool
    @State private var store: SettingsStore

    init() {
        let demo = ProcessInfo.processInfo.arguments.contains("-demo")
        self.demo = demo
        if demo, let defaults = UserDefaults(suiteName: "com.jstdlee.ohmytranslate.demo") {
            defaults.removePersistentDomain(forName: "com.jstdlee.ohmytranslate.demo")
            _store = State(initialValue: SettingsStore(defaults: defaults))
        } else {
            _store = State(initialValue: SettingsStore())
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store, demo: demo)
        }
    }
}

struct RootView: View {
    @Bindable var store: SettingsStore
    let demo: Bool

    var body: some View {
        TabView {
            Tab("Try it", systemImage: "text.cursor") {
                TryItView(store: store, demo: demo)
            }
            Tab("Actions", systemImage: "wand.and.stars") {
                ActionsView(store: store)
            }
            Tab("Languages", systemImage: "globe") {
                LanguagesView(store: store)
            }
            Tab("Engine", systemImage: "cpu") {
                EngineView(store: store)
            }
            Tab("Set up", systemImage: "checklist") {
                SetupView()
            }
        }
    }
}
