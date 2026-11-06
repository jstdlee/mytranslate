import OhMyTranslateKit
import SwiftUI

/// Shown until the user allows text to leave the iPhone for the chosen engine.
/// It can't be dismissed by swiping: the user either allows it or picks On this device.
struct ConsentView: View {
    @Bindable var store: SettingsStore

    private var destination: String {
        switch store.settings.engine.kind {
        case .anthropic: return "Anthropic, to run Claude"
        case .openAICompatible: return "the server you set in Engine"
        default: return "the engine you chose"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                    .padding(.top, 24)

                Text("Send selected text to \(destination)?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 12) {
                    Label("Only the text you select is sent, and only when you tap an action.", systemImage: "text.quote")
                    Label("OhMyTranslate has no server of its own and keeps no copy of your text.", systemImage: "internaldrive")
                    Label("\(destination.prefix(1).uppercased() + destination.dropFirst()) handles the text under its own privacy policy.", systemImage: "lock.doc")
                    Label("Your API key stays in this iPhone's Keychain.", systemImage: "key")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    Button {
                        store.settings.aiConsent = true
                    } label: {
                        Text("Allow").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("consent-allow")

                    Button {
                        store.settings.engine.kind = .onDevice
                    } label: {
                        Text("Use On this device instead").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("consent-on-device")

                    Link("Privacy policy", destination: AppLinks.privacy)
                        .font(.footnote)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .interactiveDismissDisabled()
    }
}

/// Public pages, published from docs/ on the main branch.
enum AppLinks {
    static let privacy = URL(string: "https://github.com/jstdlee/mytranslate/blob/main/docs/PRIVACY.md")!
    static let terms = URL(string: "https://github.com/jstdlee/mytranslate/blob/main/docs/TERMS.md")!
    static let support = URL(string: "https://github.com/jstdlee/mytranslate/issues")!
}
