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
    /// Optional BCP-47 language for the flow (e.g. "fr", "ar"). Sent as
    /// `?locale=` on the WebView URL; the runtime applies it to the session at
    /// bootstrap so the assistant AND all UI chrome render in this language. Omit
    /// to use the session's own language (context.language / tenant default / English).
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
