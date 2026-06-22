import Foundation

/// Terminal result of a verification flow.
public enum SentinelResult: Equatable {
    /// Verification approved (web outcome `approved`).
    case approved
    /// Verification rejected (web outcome `rejected`).
    case rejected
    /// Submitted, pending manual review (web outcome `under_review`).
    case underReview
    /// User dismissed the flow before reaching a terminal outcome.
    case cancelled
    /// Unrecoverable error (page load / transport / runtime stream).
    case failed(message: String)
}
