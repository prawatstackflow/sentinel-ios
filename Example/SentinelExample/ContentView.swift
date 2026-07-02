import Sentinel
import SwiftUI
import UIKit

/// Harness for testing the Sentinel SDK on a device/simulator. Two ways to
/// start a flow:
///   1. "Start Demo Session" — mints a fresh session against the configured
///      sandbox API (DemoSecrets.plist) and launches the SDK in one tap.
///   2. Manual — paste a sessionId + sessionToken minted by your backend's
///      `POST /sessions` and launch.
struct ContentView: View {
    @State private var sessionId = ""
    @State private var sessionToken = ""
    @State private var baseURL = DemoConfig.hostedFlowBaseURL
    @State private var resultText = "Result: —"
    @State private var demoStatus = DemoConfig.apiKey.isEmpty
        ? "Set DEMO_API_KEY in DemoSecrets.plist to use this."
        : ""
    @State private var creatingSession = false
    // Held so the demo can close the flow when *it* decides — the SDK no longer
    // self-dismisses on a status event.
    @State private var session: SentinelSession?

    private var demoConfigured: Bool { !DemoConfig.apiKey.isEmpty }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Demo")) {
                    Button(action: startDemoSession) {
                        HStack {
                            Text("Start Demo Session")
                            if creatingSession {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(!demoConfigured || creatingSession)
                    if !demoStatus.isEmpty {
                        Text(demoStatus)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                Section(header: Text("Manual session")) {
                    TextField("sessionId", text: $sessionId)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                    TextField("sessionToken", text: $sessionToken)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                    TextField("hostedFlowBaseURL", text: $baseURL)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                    Button("Start verification") { startManual() }
                        .disabled(sessionId.isEmpty || sessionToken.isEmpty)
                }
                Text(resultText)
            }
            .navigationTitle("Sentinel Example")
        }
    }

    private func startDemoSession() {
        creatingSession = true
        demoStatus = "Creating session…"
        Task { @MainActor in
            do {
                let session = try await DemoSessionService.createSession()
                creatingSession = false
                demoStatus = "Session \(session.sessionId.prefix(8))… created"
                present(
                    sessionId: session.sessionId,
                    sessionToken: session.sessionToken,
                    base: DemoConfig.hostedFlowBaseURL
                )
            } catch {
                creatingSession = false
                demoStatus = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func startManual() {
        let trimmedBase = baseURL.trimmingCharacters(in: .whitespaces)
        present(
            sessionId: sessionId.trimmingCharacters(in: .whitespaces),
            sessionToken: sessionToken.trimmingCharacters(in: .whitespaces),
            base: trimmedBase.isEmpty ? SentinelConfig.defaultHostedFlowBaseURL : trimmedBase
        )
    }

    private func present(sessionId: String, sessionToken: String, base: String) {
        guard let presenter = Self.topViewController() else { return }
        let config = SentinelConfig(
            sessionId: sessionId,
            sessionToken: sessionToken,
            hostedFlowBaseURL: base
        )
        session = Sentinel.present(from: presenter, config: config) { event in
            switch event {
            case .ready:
                resultText = "Status: ready"
            case .completed(let outcome):
                switch outcome {
                case .approved: resultText = "Result: APPROVED"
                case .rejected: resultText = "Result: REJECTED"
                case .underReview: resultText = "Result: UNDER REVIEW"
                case .completed: resultText = "Result: COMPLETED"
                }
                // Demo close policy: the host decides to close on a terminal event.
                session?.dismiss()
            case .cancelled:
                resultText = "Result: cancelled"
                session?.dismiss()
            case .error(let message):
                resultText = "Result: error — \(message)"
                session?.dismiss()
            case .loadFailed(let message):
                resultText = "Result: load failed — \(message)"
                session?.dismiss()
            }
        }
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        var top = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
