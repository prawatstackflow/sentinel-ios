import Foundation

/// Builds the hosted verification URL the WebView loads. Pure logic (no UIKit)
/// so it is unit-testable on any platform.
enum VerificationURL {
    static func build(for config: SentinelConfig, isDarkMode: Bool) -> URL? {
        guard var components = URLComponents(string: config.hostedFlowBaseURL) else {
            return nil
        }
        var basePath = components.path
        if basePath.hasSuffix("/") {
            basePath.removeLast()
        }
        components.path = basePath + "/verification/" + config.sessionId

        var items = [
            URLQueryItem(name: "token", value: config.sessionToken),
            URLQueryItem(name: "platform", value: "native"),
            URLQueryItem(name: "theme", value: themeParam(config.theme, isDarkMode: isDarkMode)),
        ]
        if let locale = config.locale {
            items.append(URLQueryItem(name: "locale", value: locale))
        }
        components.queryItems = items
        return components.url
    }

    static func themeParam(_ theme: SentinelTheme, isDarkMode: Bool) -> String {
        switch theme {
        case .light: return "light"
        case .dark: return "dark"
        case .system: return isDarkMode ? "dark" : "light"
        }
    }
}
