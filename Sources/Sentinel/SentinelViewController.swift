#if canImport(UIKit)
import UIKit
import WebKit
import os

/// Internal host controller. Loads the hosted verification runtime in a
/// WKWebView and forwards its lifecycle/status messages as [SentinelEvent]s.
final class SentinelViewController: UIViewController, WKScriptMessageHandler,
    WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate, UIGestureRecognizerDelegate
{
    private static let logger = Logger(subsystem: "com.finvasia.sentinel", category: "events")

    private let config: SentinelConfig
    private let onEvent: (SentinelEvent) -> Void
    private var webView: WKWebView!

    // Custom slide-down dismissal so the edge-to-edge `.fullScreen` look is kept
    // while the user still has a swipe-down escape hatch (the safety net that
    // replaces the removed navigation-bar Close button).
    private let dismissTransitioning = SlideDownDismissTransitioning()
    private var interactor: UIPercentDrivenInteractiveTransition?

    init(config: SentinelConfig, onEvent: @escaping (SentinelEvent) -> Void) {
        self.config = config
        self.onEvent = onEvent
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        transitioningDelegate = dismissTransitioning
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let contentController = WKUserContentController()
        // Receiving end of postToNative() on the web side.
        contentController.add(self, name: "sentinel")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        // Edge-to-edge: don't let the scroll view auto-inset for the bottom safe
        // area. The hosted flow already pads its dock with
        // env(safe-area-inset-bottom) under viewport-fit=cover, so the default
        // .automatic behaviour double-counts the inset and leaves an empty band
        // at the bottom. This mirrors Android's setDecorFitsSystemWindows(false).
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        // No rubber-band overscroll — the chat surface is a fixed-height grid, so
        // bouncing only flashes empty background past the edges.
        webView.scrollView.bounces = false
        // Keyboard safety: the hosted flow is a fixed-viewport app — its surface is
        // pinned to visualViewport.height and all scrolling happens inside web
        // containers, so the outer scroll view should never move at base zoom.
        // Without this, WKWebView's automatic keyboard focus-scroll shoves the whole
        // (non-scrollable) page off-screen under .never. scrollViewDidScroll clamps
        // it back to the top, while still allowing pinch-zoom panning.
        webView.scrollView.delegate = self
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // No native chrome: the flow is an edge-to-edge WebView (matching the
        // Android SDK). The hosted flow renders its own header/exit; the pan
        // gesture below is the always-available escape hatch.
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
        pan.delegate = self
        view.addGestureRecognizer(pan)

        let isDark = traitCollection.userInterfaceStyle == .dark
        guard let url = VerificationURL.build(for: config, isDarkMode: isDark) else {
            emit(.loadFailed(message: "Invalid hosted flow URL"))
            return
        }
        webView.load(URLRequest(url: url))
    }

    // MARK: - Swipe-to-dismiss safety net

    /// Drives the custom slide-down dismissal. This is the SDK's one
    /// self-teardown: a completed swipe reports `.cancelled` AND dismisses, so
    /// the user is never trapped even when the hosted flow hides its own header.
    @objc private func handleDismissPan(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: view)
        let height = max(view.bounds.height, 1)
        let progress = min(max(translation.y / height, 0), 1)
        let velocity = pan.velocity(in: view)

        switch pan.state {
        case .began:
            let interactor = UIPercentDrivenInteractiveTransition()
            self.interactor = interactor
            dismissTransitioning.interactor = interactor
            dismiss(animated: true)
        case .changed:
            interactor?.update(progress)
        case .ended, .cancelled, .failed:
            let shouldFinish = pan.state == .ended && (progress > 0.3 || velocity.y > 800)
            if shouldFinish {
                emit(.cancelled)
                interactor?.finish()
            } else {
                interactor?.cancel()
            }
            interactor = nil
            dismissTransitioning.interactor = nil
        default:
            break
        }
    }

    /// Only begin the dismiss pan for a deliberate downward drag starting in the
    /// top safe-area band, so it never fights the WebView's own scroll/taps
    /// (the hosted flow is a fixed viewport pinned to the top — see
    /// `scrollViewDidScroll`).
    func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        guard let pan = recognizer as? UIPanGestureRecognizer else { return true }
        let start = pan.location(in: view)
        let topBand = view.safeAreaInsets.top + 44
        guard start.y <= topBand else { return false }
        let velocity = pan.velocity(in: view)
        return velocity.y > 0 && abs(velocity.y) > abs(velocity.x)
    }

    /// Forwards a status update to the host. Never dismisses — closing is the
    /// host's decision (via `SentinelSession.dismiss()`) or the swipe-to-dismiss
    /// gesture above.
    private func emit(_ event: SentinelEvent) {
        let description = String(describing: event)
        Self.logger.log("event: \(description, privacy: .public)")
        onEvent(event)
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // Per the contract the web posts a JS object here, but the `cancel` path
        // (ChatRuntime) historically posted a JSON string — tolerate both so the
        // SDK works against already-deployed flows and stays robust to drift.
        guard message.name == "sentinel" else { return }
        let body: [String: Any]
        if let dict = message.body as? [String: Any] {
            body = dict
        } else if let json = message.body as? String,
            let data = json.data(using: .utf8),
            let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            body = parsed
        } else {
            return
        }
        guard let type = body["type"] as? String else { return }

        switch type {
        case "ready":
            emit(.ready)
        case "complete":
            switch body["outcome"] as? String {
            case "approved": emit(.completed(.approved))
            case "rejected": emit(.completed(.rejected))
            case "completed": emit(.completed(.completed))
            default: emit(.completed(.underReview))
            }
        case "error":
            let msg = (body["message"] as? String) ?? "Verification error"
            emit(.error(message: msg))
        case "cancel":
            // User confirmed the in-flow "Exit Onboarding" dialog. Report it and
            // let the host close — the SDK no longer tears itself down here.
            emit(.cancelled)
        case "close":
            // User tapped "Done" on the terminal outcome screen. Report it and let
            // the host dismiss — distinct from `cancel` (the flow finished).
            emit(.closed)
        default:
            break
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url,
            let base = URL(string: config.hostedFlowBaseURL)
        else {
            decisionHandler(.allow)
            return
        }
        let sameOrigin = url.scheme == base.scheme && url.host == base.host
        if sameOrigin {
            decisionHandler(.allow)
        } else {
            // Foreign links (terminal CTA / external pages) open in Safari.
            decisionHandler(.cancel)
            UIApplication.shared.open(url)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        emit(.loadFailed(message: "Failed to load verification: \(error.localizedDescription)"))
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        emit(.loadFailed(message: "Failed to load verification: \(error.localizedDescription)"))
    }

    // MARK: - WKUIDelegate (camera permission)

    @available(iOS 15.0, *)
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        // Liveness needs the camera. The system still shows its own prompt,
        // backed by the host app's NSCameraUsageDescription.
        decisionHandler(.grant)
    }

    // MARK: - UIScrollViewDelegate (keyboard focus-scroll guard)

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // At base zoom the page exactly fits the viewport, so the outer scroll view
        // has no business moving — keep it pinned to the top. This neutralises the
        // keyboard focus-scroll that would otherwise displace the fixed-height flow
        // under contentInsetAdjustmentBehavior = .never. When the user pinch-zooms
        // (zoomScale > minimum), real panning is expected, so we leave it alone.
        guard scrollView.zoomScale <= scrollView.minimumZoomScale else { return }
        if scrollView.contentOffset != .zero {
            scrollView.contentOffset = .zero
        }
    }
}
#endif
