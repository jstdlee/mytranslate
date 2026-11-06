import OhMyTranslateKit
import SwiftUI

@main
struct OhMyTranslateApp: App {
    @State private var store = SettingsStore()
    /// UI tests and screenshots: the demo engine, no network.
    private let demo = ProcessInfo.processInfo.arguments.contains("-demo")

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
