// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "StructuralContext",
  platforms: [.macOS(.v13)],
  dependencies: [.package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "603.0.1")],
  targets: [
    .target(name: "StructuralContext", dependencies: [
      .product(name: "SwiftSyntax", package: "swift-syntax"),
      .product(name: "SwiftParser", package: "swift-syntax"),
    ]),
    .executableTarget(name: "context-probe", dependencies: ["StructuralContext"]),
    .testTarget(name: "StructuralContextTests", dependencies: ["StructuralContext"]),
  ]
)
