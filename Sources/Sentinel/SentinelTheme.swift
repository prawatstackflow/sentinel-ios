import Foundation

/// Color scheme for the verification surface.
public enum SentinelTheme {
    case light
    case dark
    /// Resolve to the device's current light/dark setting at launch time.
    case system
}
