import Foundation

public struct InputChange: Codable, Equatable, Sendable {
  public let file: String
  public let change: String
  /// swift / non-swift / excluded / unsupported-file-kind
  public let analysis: String
}

public struct ComparisonInventory: Codable, Equatable, Sendable {
  public let scope: String
  public let changes: [InputChange]
}

extension Inputs {
  public static func gitChanges(
    from base: String, to head: String?, at root: String, excluding: [String] = []
  ) throws -> ComparisonInventory {
    let base = try revision(base, at: root)
    let head = try head.map { try revision($0, at: root) }
    var arguments = ["diff", "--raw", "--no-renames", "--no-ext-diff", "--no-textconv",
      "--ignore-submodules=none", "-z", base]
    if let head { arguments.append(head) }
    arguments.append("--")
    let fields = try runGit(arguments, at: root).split(separator: "\0", omittingEmptySubsequences: false)
    var changes: [String: InputChange] = [:]
    var index = 0
    while index < fields.count - 1 {
      let header = fields[index].split(separator: " ")
      guard header.count == 5, header[0].hasPrefix(":"), index + 1 < fields.count - 1 else {
        throw SekkaError.message("Cannot decode Git changed-file inventory")
      }
      let path = String(fields[index + 1])
      let status = String(header[4])
      guard ["A", "D", "M", "T", "U"].contains(status), !path.isEmpty else {
        throw SekkaError.message("Unsupported Git changed-file inventory entry")
      }
      let modes = [String(header[0].dropFirst()), String(header[1])]
      let regular = modes.allSatisfy { ["000000", "100644", "100755"].contains($0) }
      changes[path] = InputChange(
        file: path, change: status == "A" ? "added" : status == "D" ? "deleted" : "modified",
        analysis: analysisStatus(path, regular: regular, excluding: excluding))
      index += 2
    }
    if head == nil {
      let names = try runGit(["ls-files", "--others", "--exclude-standard", "-z"], at: root)
      for path in names.split(separator: "\0").map(String.init) {
        let url = URL(fileURLWithPath: root).appendingPathComponent(path)
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        changes[path] = InputChange(
          file: path, change: "added",
          analysis: analysisStatus(path, regular: values.isRegularFile == true && values.isSymbolicLink != true,
            excluding: excluding))
      }
    }
    return ComparisonInventory(
      scope: head == nil ? "git-worktree (tracked changes and non-ignored untracked paths)" : "git-revisions (all changed paths)",
      changes: changes.values.sorted { $0.file < $1.file })
  }

  public static func directoryChanges(
    before: String, after: String, excluding: [String] = []
  ) throws -> ComparisonInventory {
    let old = try inventoryFiles(before)
    let new = try inventoryFiles(after)
    var changes: [InputChange] = []
    for path in Set(old.keys).union(new.keys).sorted() {
      if let a = old[path], let b = new[path], try equalContents(a, b) { continue }
      changes.append(InputChange(
        file: path, change: old[path] == nil ? "added" : new[path] == nil ? "deleted" : "modified",
        analysis: analysisStatus(path, regular: true, excluding: excluding)))
    }
    return ComparisonInventory(
      scope: "directories (regular-file contents; symlinks and default excluded paths omitted)",
      changes: changes)
  }

  private static func analysisStatus(_ path: String, regular: Bool, excluding: [String]) -> String {
    if excluded(path, extra: excluding) { return "excluded" }
    if !regular { return "unsupported-file-kind" }
    return path.hasSuffix(".swift") ? "swift" : "non-swift"
  }

  static func inventoryFiles(_ path: String, excluding: [String] = []) throws -> [String: URL] {
    let root = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
      throw SekkaError.message("Not a directory: \(path)")
    }
    var failure: Error?
    guard let enumerator = FileManager.default.enumerator(
      at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
      errorHandler: { _, error in failure = error; return false }) else {
      throw SekkaError.message("Cannot enumerate comparison input: \(path)")
    }
    var files: [String: URL] = [:]
    let prefix = root.path == "/" ? "/" : root.path + "/"
    for case let url as URL in enumerator {
      let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
      if values.isSymbolicLink == true { enumerator.skipDescendants(); continue }
      let resolved = url.resolvingSymlinksInPath().path
      guard resolved.hasPrefix(prefix) else { continue }
      let relative = String(resolved.dropFirst(prefix.count))
      if excluded(relative, extra: excluding) { enumerator.skipDescendants(); continue }
      if values.isRegularFile == true { files[relative] = url }
    }
    if let failure { throw failure }
    return files
  }

  private static func equalContents(_ a: URL, _ b: URL) throws -> Bool {
    let left = try FileHandle(forReadingFrom: a)
    defer { try? left.close() }
    let right = try FileHandle(forReadingFrom: b)
    defer { try? right.close() }
    while true {
      let x = try left.read(upToCount: 65_536) ?? Data()
      let y = try right.read(upToCount: 65_536) ?? Data()
      if x != y { return false }
      if x.isEmpty { return true }
    }
  }
}

extension ComparisonInventory {
  var textLines: [String] {
    let analyzed = changes.filter { $0.analysis == "swift" }.count
    var lines = ["Comparison scope: \(scope)",
      "Changed paths: \(changes.count) · Swift candidates: \(analyzed) · outside Swift analysis: \(changes.count - analyzed)"]
    if !changes.isEmpty && analyzed == 0 { lines.append("Changes exist, but none are analyzed as Swift. Review the ordinary diff.") }
    for item in changes.prefix(20) {
      let path = item.file.contains(where: { $0.isNewline || $0 == "\t" }) ? String(reflecting: item.file) : item.file
      lines.append("  \(path) [\(item.change); \(item.analysis)]")
    }
    if changes.count > 20 { lines.append("  … \(changes.count - 20) more paths; complete list: --format json → inventory.changes") }
    return lines + [""]
  }
}
