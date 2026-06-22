# Sentinel iOS SDK

Native iOS SDK for the **Sentinel** identity-verification flow. It hosts the
deployed web verification runtime in a `WKWebView` and adds a native layer for
camera-permission handling and a typed result callback — so the
chat/widget/branding UI stays in sync with web automatically.

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
    .package(url: "https://github.com/prawatstackflow/sentinel-ios.git", from: "0.1.0")
]
```

Or in Xcode: **File ▸ Add Package Dependencies…** and enter the repo URL.

### CocoaPods

The podspec ships in the repo, so the git form works immediately:

```ruby
pod 'Sentinel', :git => 'https://github.com/prawatstackflow/sentinel-ios.git', :tag => '0.1.0'
```

Once the spec is published to the CocoaPods trunk, `pod 'Sentinel', '~> 0.1'` will also work.

## Usage

```swift
import Sentinel

Sentinel.present(from: self, config: SentinelConfig(
    sessionId: sessionId,         // from your backend's POST /sessions
    sessionToken: sessionToken,
    // hostedFlowBaseURL defaults to the Finvasia test environment; override:
    // hostedFlowBaseURL: "https://identity.yourco.com",
    theme: .system
)) { result in
    switch result {
    case .approved:            goToSuccess()
    case .rejected:            goToRejected()
    case .underReview:         goToPending()
    case .cancelled:           break               // user dismissed
    case .failed(let message): showError(message)
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
- Returns a typed `SentinelResult`; maps a failed page load to `.failed`.
- Keeps navigation within the hosted origin (foreign CTA links open in Safari).

## Known follow-ups

- Optional host-proxied session-token refresh for long-lived sessions.
