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
    @MainActor
    @discardableResult
    public static func present(
        from presenter: UIViewController,
        config: SentinelConfig,
        onEvent: @escaping (SentinelEvent) -> Void
    ) -> SentinelSession {
        let controller = SentinelViewController(config: config, onEvent: onEvent)
        presenter.present(controller, animated: true)
        return SentinelSession(presented: controller)
    }
}
#endif
