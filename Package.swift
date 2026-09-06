// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Sekka",
  platforms: [.macOS(.v13)],
  products: [.executable(name: "sekka", targets: ["sekka"])],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "603.0.1")
  ],
  targets: [
    .target(
      name: "SekkaCore",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
      ]),
    .executableTarget(name: "sekka", dependencies: ["SekkaCore"]),
    .testTarget(name: "SekkaCoreTests", dependencies: ["SekkaCore"]),
  ]
)
