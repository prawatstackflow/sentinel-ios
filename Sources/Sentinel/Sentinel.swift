#if canImport(UIKit)
import UIKit

/// Entry point for the Sentinel identity-verification flow.
public enum Sentinel {
    /// Presents the verification flow modally from `presenter` and reports the
    /// terminal [SentinelResult] via `completion`. Always call on the main thread.
    ///
    /// ```swift
    /// Sentinel.present(from: self, config: SentinelConfig(
    ///     sessionId: sessionId, sessionToken: sessionToken
    /// )) { result in
    ///     switch result { /* ... */ }
    /// }
    /// ```
    ///
    /// The host app must declare `NSCameraUsageDescription` in its Info.plist
    /// (liveness uses the camera) and target iOS 14.3+.
    @MainActor
    public static func present(
        from presenter: UIViewController,
        config: SentinelConfig,
        completion: @escaping (SentinelResult) -> Void
    ) {
        let controller = SentinelViewController(config: config, completion: completion)
        let nav = UINavigationController(rootViewController: controller)
        nav.modalPresentationStyle = .fullScreen
        presenter.present(nav, animated: true)
    }
}
#endif
