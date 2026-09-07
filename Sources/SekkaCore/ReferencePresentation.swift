import Foundation

/// Factor repeated owners without inferring correspondence between declarations.
enum ReferencePresentation {
  private struct Site: Hashable {
    let member: String
    let role: String
    let spelling: String

    init(_ reference: Reference) {
      member = reference.member
      role = reference.role
      spelling = reference.spelling
    }

    var detail: String { "[\(role)] → \(spelling)" }
  }

  static func lines(before: [Reference], after: [Reference]) -> [String] {
    let old = Set(before.map(Site.init))
    let new = Set(after.map(Site.init))
    return render(old.subtracting(new), sign: "-") + render(new.subtracting(old), sign: "+")
  }

  // Only context already present in both sides of this exact finding; no symbol lookup.
  static func retainedExpressions(_ finding: Finding) -> [String] {
    guard finding.rule == "type-references-changed" else { return [] }
    return Set(finding.before).intersection(finding.after).sorted()
  }

  static let contextLimit = 5

  static func contextLines(_ finding: Finding) -> [String] {
    let retained = retainedExpressions(finding)
    guard !retained.isEmpty else { return [] }
    var lines = ["    unchanged explicit type expressions (context, not resolved dependencies):"]
    lines += retained.prefix(contextLimit).map { "      = \($0)" }
    if retained.count > contextLimit {
      lines.append(
        "      … \(retained.count - contextLimit) more; --format json --json-detail full")
    }
    return lines
  }

  private static func render(_ sites: Set<Site>, sign: String) -> [String] {
    let groups = Dictionary(grouping: sites, by: \.member)
    return groups.keys.sorted().flatMap { member in
      let details = groups[member]!.map(\.detail).sorted()
      if details.count == 1 {
        return ["    \(sign) \(member) \(details[0])"]
      }
      return ["    \(sign) \(member):"] + details.map { "      \($0)" }
    }
  }
}
