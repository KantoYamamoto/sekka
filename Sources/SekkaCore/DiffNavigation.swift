import Foundation

/// Source hunks from the exact snapshots already analyzed, never from a later checkout.
public enum DiffNavigation {
  public static func render(
    before: Snapshot, after: Snapshot, report: DiffReport, file: String, at: String? = nil
  ) throws -> String {
    guard report.coverage.changedFiles.contains(where: { $0.file == file }) else {
      throw SekkaError.message("Not a changed analyzed Swift file: \(file)")
    }
    let patch = try sourceDiff(before.sourceByPath[file] ?? "", after.sourceByPath[file] ?? "")
    let hunks = parseHunks(patch)
    var selected = hunks
    var scope = "All file hunks."
    if let at {
      let parts = at.split(separator: ":", omittingEmptySubsequences: false)
      guard parts.count == 2, ["before", "after"].contains(parts[0]),
        let line = Int(parts[1]), line > 0
      else { throw SekkaError.message("--at must be before:LINE or after:LINE (positive line)") }
      let oldSide = parts[0] == "before"
      let snapshot = oldSide ? before : after
      let members = snapshot.types.flatMap(\.members).filter {
        $0.location.file == file && $0.body != nil
          && $0.location.line <= line && ($0.endLine ?? $0.location.line) >= line
      }
      let matches = report.coverage.bodyComparisons.filter {
        let location = oldSide ? $0.beforeLocation : $0.afterLocation
        return members.count == 1 && location == members[0].location
      }
      if members.count == 1, matches.count == 1,
        !["ambiguous-member-identity", "ambiguous-type-identity", "no-exact-member-match"].contains(matches[0].reason)
      {
        let match = matches[0]
        func range(_ snapshot: Snapshot, _ location: Location?) -> ClosedRange<Int>? {
          guard let location else { return nil }
          let candidates = snapshot.types.filter { $0.id == match.typeID }.flatMap(\.members)
            .filter { $0.location == location && $0.body != nil }
          guard candidates.count == 1, let end = candidates[0].endLine else { return nil }
          return location.line...end
        }
        let oldRange = range(before, match.beforeLocation)
        let newRange = range(after, match.afterLocation)
        if (match.beforeLocation == nil || oldRange != nil)
          && (match.afterLocation == nil || newRange != nil)
        {
          selected = hunks.filter { $0.overlaps(oldRange, before: true) || $0.overlaps(newRange, before: false) }
          scope = "Hunks overlapping declaration \(at); includes context and may include adjacent changes."
        } else {
          scope = "Declaration correspondence unavailable; showing all file hunks."
        }
      } else {
        scope = "Declaration correspondence unavailable; showing all file hunks."
      }
    }
    let quotedFile = String(data: try JSONEncoder().encode(file), encoding: .utf8)!
    return [
      "Sekka · source diff for \(quotedFile)",
      "Before: \(report.beforeLabel)", "After: \(report.afterLabel)", scope,
      "Hunk ranges: -before +after. Source text is not a correctness verdict.",
      selected.isEmpty ? "No textual hunk overlaps this selection." : selected.map(\.text).joined(separator: "\n"),
    ].joined(separator: "\n")
  }

  private struct Hunk {
    let oldStart: Int
    let oldCount: Int
    let newStart: Int
    let newCount: Int
    var text: String

    func overlaps(_ range: ClosedRange<Int>?, before: Bool) -> Bool {
      guard let range else { return false }
      let start = before ? oldStart : newStart
      let count = before ? oldCount : newCount
      return count > 0 && range.overlaps(start...(start + count - 1))
    }
  }

  private static func parseHunks(_ patch: String) -> [Hunk] {
    let pattern = try! NSRegularExpression(pattern: "^@@ -(\\d+)(?:,(\\d+))? \\+(\\d+)(?:,(\\d+))? @@")
    var hunks: [Hunk] = []
    for line in patch.components(separatedBy: "\n") {
      if let match = pattern.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
        func number(_ group: Int, default fallback: Int = 1) -> Int {
          guard let range = Range(match.range(at: group), in: line) else { return fallback }
          return Int(line[range])!
        }
        hunks.append(Hunk(oldStart: number(1), oldCount: number(2), newStart: number(3), newCount: number(4), text: line))
      } else if !hunks.isEmpty {
        hunks[hunks.count - 1].text += "\n" + line
      }
    }
    return hunks
  }

  private static func sourceDiff(_ before: String, _ after: String) throws -> String {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try Data(before.utf8).write(to: root.appendingPathComponent("before.swift"))
    try Data(after.utf8).write(to: root.appendingPathComponent("after.swift"))
    let errorURL = root.appendingPathComponent("stderr")
    FileManager.default.createFile(atPath: errorURL.path, contents: nil)
    let errors = try FileHandle(forWritingTo: errorURL)
    defer { try? errors.close() }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["git", "-c", "diff.algorithm=myers", "diff", "--no-index", "--no-ext-diff", "--no-textconv", "--no-color", "--text", "--unified=3", "--", "before.swift", "after.swift"]
    process.currentDirectoryURL = root
    let output = Pipe()
    process.standardOutput = output
    process.standardError = errors
    process.standardInput = FileHandle.nullDevice
    try process.run()
    let bytes = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard [0, 1].contains(process.terminationStatus) else {
      throw SekkaError.message("Cannot generate diff: " + (try String(contentsOf: errorURL, encoding: .utf8)))
    }
    return String(decoding: bytes, as: UTF8.self)
  }
}
