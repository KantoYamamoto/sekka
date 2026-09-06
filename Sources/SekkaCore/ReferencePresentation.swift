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
