import Foundation

public enum JSONDetail: String, Sendable { case compact, full }

func parameterOrderChanged(_ change: ParameterChange) -> Bool {
  let oldRetained = changedElements(change.removed, change.beforeOrder).added
  let newRetained = changedElements(change.added, change.afterOrder).added
  return oldRetained != newRetained
}

func displayDelta(_ finding: Finding) -> (removed: [String], added: [String]) {
  var delta = changedElements(finding.before, finding.after)
  for parameter in finding.parameterChanges {
    if let index = delta.removed.firstIndex(of: parameter.beforeSignature) {
      delta.removed.remove(at: index)
    }
    if let index = delta.added.firstIndex(of: parameter.afterSignature) {
      delta.added.remove(at: index)
    }
  }
  return delta
}

func coverageExplanation(_ reason: String) -> String {
  switch reason {
  case "parameter-clause-changed":
    return
      "Parameter clause changed on unique same-name declarations. Body comparison was skipped; review both bodies."
  case "no-exact-member-match":
    return
      "No exact counterpart: declaration added/removed, renamed, or signature changed. Body not compared."
  case "ambiguous-member-identity":
    return "Multiple declarations have this member key. No body pairing was chosen."
  case "ambiguous-type-identity":
    return "Repeated type identity (e.g. #if branches/extensions). No body pairing was chosen."
  case "type-added": return "Type added; no previous body to compare."
  case "type-removed": return "Type removed; no current body to compare."
  case "body-added": return "No previous body (e.g. a requirement gained a body)."
  case "body-removed": return "No current body to compare."
  case "tracked-counts-unchanged":
    return "Body tokens changed but tracked structural counts did not. Inspect the ordinary diff."
  default: return "Tracked structural counts changed. Behavior was not checked."
  }
}

extension Renderer {
  public static func json(_ report: DiffReport, detail: JSONDetail = .compact) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try detail == .full ? encoder.encode(report) : encoder.encode(CompactReport(report))
    return String(decoding: data, as: UTF8.self)
  }
}

private struct CompactParameterChange: Encodable {
  let member: String
  let removed: [String]
  let added: [String]
  let beforeOrder: [String]?
  let afterOrder: [String]?
  let declarationBefore: String?
  let declarationAfter: String?
  init(_ change: ParameterChange) {
    member = change.member
    removed = change.removed
    added = change.added
    beforeOrder = parameterOrderChanged(change) ? change.beforeOrder : nil
    afterOrder = parameterOrderChanged(change) ? change.afterOrder : nil
    declarationBefore = change.beforeHeader == change.afterHeader ? nil : change.beforeHeader
    declarationAfter = change.beforeHeader == change.afterHeader ? nil : change.afterHeader
  }
}

private struct CompactFinding: Encodable {
  let rule: String
  let typeID: String
  let type: String
  let location: Location
  let message: String
  let removed: [String]
  let added: [String]
  let parameterChanges: [CompactParameterChange]?
  init(_ finding: Finding) {
    rule = finding.rule
    typeID = finding.typeID
    type = finding.type
    location = finding.location
    message = finding.message
    let delta = displayDelta(finding)
    removed = delta.removed
    added = delta.added
    parameterChanges =
      finding.parameterChanges.isEmpty
      ? nil : finding.parameterChanges.map(CompactParameterChange.init)
  }
}

private struct CompactReport: Encodable {
  let schemaVersion = 2
  let analysis = "syntax-only"
  let detail = "compact"
  let beforeLabel: String
  let afterLabel: String
  let beforeFiles: Int
  let afterFiles: Int
  let findings: [CompactFinding]
  let coverage: ComparisonCoverage
  let notices: [Notice]
  let limitations: [String]
  init(_ report: DiffReport) {
    beforeLabel = report.beforeLabel
    afterLabel = report.afterLabel
    beforeFiles = report.beforeFiles
    afterFiles = report.afterFiles
    findings = report.findings.map(CompactFinding.init)
    coverage = report.coverage
    notices = report.notices
    limitations = report.limitations
  }
}
