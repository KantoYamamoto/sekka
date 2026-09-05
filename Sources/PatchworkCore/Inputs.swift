import Foundation

public enum Inputs {
  public static let defaultExclusions = [
    ".build", ".swiftpm", ".git", "Pods", "Carthage", "DerivedData",
  ]

  public static func directory(_ path: String, excluding: [String] = []) throws -> [(
    path: String, source: String
  )] {
    let root = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      throw PatchworkError.message("Not a directory: \(path)")
    }
    var enumerationError: Error?
    guard
      let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .isDirectoryKey],
        errorHandler: { _, error in
          enumerationError = error
          return false
        })
    else { throw PatchworkError.message("Cannot read directory: \(path)") }
    var files: [(path: String, source: String)] = []
    for case let url as URL in enumerator {
      let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
      if values.isSymbolicLink == true {
        enumerator.skipDescendants()
        continue
      }
      // Foundation can enumerate /var under its /private/var alias on macOS.
      let resolvedPath = url.resolvingSymlinksInPath().path
      let prefix = root.path == "/" ? "/" : root.path + "/"
      guard resolvedPath.hasPrefix(prefix) else { continue }
      let relative = String(resolvedPath.dropFirst(prefix.count))
      if excluded(relative, extra: excluding) {
        enumerator.skipDescendants()
        continue
      }
      guard values.isRegularFile == true, relative.hasSuffix(".swift") else { continue }
      files.append((relative, try String(contentsOf: url, encoding: .utf8)))
    }
    if let enumerationError { throw enumerationError }
    return files.sorted { $0.path < $1.path }
  }

  public static func gitRoot(_ path: String) throws -> String {
    try runGit(["rev-parse", "--show-toplevel"], at: path).trimmingCharacters(in: .newlines)
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
    var files: [(path: String, source: String)] = []
    for entry in entries {
      guard let tab = entry.firstIndex(of: "\t") else { continue }
      let header = entry[..<tab].split(separator: " ")
      let path = String(entry[entry.index(after: tab)...])
      guard header.count == 3, header[1] == "blob", header[0] == "100644" || header[0] == "100755",
        path.hasSuffix(".swift"), !excluded(path, extra: excluding)
      else { continue }
      files.append((path, try runGit(["cat-file", "blob", String(header[2])], at: root)))
    }
    return files.sorted { $0.path < $1.path }
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

  private static func excluded(_ path: String, extra: [String]) -> Bool {
    if path.split(separator: "/").contains(where: { defaultExclusions.contains(String($0)) }) {
      return true
    }
    return extra.contains { path == $0 || path.hasPrefix($0 + "/") }
  }

  private static func runGit(_ arguments: [String], at root: String) throws -> String {
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
    process.standardInput = FileHandle.nullDevice
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      let detail = (try? String(contentsOf: errorURL, encoding: .utf8)) ?? "Git failed"
      throw PatchworkError.message(detail.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    guard let text = String(data: data, encoding: .utf8) else {
      throw PatchworkError.message(
        "Git returned non-UTF-8 data; this prototype supports UTF-8 sources and paths only.")
    }
    return text
  }
}
