// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "DependencyRelayScratch",
  platforms: [.macOS(.v13)],
  dependencies: [.package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "603.0.1"),
    .package(path: "../../Packages/CallbackContracts")],
  targets: [
    .executableTarget(name: "relay-probe", dependencies: [
      .product(name: "SwiftSyntax", package: "swift-syntax"),
      .product(name: "SwiftParser", package: "swift-syntax")]),
    .executableTarget(name: "callback-probe", dependencies: [.product(name: "CallbackContracts", package: "callbackcontracts"),
      .product(name: "SwiftSyntax", package: "swift-syntax")]),
    .executableTarget(name: "contract-probe", dependencies: [.product(name: "CallbackContracts", package: "callbackcontracts"),
      .product(name: "SwiftSyntax", package: "swift-syntax")])])
