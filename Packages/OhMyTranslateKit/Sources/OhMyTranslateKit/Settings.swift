import Foundation
import Observation
#if canImport(Security)
import Security
#endif

/// Which model answers.
public struct EngineConfig: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable, Identifiable {
        case anthropic, openAICompatible, onDevice, demo
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .anthropic: return "Claude"
            case .openAICompatible: return "OpenAI-compatible"
            case .onDevice: return "On this device"
            case .demo: return "Demo (nothing is sent)"
            }
        }
    }

    public var kind: Kind = .anthropic
    public var anthropicModel: String = AnthropicProvider.defaultModel
    public var openAIBaseURL: String = ""
    public var openAIModel: String = ""

    public init() {}
}

public struct AppSettings: Codable, Hashable, Sendable {
    public var languages: LanguagePrefs = .default
    public var actions: [WritingAction] = WritingAction.builtIn
    public var engine = EngineConfig()
    public var lastActionID: String = WritingAction.translate.id
    public var searchEngine: SearchEngine = .duckDuckGo

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case languages, actions, engine, lastActionID, searchEngine
    }

    /// Missing keys fall back to defaults, so settings saved by earlier builds still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        languages = try c.decodeIfPresent(LanguagePrefs.self, forKey: .languages) ?? .default
        actions = try c.decodeIfPresent([WritingAction].self, forKey: .actions) ?? WritingAction.builtIn
        engine = try c.decodeIfPresent(EngineConfig.self, forKey: .engine) ?? EngineConfig()
        lastActionID = try c.decodeIfPresent(String.self, forKey: .lastActionID) ?? WritingAction.translate.id
        searchEngine = try c.decodeIfPresent(SearchEngine.self, forKey: .searchEngine) ?? .duckDuckGo
    }

    public var pinnedActions: [WritingAction] { actions.filter(\.pinned) }
}

/// Shared between the app and the extension through the App Group.
public enum SharedStorage {
    public static let appGroup = "group.com.jstdlee.ohmytranslate"
    static let settingsKey = "settings.v1"
    static let extensionSeenKey = "extension.lastOpened"

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    public static func load(from defaults: UserDefaults = SharedStorage.defaults) -> AppSettings {
        guard let data = defaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }
        return settings
    }

    public static func save(_ settings: AppSettings, to defaults: UserDefaults = SharedStorage.defaults) {
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: settingsKey) }
    }

    /// The extension records each opening, so the app can show that the default app is set.
    public static func markExtensionOpened(in defaults: UserDefaults = SharedStorage.defaults) {
        defaults.set(Date(), forKey: extensionSeenKey)
    }

    public static func extensionLastOpened(in defaults: UserDefaults = SharedStorage.defaults) -> Date? {
        defaults.object(forKey: extensionSeenKey) as? Date
    }
}

/// Settings the app edits; each change is saved.
@MainActor
@Observable
public final class SettingsStore {
    public var settings: AppSettings {
        didSet { SharedStorage.save(settings, to: defaults) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = SharedStorage.defaults) {
        self.defaults = defaults
        self.settings = SharedStorage.load(from: defaults)
    }
}

/// API keys, kept in the Keychain. The access group lets the extension read what the app saved.
public enum Secrets {
    public static let anthropic = "anthropic-api-key"
    public static let openAI = "openai-api-key"
    /// Set from the app's Info.plist (`OMTKeychainGroup`) on signed builds; nil on unsigned ones.
    public static var accessGroup: String? {
        Bundle.main.object(forInfoDictionaryKey: "OMTKeychainGroup") as? String
    }

    public static func get(_ account: String) -> String? {
        #if canImport(Security)
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
        #else
        return nil
        #endif
    }

    public static func set(_ value: String, for account: String) {
        #if canImport(Security)
        let query = baseQuery(account)
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        var add = query
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
        #endif
    }

    #if canImport(Security)
    private static func baseQuery(_ account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.jstdlee.ohmytranslate",
            kSecAttrAccount as String: account,
        ]
        if let accessGroup, !accessGroup.isEmpty, !accessGroup.hasPrefix("$(") {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
    #endif
}

public enum Engines {
    /// The provider for the current settings, or why there is none.
    public static func provider(
        for config: EngineConfig, demo: Bool = false,
        key: (String) -> String? = Secrets.get
    ) -> Result<any LLMProvider, ProviderError> {
        if demo { return .success(DemoProvider()) }
        switch config.kind {
        case .demo:
            return .success(DemoProvider())
        case .anthropic:
            guard let apiKey = key(Secrets.anthropic), !apiKey.isEmpty else {
                return .failure(.unavailable("Add your Claude API key in OhMyTranslate › Engine."))
            }
            return .success(AnthropicProvider(apiKey: apiKey, model: config.anthropicModel))
        case .openAICompatible:
            guard let url = URL(string: config.openAIBaseURL.trimmingCharacters(in: .whitespaces)),
                  url.host != nil, !config.openAIModel.isEmpty else {
                return .failure(.unavailable("Add the server address and model in OhMyTranslate › Engine."))
            }
            return .success(OpenAICompatibleProvider(baseURL: url, apiKey: key(Secrets.openAI) ?? "", model: config.openAIModel))
        case .onDevice:
            if let provider = OnDeviceModel.provider() { return .success(provider) }
            return .failure(.unavailable(OnDeviceModel.unavailableReason ?? "The on-device model is not available."))
        }
    }
}
