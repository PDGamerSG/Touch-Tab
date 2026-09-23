// swift-tools-version:5.7
// Builds the platform independent part of the app so it can be unit tested with `swift test`.
// The app itself is built with Touch-Tab.xcodeproj.
import PackageDescription

let package = Package(
    name: "TouchTabCore",
    platforms: [.macOS(.v10_15)],
    targets: [
        .target(
            name: "TouchTabCore",
            path: "Touch-Tab",
            exclude: [
                "AboutView.swift",
                "AppDelegate.swift",
                "Assets.xcassets",
                "BundleInfo.swift",
                "LaunchAtLogin.swift",
                "PrivacyHelper.swift",
                "SwipeManager.swift",
                "Touch-Tab.entitlements",
                "main.swift",
            ],
            sources: [
                "AppSwitcher.swift",
                "GestureRecognizer.swift",
                "Settings.swift",
            ]
        ),
        .testTarget(
            name: "TouchTabCoreTests",
            dependencies: ["TouchTabCore"],
            path: "Tests/TouchTabCoreTests"
        ),
    ]
)
