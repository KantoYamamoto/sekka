import Foundation

enum NoticePresentation {
  static func lines(before: [Notice], after: [Notice]) -> [String] {
    let old = before.filter { $0.conditionalHeader != nil }
    let new = after.filter { $0.conditionalHeader != nil }
    var lines: [String] = []
    if !old.isEmpty || !new.isEmpty {
      lines.append(
        "NOTE All #if branches are included, regardless of build configuration. Blocks: \(old.count) → \(new.count). Positions before/after: --format json --json-detail full → notices."
      )
      // Match a multiset of headers per file, ignoring line shifts and body changes.
      // An unmatched header is not proof that a whole block was added/deleted.
      func key(_ notice: Notice) -> Data {
        Data((notice.location.file + "\0" + notice.conditionalHeader!).utf8)
      }
      var remaining = Dictionary(grouping: old, by: key).mapValues(\.count)
      for notice in new {
        let id = key(notice)
        if remaining[id, default: 0] > 0 {
          remaining[id]! -= 1
        } else {
          lines.append(headerLine(notice, side: "after"))
        }
      }
      for notice in old where remaining[key(notice), default: 0] > 0 {
        remaining[key(notice)]! -= 1
        lines.append(headerLine(notice, side: "before"))
      }
    }
    for (side, notices) in [("before", before), ("after", after)] {
      lines += notices.filter { $0.conditionalHeader == nil }.map {
        "NOTE \($0.location.file):\(side):\($0.location.line): \($0.message)"
      }
    }
    return lines
  }

  private static func headerLine(_ notice: Notice, side: String) -> String {
    "NOTE \(notice.location.file):\(side):\(notice.location.line): Unmatched conditional header: \(notice.conditionalHeader!). Added/removed/changed header; block identity is not inferred."
  }
}
