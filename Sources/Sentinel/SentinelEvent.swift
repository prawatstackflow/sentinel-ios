import Foundation

/// Terminal outcome reported by the hosted flow on a `.completed` event.
///
/// `approved | rejected | underReview` are the scored outcomes a main
/// verification flow resolves to; `completed` is the neutral "done" state a
/// data-collection (named) flow reports, which makes no decision.
public enum SentinelOutcome: Equatable {
    case approved
    case rejected
    case underReview
    case completed
}

/// A status update reported by the verification flow.
///
/// The SDK forwards these to the host and **never dismisses itself** in
/// response. The host decides when to close by calling
/// `SentinelSession.dismiss()`. The only self-teardown is the SDK's own
/// navigation-bar Close button, which emits `.cancelled` alongside dismissing.
public enum SentinelEvent: Equatable {
    /// The hosted runtime mounted.
    case ready
    /// The flow reached a terminal outcome (see `SentinelOutcome`).
    case completed(SentinelOutcome)
    /// The user confirmed the in-flow "Exit Onboarding" dialog, or dismissed via
    /// the SDK's own navigation-bar Close button.
    case cancelled
    /// The web runtime reported an unrecoverable error.
    case error(message: String)
    /// The WebView failed to load (page-load / transport failure). SDK-level,
    /// not a web outcome.
    case loadFailed(message: String)
}
