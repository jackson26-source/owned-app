// swift-tools-version: 5.9
import PackageDescription

// NOTE for whoever picks this up: this project is defined as a Swift Package
// with an .iOSApplication product instead of a traditional .xcodeproj.
// That was a deliberate choice, not an accident — see README.md "Why a Swift
// Package instead of an .xcodeproj" for the full reasoning. Short version:
// this was authored in a Linux sandbox with no Xcode and no way to run the
// Swift compiler to check syntax, so a small, simple manifest (this file)
// was safer to hand-write correctly than a large, UUID-linked .pbxproj would
// have been. The real test of whether this is right happens the first time
// CI runs it on an actual macOS runner — treat a failure here as an easy,
// expected first fix, not a sign the whole approach is wrong.

let package = Package(
      name: "Owned",
      platforms: [
                .iOS(.v17)
      ],
      products: [
                .iOSApplication(
                              name: "Owned",
                              targets: ["OwnedApp"],
                              bundleIdentifier: "dev.macless.owned",
                              teamIdentifier: "REPLACE_WITH_APPLE_TEAM_ID",
                              displayVersion: "0.1.0",
                              bundleVersion: "1",
                              appIcon: .asset("AppIcon"),
                              accentColor: .asset("AccentColor"),
                              supportedDeviceFamilies: [
                                                .phone
                              ],
                              supportedInterfaceOrientations: [
                                                .portrait
                              ],
                              capabilities: [
                                                .camera(purposeString: "Owned uses your camera to scan receipts so you don't have to type in the details by hand.")
                              ]
                )
      ],
      targets: [
                .executableTarget(
                              name: "OwnedApp",
                              path: "Sources/OwnedApp",
                              resources: [
                                                .process("Resources/Assets.xcassets")
                              ]
                )
      ]
)
