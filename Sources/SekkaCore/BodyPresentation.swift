import Foundation

/// Rendering only: the complete comparison records remain available in both JSON formats.
struct BodyPresentation {
  var summaries: [String] = []
  var individual: [BodyComparison] = []

  init(_ comparisons: [BodyComparison], findings: [Finding]) {
    let memberDelta = findings.first { $0.rule == "members-changed" }.map(displayDelta)
    let additionsOnly = memberDelta.map { $0.removed.isEmpty && !$0.added.isEmpty } ?? false
    let removalsOnly = memberDelta.map { $0.added.isEmpty && !$0.removed.isEmpty } ?? false
    var grouped: [String: [BodyComparison]] = [:]
    for body in comparisons where body.status != "changed-metrics" {
      let category: String?
      switch body.reason {
      case "type-added": category = "in added type"
      case "type-removed": category = "in removed type"
      case "no-exact-member-match" where additionsOnly && body.beforeLocation == nil:
        category = "with added declarations"
      case "no-exact-member-match" where removalsOnly && body.afterLocation == nil:
        category = "with removed declarations"
      default: category = nil
      }
      if body.status == "not-compared", let category {
        grouped[category, default: []].append(body)
      } else {
        individual.append(body)
      }
    }
    summaries = grouped.keys.sorted().map { category in
      let records = grouped[category]!
      let positions = records.sorted {
        ($0.afterLocation ?? $0.beforeLocation!).line < ($1.afterLocation ?? $1.beforeLocation!).line
      }.map { body in
        body.afterLocation.map { "after:\($0.line)" } ?? "before:\(body.beforeLocation!.line)"
      }
      let sample = positions.prefix(3).joined(separator: ", ")
      let omitted = positions.count > 3 ? "; +\(positions.count - 3) more" : ""
      return "\(records.count) bodies \(category); not compared. \(sample)\(omitted). Full locations: --format json → coverage.bodyComparisons."
    }
  }
}
