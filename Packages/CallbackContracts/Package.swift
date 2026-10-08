// swift-tools-version: 6.0
import PackageDescription

let package = Package(name: "CallbackContracts", platforms: [.macOS(.v13)],
  products: [.library(name: "CallbackContracts", targets: ["CallbackContracts"])],
  dependencies: [.package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "603.0.1")],
  targets: [.target(name: "CallbackContracts", dependencies: [
    .product(name: "SwiftSyntax", package: "swift-syntax"),
    .product(name: "SwiftParser", package: "swift-syntax")])])
