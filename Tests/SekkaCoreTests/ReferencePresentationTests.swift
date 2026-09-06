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
  #expect(ReferencePresentation.lines(before: before, after: before.map {
    Reference(spelling: $0.spelling, role: $0.role, member: $0.member, line: 100)
  }).isEmpty)
}

@Test func groupedReferenceTextKeepsSerializedFactsAndDecodedFallback() throws {
  let before = try Analyzer.analyze([("App.swift", "struct A { func run(x: Int, s: String) -> Int { x } }")])
  let after = try Analyzer.analyze([("App.swift", "struct A { func run(y: Int, s: String) -> Int { y } }")])
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
