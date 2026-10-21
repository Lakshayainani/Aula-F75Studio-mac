// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "F75Studio",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "F75Studio", targets: ["F75Studio"]), .executable(name: "f75ctl", targets: ["F75CLI"])],
    targets: [
        .target(name: "F75Core"),
        .executableTarget(name: "F75Studio", dependencies: ["F75Core"]),
        .executableTarget(name: "F75CLI", dependencies: ["F75Core"])
    ]
)
