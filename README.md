# Sentinel iOS SDK

Native iOS SDK for the **Sentinel** identity-verification flow. It hosts the
deployed web verification runtime in a `WKWebView` and adds a native layer for
camera-permission handling and a typed status callback — so the
chat/widget/branding UI stays in sync with web automatically.

The SDK **reports** status; it does not close itself. On every status change it
calls your `onEvent` handler and leaves the WebView open; the host decides when
to tear down via the returned `SentinelSession`. (The SDK's own navigation-bar
Close button is the one exception — it emits `.cancelled` and dismisses so the
user is never trapped.)

See `docs/mobile-sdk-contract.md` in the platform repo for the cross-platform
contract this SDK mirrors.

## Requirements

- iOS **14.3+** (WKWebView `getUserMedia` for liveness).
- The **host app** must declare `NSCameraUsageDescription` in its Info.plist —
  a framework cannot supply the host's usage string.

## Install

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/prawatstackflow/sentinel-ios.git", from: "0.1.3")
]
```

Or in Xcode: **File ▸ Add Package Dependencies…** and enter the repo URL.

### CocoaPods

The podspec ships in the repo, so the git form works immediately:

```ruby
pod 'Sentinel', :git => 'https://github.com/prawatstackflow/sentinel-ios.git', :tag => '0.1.3'
```

Once the spec is published to the CocoaPods trunk, `pod 'Sentinel', '~> 0.1'` will also work.

## Usage

```swift
import Sentinel

let session = Sentinel.present(from: self, config: SentinelConfig(
    sessionId: sessionId,         // from your backend's POST /sessions
    sessionToken: sessionToken,
    // hostedFlowBaseURL defaults to the Finvasia test environment; override:
    // hostedFlowBaseURL: "https://identity.yourco.com",
    theme: .system
)) { event in
    switch event {
    case .ready:                    break
    case .completed(let outcome):
        switch outcome {
        case .approved:    goToSuccess()
        case .rejected:    goToRejected()
        case .underReview: goToPending()
        case .completed:   goToDone()
        }
        session?.dismiss()          // host decides when to close
    case .cancelled:                session?.dismiss()   // user exited
    case .error(let message):       showError(message); session?.dismiss()
    case .loadFailed(let message):  showError(message); session?.dismiss()
    }
}
```

`sessionId` and `sessionToken` come from **your backend** calling
`POST /sessions` (via `@finvasia-identity/node`) — never minted on the device.

## Example app

A runnable SwiftUI harness lives in [`Example/`](Example). The Xcode project is
generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
cd Example
xcodegen generate
open SentinelExample.xcodeproj   # build & run on a simulator/device
```

The harness offers two ways to start a flow:

- **Start Demo Session** — mints a fresh session for you (calls `POST /sessions`)
  and launches the SDK in one tap. Configure it by copying
  [`SentinelExample/DemoSecrets.example.plist`](Example/SentinelExample/DemoSecrets.example.plist)
  to `DemoSecrets.plist` (git-ignored) and setting `DEMO_API_KEY` to a sandbox
  tenant API key. `DEMO_API_BASE_URL` / `DEMO_HOSTED_FLOW_BASE_URL` default to the
  local LAN stack; point them at `https://test-api-identity.finvasia.com` /
  `https://test-identity.finvasia.com` for the deployed sandbox. Until a key is
  set, the button stays disabled. *(Demo only — never ship an API key in a real
  app; keep it server-side.)*
- **Manual** — paste a `sessionId` + `sessionToken`, optionally override the base
  URL, and tap **Start verification**.

## What the SDK handles

- Loads `{hostedFlowBaseURL}/verification/{sessionId}?token=…&theme=…&platform=native`.
- Grants the WebView camera capture request (iOS 15+ `WKUIDelegate`; iOS 14.3–14
  uses the system prompt backed by `NSCameraUsageDescription`).
- Reports typed `SentinelEvent`s via `onEvent`; maps a failed page load to
  `.loadFailed`. Never closes itself on a web status — the host dismisses via the
  returned `SentinelSession`.
- Keeps navigation within the hosted origin (foreign CTA links open in Safari).

## Known follow-ups

- Optional host-proxied session-token refresh for long-lived sessions.
