import XCTest

@testable import Sentinel

final class VerificationURLTests: XCTestCase {
    func testBuildsVerificationURLWithDefaults() throws {
        let config = SentinelConfig(sessionId: "sess_123", sessionToken: "tok_abc")
        let url = try XCTUnwrap(VerificationURL.build(for: config, isDarkMode: false))
        let string = url.absoluteString
        XCTAssertTrue(
            string.hasPrefix("https://test-identity.finvasia.com/verification/sess_123?"),
            string)
        XCTAssertTrue(string.contains("token=tok_abc"))
        XCTAssertTrue(string.contains("platform=native"))
        XCTAssertTrue(string.contains("theme=light"))
    }

    func testSystemThemeResolvesToDeviceSetting() throws {
        let config = SentinelConfig(sessionId: "s", sessionToken: "t", theme: .system)
        let dark = try XCTUnwrap(VerificationURL.build(for: config, isDarkMode: true))
        XCTAssertTrue(dark.absoluteString.contains("theme=dark"))
        let light = try XCTUnwrap(VerificationURL.build(for: config, isDarkMode: false))
        XCTAssertTrue(light.absoluteString.contains("theme=light"))
    }

    func testExplicitThemeAndLocale() throws {
        let config = SentinelConfig(
            sessionId: "s", sessionToken: "t", theme: .dark, locale: "en-GB")
        let string = try XCTUnwrap(VerificationURL.build(for: config, isDarkMode: false))
            .absoluteString
        XCTAssertTrue(string.contains("theme=dark"))
        XCTAssertTrue(string.contains("locale=en-GB"))
    }

    func testTrailingSlashBaseURLIsNormalized() throws {
        let config = SentinelConfig(
            sessionId: "s", sessionToken: "t", hostedFlowBaseURL: "https://id.example.com/")
        let string = try XCTUnwrap(VerificationURL.build(for: config, isDarkMode: false))
            .absoluteString
        XCTAssertTrue(string.hasPrefix("https://id.example.com/verification/s?"), string)
    }
}
