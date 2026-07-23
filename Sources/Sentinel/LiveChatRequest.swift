import Foundation

/// A request from the hosted verification flow to open LiveChat **natively**.
///
/// Inside the SDK WebView the hosted flow does NOT render LiveChat itself (a
/// fullscreen third-party widget can't reliably clear the notch there). When the
/// user taps "Chat with support" it instead posts a `live_chat` bridge message,
/// which the SDK delivers to the host's `onLiveChat` callback carrying the same
/// data the web widget would use. The host opens LiveChat with its own LiveChat
/// iOS SDK (or support flow), where the OS handles the safe area.
///
/// This is a **non-terminal** request: it does not change the flow's status and
/// never dismisses the WebView — the verification flow stays live underneath.
public struct LiveChatRequest: Equatable {
    /// LiveChat license id. A string to stay lossless for large ids.
    public let license: String
    /// Resolved routing group; `0` is LiveChat's built-in General group.
    public let group: Int
    /// Whether the tenant opted to forward the declared name/email to LiveChat.
    public let forwardPii: Bool
    /// Non-PII session context (LiveChat "session variables").
    public let sessionVariables: [String: String]
    /// Declared name — present only when `forwardPii` is true and known.
    public let customerName: String?
    /// Declared email — present only when `forwardPii` is true and known.
    public let customerEmail: String?

    public init(
        license: String,
        group: Int,
        forwardPii: Bool,
        sessionVariables: [String: String],
        customerName: String? = nil,
        customerEmail: String? = nil
    ) {
        self.license = license
        self.group = group
        self.forwardPii = forwardPii
        self.sessionVariables = sessionVariables
        self.customerName = customerName
        self.customerEmail = customerEmail
    }

    /// Decode from the bridge message body (`{ "type": "live_chat", … }`).
    /// Returns nil when the required `license` is missing or blank.
    init?(body: [String: Any]) {
        guard let license = body["license"] as? String, !license.isEmpty else { return nil }
        self.license = license
        // JS numbers cross the bridge as NSNumber; tolerate a numeric string too.
        if let group = body["group"] as? NSNumber {
            self.group = group.intValue
        } else if let group = body["group"] as? Int {
            self.group = group
        } else if let group = body["group"] as? String, let parsed = Int(group) {
            self.group = parsed
        } else {
            self.group = 0
        }
        self.forwardPii = (body["forwardPii"] as? Bool) ?? false
        if let vars = body["sessionVariables"] as? [String: Any] {
            self.sessionVariables = vars.reduce(into: [String: String]()) { acc, entry in
                if let value = entry.value as? String { acc[entry.key] = value }
            }
        } else {
            self.sessionVariables = [:]
        }
        self.customerName = body["customerName"] as? String
        self.customerEmail = body["customerEmail"] as? String
    }
}
