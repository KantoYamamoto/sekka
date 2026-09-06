import Foundation

/// Rendering only: the complete comparison records remain available in both JSON formats.
struct BodyPresentation {
  var summaries: [String] = []
  var individual: [BodyComparison] = []

  init(_ comparisons: [BodyComparison], findings: [Finding]) {
    let memberDelta = findings.first { $0.rule == "members-changed" }.map(displayDelta)
    let additionsOnly = memberDelta.map { $0.removed.isEmpty && !$0.added.isEmpty } ?? false
    let removalsOnly = memberDelta.map { $0.added.isEmpty && !$0.removed.isEmpty } ?? false
    var grouped: [String: Int] = [:]
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
        grouped[category, default: 0] += 1
      } else {
        individual.append(body)
      }
    }
    summaries = grouped.keys.sorted().map {
      "\(grouped[$0]!) bodies \($0); not compared. Declarations above; details: --format json → coverage.bodyComparisons."
    }
  }
}
