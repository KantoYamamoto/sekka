import Foundation
import CryptoKit
import SwiftParser
import SwiftSyntax

public struct ParsedSource {
  public let path: String
  public let tree: SourceFileSyntax
  public let converter: SourceLocationConverter
}

public enum InputFailure: Error { case message(String) }
public func inputFailure(_ message: String) throws -> Never { throw InputFailure.message(message) }

/// Source bytes only. No target checkout, compilation or execution.
public struct SourceInventory {
  public let hash: String
  public let files: [String]
  public let sources: [ParsedSource]

  public init(_ directory: String) throws {
    let suppliedRoot = URL(fileURLWithPath: directory).standardizedFileURL
    let resources = try suppliedRoot.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard resources.isDirectory == true, resources.isSymbolicLink != true else { try inputFailure("input must be an ordinary source directory") }
    guard let resolved = realpath(suppliedRoot.path, nil) else { try inputFailure("cannot resolve supplied directory") }
    let root = URL(fileURLWithPath: String(cString: resolved)); free(resolved)
    var enumerationError: Error?
    guard let listing = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey],
      options: [], errorHandler: { _, error in enumerationError = error; return false }) else { try inputFailure("cannot enumerate source directory") }
    var inputs: [URL] = []
    while let file = listing.nextObject() as? URL {
      guard try file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { try inputFailure("symlink in supplied inventory") }
      if file.pathExtension == "swift" { inputs.append(file) }
    }
    if let enumerationError { throw enumerationError }
    inputs.sort { $0.path < $1.path }
    guard !inputs.isEmpty, inputs.count <= 128 else { try inputFailure("supply 1...128 Swift files") }
    var directoryBytes = 0
    let raw = try inputs.map { url -> (path: String, source: String) in
      guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { try inputFailure("Swift source must be an ordinary file") }
      let bytes = try Data(contentsOf: url)
      directoryBytes += bytes.count
      guard bytes.count <= 4_000_000, directoryBytes <= 20_000_000, let source = String(data: bytes, encoding: .utf8), Data(source.utf8) == bytes else { try inputFailure("inventory must be bounded UTF-8") }
      return (String(url.path.dropFirst(root.path.count + 1)), source)
    }
    try self.init(raw)
  }

  /// Reuses already-read Git/directory source; does not materialize or execute target files.
  public init(_ raw: [(path: String, source: String)]) throws {
    guard raw.count <= 128, Set(raw.map(\.path)).count == raw.count else { try inputFailure("trial accepts at most 128 unique Swift paths per side") }
    let sorted = raw.sorted { $0.path < $1.path }
    files = sorted.map(\.path)
    var parsed: [ParsedSource] = [], hashed = Data(), total = 0
    for (file, source) in sorted {
      guard !file.isEmpty, !file.hasPrefix("/"), !file.split(separator: "/").contains(".."), file.hasSuffix(".swift") else { try inputFailure("expected relative Swift path") }
      let bytes = Data(source.utf8); total += bytes.count
      guard bytes.count <= 4_000_000, total <= 20_000_000 else { try inputFailure("inventory must be bounded UTF-8") }
      let tree = Array(bytes).withUnsafeBufferPointer { Parser.parse(source: $0, swiftVersion: .v6) }
      guard !tree.hasError else { try inputFailure("Swift parse failed: " + file) }
      hashed.append(Data((String(file.utf8.count) + ":" + file + ":" + String(bytes.count) + ":").utf8)); hashed.append(bytes)
      parsed.append(ParsedSource(path: file, tree: tree, converter: SourceLocationConverter(fileName: file, tree: tree)))
    }
    sources = parsed
    hash = SHA256.hash(data: hashed).map { String(format: "%02x", $0) }.joined()

  }
}
