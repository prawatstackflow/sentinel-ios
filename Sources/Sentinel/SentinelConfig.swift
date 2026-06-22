import Foundation

/// Configuration for a single verification session.
public struct SentinelConfig {
    /// Origin of the hosted verification flow when none is supplied.
    public static let defaultHostedFlowBaseURL = "https://test-identity.finvasia.com"

    /// Identity session id from the tenant backend's `POST /sessions` call.
    public let sessionId: String
    /// Scoped session token (JWT) from the same call. TTL 24h.
    public let sessionToken: String
    /// Origin of the hosted verification flow. Override per environment.
    public let hostedFlowBaseURL: String
    /// Color scheme; `.system` follows the device at launch.
    public let theme: SentinelTheme
    /// Optional BCP-47 locale hint. Reserved — not yet consumed by the runtime.
    public let locale: String?

    public init(
        sessionId: String,
        sessionToken: String,
        hostedFlowBaseURL: String = SentinelConfig.defaultHostedFlowBaseURL,
        theme: SentinelTheme = .system,
        locale: String? = nil
    ) {
        self.sessionId = sessionId
        self.sessionToken = sessionToken
        self.hostedFlowBaseURL = hostedFlowBaseURL
        self.theme = theme
        self.locale = locale
    }
}
