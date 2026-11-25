// swift-tools-version:5.9
import PackageDescription

var targets: [Target] = [
    .target(name: "MessengerCore"),
    .testTarget(name: "MessengerCoreTests", dependencies: ["MessengerCore"]),
]

// The app target needs AppKit and WebKit, so it is only declared on macOS.
// This keeps `swift test` (Core only) working on Linux.
#if os(macOS)
targets.append(
    .executableTarget(name: "MessengerWrapper", dependencies: ["MessengerCore"])
)
#endif

let package = Package(
    name: "MessengerWrapper",
    platforms: [.macOS(.v13)],
    targets: targets
)
