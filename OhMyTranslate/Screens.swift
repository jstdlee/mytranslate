import OhMyTranslateKit
import OhMyTranslateUI
import SwiftUI

// MARK: - Try it

/// Shows the same sheet the Translate menu opens, on text typed here.
struct TryItView: View {
    @Bindable var store: SettingsStore
    let demo: Bool
    @State private var text = """
    Dear hs-office,

    I am writing to ask for a meeting next Tuesday at 3pm.

    Thanks.
    """
    @State private var sheet: SheetModel?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 180)
                        .accessibilityIdentifier("try-text")
                } footer: {
                    Text("In other apps, select text and tap Translate. This opens the same sheet.")
                }
                Section {
                    Button("Open the sheet") { open() }
                        .accessibilityIdentifier("open-sheet")
                }
            }
            .navigationTitle("OhMyTranslate")
            .sheet(item: $sheet) { model in
                SheetView(model: model, allowsReplacement: true) { result in
                    text = result
                    sheet = nil
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func open() {
        let model = SheetModel(
            input: text, settings: store.settings,
            provider: Engines.provider(for: store.settings.engine, consented: store.settings.aiConsent, demo: demo)
        )
        model.onActionUsed = { id in store.settings.lastActionID = id }
        sheet = model
    }
}

// MARK: - Actions

struct ActionsView: View {
    @Bindable var store: SettingsStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($store.settings.actions) { $action in
                        Toggle(isOn: $action.pinned) {
                            Label(action.title, systemImage: action.symbol)
                        }
                    }
                    .onMove { store.settings.actions.move(fromOffsets: $0, toOffset: $1) }
                } footer: {
                    Text("Turned-on actions are chips on the sheet, in this order.")
                }
                Section {
                    Button("Restore built-in actions") { store.settings.actions = WritingAction.builtIn }
                }
            }
            .navigationTitle("Actions")
            .toolbar { EditButton() }
        }
    }
}

// MARK: - Settings (languages and search)

struct SettingsView: View {
    @Bindable var store: SettingsStore
    @State private var confirmErase = false

    private var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
    }

    private func eraseAll() {
        store.settings = AppSettings()
        Secrets.set("", for: Secrets.anthropic)
        Secrets.set("", for: Secrets.openAI)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Translate into", selection: $store.settings.languages.primary) {
                        languageOptions
                    }
                    Picker("When text is already in it", selection: $store.settings.languages.secondary) {
                        languageOptions
                    }
                } footer: {
                    Text("Text in your first language goes to the second one, so one tap works both ways.")
                }
                Section {
                    Picker("Search engine", selection: $store.settings.searchEngine) {
                        ForEach(SearchEngine.allCases) { Text($0.title).tag($0) }
                    }
                } header: {
                    Text("Search")
                } footer: {
                    Text("The search button on the sheet opens web or image results on this engine. DuckDuckGo doesn't build a profile of what you search for.")
                }
                Section {
                    Button("Erase all data", role: .destructive) { confirmErase = true }
                        .accessibilityIdentifier("erase-data")
                } header: {
                    Text("Your data")
                } footer: {
                    Text("Removes your settings, actions and API keys from this iPhone. OhMyTranslate keeps nothing on a server.")
                }
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Link("Privacy policy", destination: AppLinks.privacy)
                    Link("Terms of use", destination: AppLinks.terms)
                    Link("Report a problem", destination: AppLinks.support)
                }
                Section("Chips on the sheet") {
                    ForEach(Language.all) { language in
                        let pinned = store.settings.languages.pinned.contains(language)
                        Button {
                            toggle(language)
                        } label: {
                            HStack {
                                Text(language.chipLabel)
                                Text(language.englishName).foregroundStyle(.secondary)
                                Spacer()
                                if pinned { Image(systemName: "checkmark") }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Erase all OhMyTranslate data?", isPresented: $confirmErase, titleVisibility: .visible) {
                Button("Erase", role: .destructive) { eraseAll() }
            } message: {
                Text("This removes your settings, actions and API keys from this iPhone.")
            }
        }
    }

    private var languageOptions: some View {
        ForEach(Language.all) { Text("\($0.chipLabel) · \($0.englishName)").tag($0) }
    }

    private func toggle(_ language: Language) {
        if let index = store.settings.languages.pinned.firstIndex(of: language) {
            store.settings.languages.pinned.remove(at: index)
        } else {
            store.settings.languages.pinned.append(language)
        }
    }
}

// MARK: - Engine

struct EngineView: View {
    @Bindable var store: SettingsStore
    @State private var anthropicKey = Secrets.get(Secrets.anthropic) ?? ""
    @State private var openAIKey = Secrets.get(Secrets.openAI) ?? ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Engine", selection: $store.settings.engine.kind) {
                    ForEach(EngineConfig.Kind.allCases) { Text($0.title).tag($0) }
                }
                switch store.settings.engine.kind {
                case .anthropic:
                    Section {
                        Picker("Model", selection: $store.settings.engine.anthropicModel) {
                            ForEach(AnthropicProvider.models, id: \.id) { Text($0.label).tag($0.id) }
                        }
                        SecureField("API key", text: $anthropicKey)
                            .textContentType(.password)
                            .onChange(of: anthropicKey) { _, key in Secrets.set(key, for: Secrets.anthropic) }
                    } footer: {
                        Text("Get a key at console.anthropic.com. It is kept in the Keychain and sent only to Anthropic.")
                    }
                case .openAICompatible:
                    Section {
                        TextField("Server, e.g. https://openrouter.ai/api/v1", text: $store.settings.engine.openAIBaseURL)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                        TextField("Model", text: $store.settings.engine.openAIModel)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("API key (optional)", text: $openAIKey)
                            .onChange(of: openAIKey) { _, key in Secrets.set(key, for: Secrets.openAI) }
                    }
                case .onDevice:
                    Section {
                        if let reason = OnDeviceModel.unavailableReason {
                            Label(reason, systemImage: "exclamationmark.triangle")
                        } else {
                            Label("Ready. Works offline, nothing leaves this iPhone.", systemImage: "checkmark.circle")
                        }
                    }
                case .demo:
                    Section {
                        Text("Shows a fixed answer. Useful to try the sheet without a key.")
                    }
                }
            }
            .navigationTitle("Engine")
        }
    }
}

// MARK: - Set up

struct SetupView: View {
    @Environment(\.openURL) private var openURL
    @State private var lastOpened = SharedStorage.extensionLastOpened()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    step(1, "Open Settings › Apps › Default Apps › Translation.")
                    step(2, "Choose OhMyTranslate.")
                    step(3, "In any app, select text and tap Translate.")
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                } header: {
                    Text("Make it your Translate button")
                } footer: {
                    Text("Needs iOS 18.4 or later. The menu item keeps the name Translate.")
                }
                Section {
                    if let lastOpened {
                        Label("Last opened from the menu \(lastOpened.formatted(.relative(presentation: .named)))", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Not opened from the menu yet", systemImage: "circle.dashed")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Set up")
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                lastOpened = SharedStorage.extensionLastOpened()
            }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Text("\(number)").font(.headline).foregroundStyle(.tint)
        }
    }
}
