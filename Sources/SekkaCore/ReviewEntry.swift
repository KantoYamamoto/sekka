import Foundation

/// A reading index derived from existing facts, not a risk ranking or another JSON payload.
struct ReviewEntry {
  let change: InputChange
  let swift: ChangedFile?
  let bodies: [BodyComparison]

  var summary: String {
    guard let swift else { return change.analysis }
    let syntaxOnly = bodies.filter { $0.status == "changed-syntax-only" }.count
    let skipped = bodies.filter { $0.status == "not-compared" }.count
    var parts = ["\(swift.observationCount) structural observations"]
    if syntaxOnly > 0 { parts.append("\(syntaxOnly) changed-syntax-only bodies") }
    if skipped > 0 { parts.append("\(skipped) not-compared bodies") }
    if !swift.syntaxChanged { parts.append("comments/formatting only") }
    else if swift.observationCount == 0 && bodies.isEmpty { parts.append("file diff only") }
    return parts.joined(separator: "; ")
  }

  static func textLines(_ report: DiffReport) -> [String] {
    let files = Dictionary(uniqueKeysWithValues: report.coverage.changedFiles.map { ($0.file, $0) })
    let inventory = report.inventory ?? ComparisonInventory(
      scope: "analyzed Swift sources only (no whole-input inventory)",
      changes: report.coverage.changedFiles.map { InputChange(file: $0.file, change: $0.change, analysis: "swift") })
    let bodies = Dictionary(grouping: report.coverage.bodyComparisons, by: {
      ($0.afterLocation ?? $0.beforeLocation!).file
    })
    let changes = inventory.changes.sorted {
      if (files[$0.file] != nil) != (files[$1.file] != nil) { return files[$0.file] != nil }
      return $0.file < $1.file
    }
    let analyzed = changes.filter { $0.analysis == "swift" }.count
    var lines = ["Comparison scope: \(inventory.scope)",
      "Changed paths: \(changes.count) · Swift candidates: \(analyzed) · outside Swift analysis: \(changes.count - analyzed)",
      "Review index (Swift changes first; counts are not review coverage):"]
    if !changes.isEmpty && analyzed == 0 {
      lines.append("Changes exist, but none are analyzed as Swift. Review the ordinary diff.")
    }
    for change in changes.prefix(20) {
      let path = change.file.contains(where: { $0.isNewline || $0 == "\t" }) ? String(reflecting: change.file) : change.file
      let entry = ReviewEntry(change: change, swift: files[change.file], bodies: bodies[change.file] ?? [])
      lines.append("  \(path) [\(change.change); \(entry.summary)]")
    }
    if changes.count > 20 {
      let field = report.inventory == nil ? "coverage.changedFiles" : "inventory.changes"
      lines.append("  … \(changes.count - 20) more paths; complete list: --format json → \(field)")
    }
    return lines + [""]
  }
}
