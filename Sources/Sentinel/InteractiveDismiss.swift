#if canImport(UIKit)
import UIKit

/// Slide-down interactive dismissal for a full-screen modal.
///
/// The SDK presents the verification WebView as an edge-to-edge `.fullScreen`
/// modal (matching the Android SDK's edge-to-edge Activity). `.fullScreen`
/// modals have no built-in interactive dismissal, so this custom transition
/// gives the user a swipe-down escape hatch **without** falling back to a card
/// sheet (rounded corners / top gap). It is the safety net that replaces the
/// removed navigation-bar Close button, so the user is never trapped — even
/// when the hosted flow hides its own header (`display.header: false`).
final class SlideDownDismissTransitioning: NSObject, UIViewControllerTransitioningDelegate {
    /// Non-nil only while a pan gesture is actively driving the dismissal. Left
    /// nil for a programmatic `SentinelSession.dismiss()` so those animate
    /// non-interactively.
    var interactor: UIPercentDrivenInteractiveTransition?

    func animationController(forDismissed _: UIViewController)
        -> UIViewControllerAnimatedTransitioning?
    {
        SlideDownDismissAnimator()
    }

    func interactionControllerForDismissal(
        using _: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        interactor
    }
}

/// Slides the dismissing view controller straight down off the bottom edge.
final class SlideDownDismissAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval { 0.3 }

    func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        guard let from = ctx.view(forKey: .from) else {
            ctx.completeTransition(false)
            return
        }
        let container = ctx.containerView
        // `.fullScreen` removes the presenter's view during presentation; put it
        // back underneath so the user isn't sliding away to a black container.
        if let to = ctx.view(forKey: .to) {
            to.frame = container.bounds
            container.insertSubview(to, belowSubview: from)
        }
        let offScreen = from.frame.offsetBy(dx: 0, dy: container.bounds.height)
        UIView.animate(
            withDuration: transitionDuration(using: ctx),
            delay: 0,
            options: [.curveEaseInOut],
            animations: { from.frame = offScreen },
            completion: { _ in
                let cancelled = ctx.transitionWasCancelled
                if cancelled { from.frame = container.bounds }
                ctx.completeTransition(!cancelled)
            }
        )
    }
}
#endif
