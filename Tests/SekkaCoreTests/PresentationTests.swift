import Foundation
import Testing

@testable import SekkaCore

private func presentationReport(_ before: String, _ after: String) throws -> DiffReport {
  try Differ.compare(
    Analyzer.analyze([("App.swift", before)]), Analyzer.analyze([("App.swift", after)]),
    beforeLabel: "before", afterLabel: "after")
}

@Test func typeLifecycleCollapsesReasonsWithoutLosingRecords() throws {
  let members = (0..<20).map { "func test\($0)() { work() }" }.joined(separator: "\n")
  let report = try presentationReport("struct Old { \(members) }", "struct New { \(members) }")
  let text = Renderer.text(report)
  #expect(text.components(separatedBy: "[not-compared]").count - 1 == 2)
  #expect(text.contains("20 bodies in removed type"))
  #expect(text.contains("20 bodies in added type"))
  #expect(report.coverage.bodyComparisons.count == 40)
  #expect(report.coverage.skippedBodyCount == 40)
  #expect(text.components(separatedBy: "func test0").count - 1 == 2)
}

@Test func onlyAddedMembersCollapseButRenamedMembersRemainIndividual() throws {
  let additions = try presentationReport(
    "struct Suite { func existing() {} }",
    "struct Suite { func existing() {}; func testA() {}; func testB() {} }")
  #expect(Renderer.text(additions).contains("2 bodies with added declarations"))
  let rename = try presentationReport(
    "struct Suite { func old() {} }", "struct Suite { func new() {} }")
  #expect(Renderer.text(rename).components(separatedBy: "No exact counterpart").count - 1 == 2)
  #expect(!Renderer.text(rename).contains("bodies with added"))
}

@Test func ambiguousAndParameterChangesDoNotCollapse() throws {
  let report = try presentationReport(
    "struct Suite { func run(_ x: Int) {}; func run(_ x: String) {} }",
    "struct Suite { func run(_ x: Int, mode: Bool) {}; func run(_ x: String) {} }")
  #expect(Renderer.text(report).components(separatedBy: "No exact counterpart").count - 1 == 2)
  let repeated = try presentationReport(
    "struct A { func f() {} }; struct A { func f() {} }",
    "struct A { func f() { change() } }; struct A { func f() {} }")
  #expect(Renderer.text(repeated).components(separatedBy: "Repeated type identity").count - 1 == 4)
}
