#if canImport(UIKit)
import UIKit

/// Handle to a presented verification flow. Returned by `Sentinel.present` so
/// the host can tear the flow down when *it* decides — the SDK no longer closes
/// itself on a web status event.
///
/// ```swift
/// let session = Sentinel.present(from: self, config: config) { event in
///     if case .completed = event { session.dismiss() }
/// }
/// ```
@MainActor
public final class SentinelSession {
    // Weak: once the host (or the SDK's own Close button) dismisses the modal,
    // UIKit releases it and `dismiss()` becomes a no-op.
    private weak var presented: UIViewController?

    init(presented: UIViewController) {
        self.presented = presented
    }

    /// Dismisses the verification flow. No-op if already gone.
    public func dismiss(animated: Bool = true) {
        presented?.dismiss(animated: animated)
    }
}
#endif
