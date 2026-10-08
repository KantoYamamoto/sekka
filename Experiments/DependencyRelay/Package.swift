// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "DependencyRelayScratch",
  platforms: [.macOS(.v13)],
  dependencies: [.package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "604.0.0")],
  targets: [
    .target(name: "ProbeSupport", dependencies: [
      .product(name: "SwiftSyntax", package: "swift-syntax"),
      .product(name: "SwiftParser", package: "swift-syntax")]),
    .executableTarget(name: "relay-probe", dependencies: [
      .product(name: "SwiftSyntax", package: "swift-syntax"),
      .product(name: "SwiftParser", package: "swift-syntax")]),
    .executableTarget(name: "callback-probe", dependencies: ["ProbeSupport",
      .product(name: "SwiftSyntax", package: "swift-syntax")]),
    .executableTarget(name: "contract-probe", dependencies: ["ProbeSupport",
      .product(name: "SwiftSyntax", package: "swift-syntax")])])
