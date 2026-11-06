import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple's on-device model (iOS 26 and Apple Intelligence). Free, offline, smaller than the cloud models.
public enum OnDeviceModel {
    /// nil when it can be used; otherwise why not.
    public static var unavailableReason: String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return nil
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Turn on Apple Intelligence in the Settings app."
            case .unavailable(.modelNotReady):
                return "The on-device model is still downloading. Try again later."
            default:
                return "This device doesn't support Apple Intelligence."
            }
        }
        #endif
        return "Needs iOS 26 and a device with Apple Intelligence."
    }

    /// A provider when the model can be used.
    public static func provider() -> (any LLMProvider)? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), unavailableReason == nil {
            return OnDeviceProvider()
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
struct OnDeviceProvider: LLMProvider {
    var cacheID: String { "on-device" }

    func stream(_ request: LLMRequest) -> AsyncThrowingStream<String, Error> {
        makeStream { continuation in
            let session = LanguageModelSession(instructions: request.system)
            let reply = try await session.respond(to: request.prompt).content
            continuation.yield(reply.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
#endif
