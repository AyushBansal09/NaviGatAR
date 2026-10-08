// swift-tools-version:5.9
// Builds the platform-independent navigation core (NaviGatAR/Core) as a
// library so its logic can be unit-tested with `swift test` on macOS or Linux.
// The iOS app itself is built from NaviGatAR.xcodeproj.
import PackageDescription

let package = Package(
    name: "NaviGatARCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "NaviGatARCore", targets: ["NaviGatARCore"])],
    targets: [
        .target(name: "NaviGatARCore", path: "NaviGatAR/Core"),
        .testTarget(name: "NaviGatARCoreTests", dependencies: ["NaviGatARCore"], path: "CoreTests"),
    ]
)
