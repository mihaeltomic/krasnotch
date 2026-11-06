// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Krasnotch",
  platforms: [.macOS(.v15)],
  targets: [
    .target(name: "KrasnotchKit"),
    .executableTarget(name: "Krasnotch", dependencies: ["KrasnotchKit"]),
    .testTarget(name: "KrasnotchKitTests", dependencies: ["KrasnotchKit"]),
  ]
)
