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
      if let ranges = declarationRanges(
        before: before, after: after, report: report, file: file,
        line: line, oldSide: parts[0] == "before")
      {
        selected = hunks.filter { $0.overlaps(ranges.before, before: true) || $0.overlaps(ranges.after, before: false) }
        scope = "Hunks overlapping declaration \(at); includes context and may include adjacent changes."
        scope += " Selected \(selected.count) of \(hunks.count) file hunks."
        if !selected.isEmpty && selected.count == hunks.count {
          scope += " All file hunks overlap this selection; hunks are not clipped to declaration boundaries."
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

  private struct DeclarationRanges {
    let before: ClosedRange<Int>?
    let after: ClosedRange<Int>?
  }

  private static func declarationRanges(
    before: Snapshot, after: Snapshot, report: DiffReport, file: String,
    line: Int, oldSide: Bool
  ) -> DeclarationRanges? {
    let snapshot = oldSide ? before : after
    let candidates = snapshot.types.flatMap { type in
      type.members.filter {
        $0.location.file == file && ($0.body != nil || $0.kind == "property")
          && $0.location.line <= line && ($0.endLine ?? $0.location.line) >= line
      }.map { (type, $0) }
    }
    guard candidates.count == 1 else { return nil }
    let (type, member) = candidates[0]
    func family(_ snapshot: Snapshot) -> [TypeRecord] {
      snapshot.types.filter { $0.location.file == file && $0.kind == type.kind && $0.name == type.name }
    }
    let oldTypes = family(before)
    let newTypes = family(after)
    guard oldTypes.count <= 1, newTypes.count <= 1 else { return nil }
    func range(_ member: Member?) -> ClosedRange<Int>? {
      guard let member, let end = member.endLine else { return nil }
      return member.location.line...end
    }
    if member.kind == "property" {
      // Initializers are not accessor bodies. Select their stored binding ranges directly.
      let old = oldTypes.first?.members.filter { $0.key == member.key } ?? []
      let new = newTypes.first?.members.filter { $0.key == member.key } ?? []
      guard old.count <= 1, new.count <= 1,
        old.first == nil || range(old.first) != nil,
        new.first == nil || range(new.first) != nil else { return nil }
      return DeclarationRanges(before: range(old.first), after: range(new.first))
    }
    let matches = report.coverage.bodyComparisons.filter {
      $0.typeID == type.id && (oldSide ? $0.beforeLocation : $0.afterLocation) == member.location
    }
    guard matches.count == 1,
      !["ambiguous-member-identity", "ambiguous-type-identity"].contains(matches[0].reason)
    else { return nil }
    let match = matches[0]
    // A missing counterpart prevents comparison, but not navigation on the known side.
    func bodyRange(_ types: [TypeRecord], _ location: Location?) -> ClosedRange<Int>? {
      guard let location else { return nil }
      let members = types.flatMap(\.members).filter { $0.location == location && $0.body != nil }
      return members.count == 1 ? range(members[0]) : nil
    }
    let old = bodyRange(oldTypes, match.beforeLocation)
    let new = bodyRange(newTypes, match.afterLocation)
    guard (match.beforeLocation == nil || old != nil), (match.afterLocation == nil || new != nil) else { return nil }
    return DeclarationRanges(before: old, after: new)
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
