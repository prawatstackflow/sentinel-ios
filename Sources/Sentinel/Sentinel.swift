#if canImport(UIKit)
import UIKit

/// Entry point for the Sentinel identity-verification flow.
public enum Sentinel {
    /// Presents the verification flow modally from `presenter` and reports every
    /// status update via `onEvent`. Always call on the main thread.
    ///
    /// The SDK **does not close itself** when the flow completes, errors, or the
    /// user cancels — it only reports the event. Use the returned
    /// `SentinelSession` to dismiss when the host decides:
    ///
    /// ```swift
    /// let session = Sentinel.present(from: self, config: SentinelConfig(
    ///     sessionId: sessionId, sessionToken: sessionToken
    /// )) { event in
    ///     switch event {
    ///     case .completed, .cancelled, .error, .loadFailed:
    ///         session.dismiss()
    ///     case .ready:
    ///         break
    ///     }
    /// }
    /// ```
    ///
    /// The flow is presented as an edge-to-edge full-screen WebView with no
    /// native chrome (matching the Android SDK). A swipe-down gesture is the one
    /// built-in exception: it emits `.cancelled` and dismisses, so the user is
    /// never trapped even if the hosted flow hides its own header.
    ///
    /// The host app must declare `NSCameraUsageDescription` in its Info.plist
    /// (liveness uses the camera) and target iOS 14.3+.
    ///
    /// `onLiveChat` (optional) is invoked when the user taps "Chat with support"
    /// inside the flow. It is a **non-terminal** request — the flow stays open —
    /// asking the host to open LiveChat natively with the supplied
    /// `LiveChatRequest` (license/group + session context). Omit it to leave the
    /// support button inert on native (the hosted flow does not open LiveChat
    /// in-WebView).
    @MainActor
    @discardableResult
    public static func present(
        from presenter: UIViewController,
        config: SentinelConfig,
        onEvent: @escaping (SentinelEvent) -> Void,
        onLiveChat: ((LiveChatRequest) -> Void)? = nil
    ) -> SentinelSession {
        let controller = SentinelViewController(config: config, onEvent: onEvent, onLiveChat: onLiveChat)
        presenter.present(controller, animated: true)
        return SentinelSession(presented: controller)
    }
}
#endif
