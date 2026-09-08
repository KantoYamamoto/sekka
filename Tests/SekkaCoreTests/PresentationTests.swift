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

@Test func commonConditionalNotesCollapseAndKeepJSONLocations() throws {
  let before = "#if DEBUG\nstruct A {}\n#endif\n"
  let report = try presentationReport(before, "// moved lines\n" + before)
  let text = Renderer.text(report)
  #expect(text.components(separatedBy: "All #if branches").count - 1 == 1)
  #expect(!text.contains("Unmatched conditional header"))
  #expect(report.notices.count == 2)
  #expect(report.notices.map(\.location.line) == [1, 2])
  #expect(try !Renderer.json(report).contains("conditionalHeader"))
  #expect(try !Renderer.json(report, detail: .full).contains("textNotices"))
}

@Test func changedConditionAndAmbiguousTypesRemainVisible() throws {
  let before = "#if DEBUG\nstruct A {}\n#endif\n"
  let report = try presentationReport(before, before.replacingOccurrences(of: "DEBUG", with: "RELEASE"))
  let text = Renderer.text(report)
  #expect(text.contains("after:1: Unmatched conditional header: #if RELEASE"))
  #expect(text.contains("before:1: Unmatched conditional header: #if DEBUG"))
  let duplicate = try presentationReport(
    before + before, before + before.replacingOccurrences(of: "struct A {}", with: "struct A { func f() {} }"))
  #expect(Renderer.text(duplicate).contains("Repeated declaration identity"))
  #expect(Renderer.text(duplicate).contains("Repeated type identity"))
}

@Test func reviewIndexDistinguishesBodyOnlyFileOnlyAndTrivia() throws {
  let old = [("Body.swift", "struct A { func f() { old() } }"),
    ("Top.swift", "func f() { old() }"), ("Comment.swift", "struct C {}")]
  let new = [("Body.swift", "struct A { func f() { new() } }"),
    ("Top.swift", "func f() { new() }"), ("Comment.swift", "// note\nstruct C {}")]
  let report = try Differ.compare(Analyzer.analyze(old), Analyzer.analyze(new), beforeLabel: "a", afterLabel: "b")
  let text = Renderer.text(report)
  #expect(text.contains("Body.swift [modified; 0 structural observations; 1 changed-syntax-only bodies]"))
  #expect(text.contains("Top.swift [modified; 0 structural observations; file diff only]"))
  #expect(text.contains("Comment.swift [modified; 0 structural observations; comments/formatting only]"))
  #expect(!text.contains("Changed files without structural observations"))
  #expect(text.components(separatedBy: "tracked structural counts did not").count - 1 == 1)
}

@Test func lifecycleSummaryKeepsBoundedSourcePositionsInLineOrder() throws {
  let members = (0..<12).map { "func f\($0)() {}" }.joined(separator: "\n")
  let report = try presentationReport("struct A {}", "struct A {\n" + members + "\n}")
  let text = Renderer.text(report)
  #expect(text.contains("after:2, after:3, after:4; +9 more"))
  #expect(report.coverage.bodyComparisons.count == 12)
  let removed = try presentationReport("struct A {\n" + members + "\n}", "struct A {}")
  #expect(Renderer.text(removed).contains("before:2, before:3, before:4; +9 more"))
}
