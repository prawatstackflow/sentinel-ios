#if canImport(UIKit)
import UIKit
import WebKit

/// Internal host controller. Loads the hosted verification runtime in a
/// WKWebView and bridges its lifecycle/result messages to a [SentinelResult].
final class SentinelViewController: UIViewController, WKScriptMessageHandler,
    WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate
{
    private let config: SentinelConfig
    private let completion: (SentinelResult) -> Void
    private var resultDelivered = false
    private var webView: WKWebView!

    init(config: SentinelConfig, completion: @escaping (SentinelResult) -> Void) {
        self.config = config
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
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
        title = "Verification"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))

        let isDark = traitCollection.userInterfaceStyle == .dark
        guard let url = VerificationURL.build(for: config, isDarkMode: isDark) else {
            deliver(.failed(message: "Invalid hosted flow URL"))
            return
        }
        webView.load(URLRequest(url: url))
    }

    @objc private func cancelTapped() {
        deliver(.cancelled)
    }

    private func deliver(_ result: SentinelResult) {
        guard !resultDelivered else { return }
        resultDelivered = true
        let completion = self.completion
        dismiss(animated: true) { completion(result) }
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "sentinel",
            let body = message.body as? [String: Any],
            let type = body["type"] as? String
        else { return }

        switch type {
        case "complete":
            switch body["outcome"] as? String {
            case "approved": deliver(.approved)
            case "rejected": deliver(.rejected)
            default: deliver(.underReview)
            }
        case "error":
            let msg = (body["message"] as? String) ?? "Verification error"
            deliver(.failed(message: msg))
        default:
            break  // "ready" is informational.
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
        deliver(.failed(message: "Failed to load verification: \(error.localizedDescription)"))
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        deliver(.failed(message: "Failed to load verification: \(error.localizedDescription)"))
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
