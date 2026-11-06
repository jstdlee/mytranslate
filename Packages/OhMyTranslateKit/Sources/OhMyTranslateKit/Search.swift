import Foundation

/// Where a search goes. DuckDuckGo is the default: it doesn't profile the people searching.
public enum SearchEngine: String, Codable, CaseIterable, Sendable, Identifiable {
    case duckDuckGo, google

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .duckDuckGo: return "DuckDuckGo"
        case .google: return "Google"
        }
    }
}

public enum SearchKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case web, images

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .web: return "Web"
        case .images: return "Images"
        }
    }

    public var symbol: String {
        switch self {
        case .web: return "globe"
        case .images: return "photo.on.rectangle"
        }
    }
}

public enum SearchURL {
    /// The results page for `query`, or nil when there is nothing to search for.
    public static func url(for query: String, engine: SearchEngine, kind: SearchKind) -> URL? {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        var components: URLComponents
        var items = [URLQueryItem(name: "q", value: text)]
        switch (engine, kind) {
        case (.duckDuckGo, .web):
            components = URLComponents(string: "https://duckduckgo.com/")!
        case (.duckDuckGo, .images):
            components = URLComponents(string: "https://duckduckgo.com/")!
            items += [URLQueryItem(name: "iax", value: "images"), URLQueryItem(name: "ia", value: "images")]
        case (.google, .web):
            components = URLComponents(string: "https://www.google.com/search")!
        case (.google, .images):
            components = URLComponents(string: "https://www.google.com/search")!
            items.append(URLQueryItem(name: "tbm", value: "isch"))
        }
        components.queryItems = items
        return components.url
    }
}
