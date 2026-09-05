// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Patchwork",
  platforms: [.macOS(.v13)],
  products: [.executable(name: "patchwork", targets: ["patchwork"])],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "603.0.1")
  ],
  targets: [
    .target(
      name: "PatchworkCore",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
      ]),
    .executableTarget(name: "patchwork", dependencies: ["PatchworkCore"]),
    .testTarget(name: "PatchworkCoreTests", dependencies: ["PatchworkCore"]),
  ]
)
