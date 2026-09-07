import Foundation

public enum Inputs {
  public static let defaultExclusions = [
    ".build", ".swiftpm", ".git", "Pods", "Carthage", "DerivedData",
  ]

  public static func directory(_ path: String, excluding: [String] = []) throws -> [(
    path: String, source: String
  )] {
    try inventoryFiles(path, excluding: excluding).filter { $0.key.hasSuffix(".swift") }
      .map { (path: $0.key, source: try String(contentsOf: $0.value, encoding: .utf8)) }
      .sorted { $0.path < $1.path }
  }

  public static func gitRoot(_ path: String) throws -> String {
    try runGit(["rev-parse", "--show-toplevel"], at: path).trimmingCharacters(in: .newlines)
  }

  /// Content identifier, not authentication. Length prefixes separate paths and source bytes.
  public static func fingerprint(before: Snapshot, after: Snapshot) throws -> String {
    var bytes = Data()
    func append(_ value: String) {
      let data = Data(value.utf8)
      bytes.append(Data("\(data.count):".utf8))
      bytes.append(data)
    }
    for snapshot in [before, after] {
      append(String(snapshot.sourceByPath.count))
      for file in snapshot.sourceByPath.keys.sorted() {
        append(file)
        append(snapshot.sourceByPath[file]!)
      }
    }
    let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try bytes.write(to: temporary)
    defer { try? FileManager.default.removeItem(at: temporary) }
    return try runGit(["hash-object", "--no-filters", temporary.path], at: temporary.deletingLastPathComponent().path)
      .trimmingCharacters(in: .newlines)
  }

  public static func revision(_ ref: String, at root: String) throws -> String {
    try runGit(["rev-parse", "--verify", "--end-of-options", ref + "^{commit}"], at: root)
      .trimmingCharacters(in: .newlines)
  }

  public static func commonAncestor(_ ref: String, _ headRef: String, at root: String) throws
    -> String
  {
    let base = try revision(ref, at: root)
    let head = try revision(headRef, at: root)
    return try runGit(["merge-base", base, head], at: root).trimmingCharacters(in: .newlines)
  }

  public static func gitSnapshot(_ commit: String, at root: String, excluding: [String] = []) throws
    -> [(path: String, source: String)]
  {
    let resolved = try revision(commit, at: root)
    let entries = try runGit(["ls-tree", "-rz", resolved], at: root).split(separator: "\0")
    var selected: [(path: String, object: String)] = []
    for entry in entries {
      guard let tab = entry.firstIndex(of: "\t") else { continue }
      let header = entry[..<tab].split(separator: " ")
      let path = String(entry[entry.index(after: tab)...])
      guard header.count == 3, header[1] == "blob", header[0] == "100644" || header[0] == "100755",
        path.hasSuffix(".swift"), !excluded(path, extra: excluding)
      else { continue }
      selected.append((path, String(header[2])))
    }
    let objects = Array(Set(selected.map(\.object))).sorted()
    guard !objects.isEmpty else { return [] }
    let input = Data((objects.joined(separator: "\n") + "\n").utf8)
    let data = try runGitData(["cat-file", "--batch"], at: root, input: input)
    let sources = try GitBatch.decode(data, objects: objects)
    return selected.map { (path: $0.path, source: sources[$0.object]!) }.sorted { $0.path < $1.path }
  }

  public static func worktree(at root: String, excluding: [String] = []) throws -> [(
    path: String, source: String
  )] {
    let names = try runGit(
      ["ls-files", "--cached", "--others", "--exclude-standard", "-z"], at: root)
    var files: [(path: String, source: String)] = []
    let rootURL = URL(fileURLWithPath: root).resolvingSymlinksInPath()
    for path in Set(names.split(separator: "\0").map(String.init)).sorted() {
      guard path.hasSuffix(".swift"), !excluded(path, extra: excluding) else { continue }
      let url = rootURL.appendingPathComponent(path)
      guard FileManager.default.fileExists(atPath: url.path) else { continue }
      guard url.resolvingSymlinksInPath().path == url.standardizedFileURL.path else { continue }
      let values = try url.resourceValues(forKeys: [.isRegularFileKey])
      guard values.isRegularFile == true else { continue }
      files.append((path, try String(contentsOf: url, encoding: .utf8)))
    }
    return files
  }

  static func excluded(_ path: String, extra: [String]) -> Bool {
    if path.split(separator: "/").contains(where: { defaultExclusions.contains(String($0)) }) {
      return true
    }
    return extra.contains { path == $0 || path.hasPrefix($0 + "/") }
  }

  static func runGit(_ arguments: [String], at root: String) throws -> String {
    let data = try runGitData(arguments, at: root)
    guard let text = String(data: data, encoding: .utf8) else {
      throw SekkaError.message(
        "Git returned non-UTF-8 data; this prototype supports UTF-8 sources and paths only.")
    }
    return text
  }

  private static func runGitData(_ arguments: [String], at root: String, input: Data? = nil) throws -> Data {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["git", "-C", root] + arguments
    // A temporary stderr file prevents stdout/stderr pipe deadlocks on large repositories.
    let errorURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    FileManager.default.createFile(atPath: errorURL.path, contents: nil)
    defer { try? FileManager.default.removeItem(at: errorURL) }
    let errorHandle = try FileHandle(forWritingTo: errorURL)
    defer { try? errorHandle.close() }
    let output = Pipe()
    process.standardOutput = output
    process.standardError = errorHandle
    let inputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    var inputHandle: FileHandle?
    defer {
      try? inputHandle?.close()
      try? FileManager.default.removeItem(at: inputURL)
    }
    if let input {
      try input.write(to: inputURL)
      inputHandle = try FileHandle(forReadingFrom: inputURL)
    }
    // Regular-file stdin avoids blocking while Git fills its stdout pipe with batch results.
    process.standardInput = inputHandle ?? FileHandle.nullDevice
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      let detail = (try? String(contentsOf: errorURL, encoding: .utf8)) ?? "Git failed"
      throw SekkaError.message(detail.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    return data
  }
}
