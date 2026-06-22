// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Sentinel",
    platforms: [
        // WKWebView getUserMedia (liveness) requires iOS 14.3+. SPM platform
        // granularity is major.minor; the runtime requirement is documented.
        .iOS(.v14),
    ],
    products: [
        .library(name: "Sentinel", targets: ["Sentinel"]),
    ],
    targets: [
        .target(
            name: "Sentinel",
            path: "Sources/Sentinel"
        ),
        .testTarget(
            name: "SentinelTests",
            dependencies: ["Sentinel"],
            path: "Tests/SentinelTests"
        ),
    ]
)
