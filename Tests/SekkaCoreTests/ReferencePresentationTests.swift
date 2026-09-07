import Foundation
import Testing

@testable import SekkaCore

@Test func referenceGroupsPreserveOwnersRolesAndBothSides() {
  let owner = "func run(_ value: Int, text: String = \" [parameter-type] → \" )"
  let overload = "func run(_ value: Double)"
  let before = [
    Reference(spelling: "Int", role: "parameter-type", member: owner, line: 1),
    Reference(spelling: "String", role: "return-type", member: owner, line: 1),
    Reference(spelling: "Double", role: "parameter-type", member: overload, line: 2),
  ]
  let after = before.map {
    Reference(spelling: $0.spelling, role: $0.role, member: $0.member + " async", line: 30)
  }
  let lines = ReferencePresentation.lines(before: before, after: after)
  #expect(lines.contains("    - \(owner):"))
  #expect(lines.contains("    + \(owner) async:"))
  #expect(lines.filter { $0 == "      [parameter-type] → Int" }.count == 2)
  #expect(lines.filter { $0 == "      [return-type] → String" }.count == 2)
  #expect(lines.contains("    - \(overload) [parameter-type] → Double"))
  #expect(lines.count == 8)
  #expect(
    ReferencePresentation.lines(
      before: before,
      after: before.map {
        Reference(spelling: $0.spelling, role: $0.role, member: $0.member, line: 100)
      }
    ).isEmpty)
}

@Test func groupedReferenceTextKeepsSerializedFactsAndDecodedFallback() throws {
  let before = try Analyzer.analyze([
    ("App.swift", "struct A { func run(x: Int, s: String) -> Int { x } }")
  ])
  let after = try Analyzer.analyze([
    ("App.swift", "struct A { func run(y: Int, s: String) -> Int { y } }")
  ])
  let report = Differ.compare(before, after, beforeLabel: "before", afterLabel: "after")
  let finding = try #require(report.findings.first { $0.rule == "reference-sites-changed" })
  #expect(finding.textReferenceLines != nil)
  #expect(Renderer.text(report).contains("      [return-type] → Int"))
  let encoded = try Renderer.json(finding)
  #expect(!encoded.contains("textReferenceLines"))
  let decoded = try JSONDecoder().decode(Finding.self, from: Data(encoded.utf8))
  #expect(decoded.before == finding.before)
  #expect(decoded.after == finding.after)
  #expect(decoded.textReferenceLines == nil)
}

@Test func retainedTypeContextUsesOnlySharedExplicitExpressions() throws {
  let before = try Analyzer.analyze([("Checkout.swift", "struct Checkout { let logger: Logger }")])
  let after = try Analyzer.analyze([
    ("Checkout.swift", "struct Checkout { let logger: Logger; let analytics: Analytics }")
  ])
  let report = Differ.compare(before, after, beforeLabel: "before", afterLabel: "after")
  let finding = try #require(report.findings.first { $0.rule == "type-references-changed" })
  #expect(ReferencePresentation.retainedExpressions(finding) == ["Logger"])
  #expect(Renderer.text(report).contains("      = Logger"))
  #expect(Renderer.text(report).contains("+ Analytics"))
  let compact =
    try JSONSerialization.jsonObject(with: Data(Renderer.json(report).utf8)) as! [String: Any]
  let findings = compact["findings"] as! [[String: Any]]
  #expect(
    findings.first { $0["rule"] as? String == "type-references-changed" }?[
      "unchangedTypeExpressions"] as? [String] == ["Logger"])
  #expect(
    findings.first { $0["rule"] as? String == "members-changed" }?["unchangedTypeExpressions"]
      == nil)
  #expect(report.findings.count == 2)
}

@Test func retainedContextIsBoundedAndFullFactsRemainAvailable() throws {
  let old = (0..<8).map { "Type\($0)" }
  let finding = Finding(
    rule: "type-references-changed", type: "A", location: Location(file: "A.swift", line: 1),
    message: "changed", before: old.reversed(), after: old + ["New"])
  let lines = ReferencePresentation.contextLines(finding)
  #expect(lines.filter { $0.hasPrefix("      = ") }.count == 5)
  #expect(lines.last?.contains("3 more") == true)
  #expect(ReferencePresentation.retainedExpressions(finding) == old)
  let report = DiffReport(
    beforeLabel: "before", afterLabel: "after", beforeFiles: 1, afterFiles: 1, findings: [finding],
    notices: [], limitations: [])
  let data =
    try JSONSerialization.jsonObject(with: Data(Renderer.json(report).utf8)) as! [String: Any]
  let row = (data["findings"] as! [[String: Any]])[0]
  #expect(row["omittedUnchangedTypeExpressionCount"] as? Int == 3)
  #expect(row["unchangedTypeExpressions"] as? [String] == Array(old.prefix(5)))
  #expect(try Renderer.json(report, detail: .full).contains("Type7"))
  #expect(try Renderer.json(report) == Renderer.json(report))
}

@Test func contextDoesNotInventCommonOrCrossTypeRelations() {
  let location = Location(file: "A.swift", line: 1)
  let unrelated = Finding(
    rule: "members-changed", type: "A", location: location, message: "changed", before: ["Logger"],
    after: ["Logger", "Analytics"])
  let disjoint = Finding(
    rule: "type-references-changed", type: "A", location: location, message: "changed",
    before: ["Logger"], after: ["Analytics"])
  #expect(ReferencePresentation.contextLines(unrelated).isEmpty)
  #expect(ReferencePresentation.contextLines(disjoint).isEmpty)
}
