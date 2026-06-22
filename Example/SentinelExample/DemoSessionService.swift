import Foundation

/// Demo-app configuration loaded from a git-ignored `DemoSecrets.plist`
/// (template: `DemoSecrets.example.plist`). A missing file or blank value falls
/// back to the local-LAN defaults; an empty API key disables the one-tap button.
enum DemoConfig {
    static let apiKey = string("DEMO_API_KEY", default: "")
    static let apiBaseURL = string("DEMO_API_BASE_URL", default: "https://10.10.10.51/api")
    static let hostedFlowBaseURL = string("DEMO_HOSTED_FLOW_BASE_URL", default: "https://10.10.10.51")

    /// Host of `apiBaseURL` — used to scope the DEBUG cert exception.
    static let apiHost = URL(string: apiBaseURL)?.host

    private static let values: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "DemoSecrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any]
        else { return [:] }
        return dict
    }()

    private static func string(_ key: String, default fallback: String) -> String {
        let value = (values[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value.map { !$0.isEmpty } ?? false) ? value! : fallback
    }
}

/// Mints a fresh verification session via `POST {apiBaseURL}/sessions` with a
/// tenant `X-Api-Key` — the same call a tenant backend makes. Powers the demo
/// app's one-tap "Start Demo Session".
///
/// DEMO ONLY: a real integration keeps the API key server-side and hands the
/// client only the short-lived session token.
enum DemoSessionService {
    struct Session {
        let sessionId: String
        let sessionToken: String
    }

    enum DemoError: LocalizedError {
        case badURL(String)
        case http(Int, String)
        case malformed

        var errorDescription: String? {
            switch self {
            case let .badURL(url): return "Bad API base URL: \(url)"
            case let .http(code, message): return "HTTP \(code) — \(message)"
            case .malformed: return "Malformed response from /sessions"
            }
        }
    }

    private struct CreateResponse: Decodable {
        let sessionId: String
        let sessionToken: String
    }

    static func createSession() async throws -> Session {
        let ts = Int(Date().timeIntervalSince1970)
        let base = DemoConfig.apiBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: base + "/sessions") else {
            throw DemoError.badURL(DemoConfig.apiBaseURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(DemoConfig.apiKey, forHTTPHeaderField: "X-Api-Key")
        let body: [String: Any] = [
            "type": "kyc",
            "subjectRef": "demo-\(ts)",
            "subjectType": "individual",
            "context": ["email": "demo-\(ts)@demo.example.com"],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw DemoError.http(code, extractError(data))
        }
        guard let parsed = try? JSONDecoder().decode(CreateResponse.self, from: data),
              !parsed.sessionId.isEmpty, !parsed.sessionToken.isEmpty
        else {
            throw DemoError.malformed
        }
        return Session(sessionId: parsed.sessionId, sessionToken: parsed.sessionToken)
    }

    // DEBUG uses a session that trusts the dev LAN edge's self-signed/mkcert
    // cert so the demo can hit https://10.10.10.51 without a trust profile —
    // mirrors the Android demo's network_security_config debug-overrides. The
    // deployed test host has a valid CA cert and never reaches that delegate.
    #if DEBUG
    private static let session = URLSession(
        configuration: .default,
        delegate: TrustLocalCertDelegate(),
        delegateQueue: nil
    )
    #else
    private static let session = URLSession.shared
    #endif

    /// Pull a human message out of a Nest error body (`message` is a string or
    /// an array of validation strings); fall back to the raw text.
    private static func extractError(_ data: Data) -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8) ?? "unknown error"
        }
        if let arr = obj["message"] as? [String] { return arr.joined(separator: "; ") }
        if let msg = obj["message"] as? String { return msg }
        if let err = obj["error"] as? String { return err }
        return String(data: data, encoding: .utf8) ?? "unknown error"
    }
}

#if DEBUG
/// DEBUG-only: accept the dev LAN edge's certificate (scoped to the configured
/// API host) so the create-session call succeeds against a self-signed/mkcert
/// endpoint. Never compiled into release builds.
private final class TrustLocalCertDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host == DemoConfig.apiHost,
              let trust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
#endif
