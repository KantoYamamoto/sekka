import Foundation
import Testing

@testable import PatchworkCore

private func compare(_ before: String, _ after: String) throws -> DiffReport {
  try Differ.compare(
    Analyzer.analyze([("App.swift", before)]), Analyzer.analyze([("App.swift", after)]),
    beforeLabel: "before", afterLabel: "after")
}

private func object(_ text: String) throws -> [String: Any] {
  try #require(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
}

@Test func callOnlyChangesAreVisibleWithoutInventingStructuralFindings() throws {
  let report = try compare(
    "struct View { func show() { service.send() } }",
    "struct View { func show() { service.send(mode: mode) } }")
  #expect(report.findings.isEmpty)
  #expect(report.coverage.changedFiles.count == 1)
  #expect(report.coverage.changedFiles[0].observationCount == 0)
  #expect(report.coverage.bodyComparisons[0].status == "changed-syntax-only")
  #expect(report.coverage.comparedBodyCount == 1)
  #expect(Renderer.text(report).contains("Changed files without structural observations"))
  #expect(Renderer.github(report).contains("Body tokens changed"))
}

@Test func triviaOnlyChangeIsNotABodyChange() throws {
  let report = try compare(
    "struct A { func f() { return 1 } }",
    "// comment\nstruct A { func f() {\n /* hi */ return 1\n } }")
  #expect(report.findings.isEmpty)
  #expect(report.coverage.changedFiles.count == 1)
  #expect(!report.coverage.changedFiles[0].syntaxChanged)
  #expect(report.coverage.unchangedBodyCount == 1)
  #expect(report.coverage.bodyComparisons.isEmpty)
}

@Test func parameterChangeSummarizedButBodyNotCompared() throws {
  let report = try compare(
    "struct Service { func run(value: Int) { old() } }",
    "struct Service { func run(value: Int, mode: Mode = .default) { new() } }")
  let change = try #require(report.findings.flatMap(\.parameterChanges).first)
  #expect(change.member == "func run")
  #expect(change.added == ["mode : Mode = . default"])
  #expect(change.removed.isEmpty)
  #expect(report.coverage.comparedBodyCount == 0)
  #expect(report.coverage.skippedBodyCount == 1)
  #expect(report.coverage.bodyComparisons[0].reason == "parameter-clause-changed")
  #expect(report.coverage.bodyComparisons[0].beforeLocation != nil)
  #expect(report.coverage.bodyComparisons[0].afterLocation != nil)
}

@Test func regressionExperimentAlwaysExposesSkippedComparison() throws {
  let before = "struct S { func recommend() { question.resolvedFormat } }"
  for expression in ["question.format(mode: mode)", "question.resolvedFormat"] {
    let report = try compare(before, "struct S { func recommend(mode: Mode) { \(expression) } }")
    #expect(
      report.coverage.bodyComparisons.contains {
        $0.status == "not-compared" && $0.reason == "parameter-clause-changed"
      })
    #expect(Renderer.text(report).contains("Body comparison was skipped"))
  }
}

@Test func sameCountLiteralOrOperatorChangeIsNotHidden() throws {
  let report = try compare(
    "struct S { func f(_ x: Int) -> Int { x + 1 } }",
    "struct S { func f(_ x: Int) -> Int { x - 2 } }")
  #expect(report.findings.isEmpty)
  #expect(report.coverage.bodyComparisons[0].status == "changed-syntax-only")
}

@Test func unicodeSpellingChangesAreNotLabelledAsTrivia() throws {
  let report = try compare(
    "struct A { func f() { \"\u{e9}\" } }", "struct A { func f() { \"e\u{301}\" } }")
  #expect(report.coverage.changedFiles[0].syntaxChanged)
  #expect(report.coverage.bodyComparisons[0].status == "changed-syntax-only")
}

@Test func overloadsAreNotMatchedByNameForParameterSummaries() throws {
  let report = try compare(
    "struct S { func f(_ x: Int) {} ; func f(_ x: String) {} }",
    "struct S { func f(_ x: Int, mode: Mode) {}; func f(_ x: String) {} }")
  #expect(report.findings.flatMap(\.parameterChanges).isEmpty)
  #expect(report.coverage.comparedBodyCount == 1)
  #expect(report.coverage.skippedBodyCount == 2)
  #expect(report.coverage.bodyComparisons.allSatisfy { $0.reason == "no-exact-member-match" })
}

@Test func repeatedTypesNeverClaimBodyComparison() throws {
  let before = "struct A { func f() {} }; struct A { func f() {} }"
  let after = "struct A { func f() { if flag {} } }; struct A { func f() {} }"
  let report = try compare(before, after)
  #expect(report.coverage.comparedBodyCount == 0)
  #expect(report.coverage.skippedBodyCount == 4)
  #expect(report.coverage.bodyComparisons.allSatisfy { $0.reason == "ambiguous-type-identity" })
  #expect(!report.findings.contains { $0.rule == "body-structure-changed" })
}

@Test func unsupportedBodiesRemainUnobservedChangedFiles() throws {
  let report = try compare("func topLevel() { a() }", "func topLevel() { b() }")
  #expect(report.findings.isEmpty)
  #expect(report.coverage.changedFiles[0].syntaxChanged)
  #expect(report.coverage.comparedBodyCount == 0)
  #expect(report.coverage.bodyComparisons.isEmpty)
}

@Test func addedAndRemovedBodiesHaveExplicitReasons() throws {
  let report = try compare("struct Old { func f() {} }", "struct New { func f() {} }")
  #expect(report.coverage.skippedBodyCount == 2)
  #expect(Set(report.coverage.bodyComparisons.map(\.reason)) == ["type-added", "type-removed"])
}

@Test func compactJSONOmitsUnchangedDeclarationsButKeepsCoverage() throws {
  let report = try compare(
    "struct A { let untouched: Int; func run(value: Int) {} }",
    "struct A { let untouched: Int; func run(value: Int, mode: Bool) {} }")
  let compactText = try Renderer.json(report)
  let fullText = try Renderer.json(report, detail: .full)
  let compact = try object(compactText)
  let full = try object(fullText)
  #expect(compact["detail"] as? String == "compact")
  #expect(full["detail"] as? String == "full")
  #expect(compact["schemaVersion"] as? Int == 2)
  #expect(!compactText.contains("untouched"))
  #expect(fullText.contains("untouched"))
  #expect(compact["coverage"] as? NSDictionary == full["coverage"] as? NSDictionary)
  #expect(compact["limitations"] as? [String] == full["limitations"] as? [String])
  let findings = try #require(compact["findings"] as? [[String: Any]])
  #expect(findings.allSatisfy { $0["before"] == nil && $0["after"] == nil })
  #expect(findings.allSatisfy { $0["added"] != nil && $0["removed"] != nil })
}

@Test func textGroupsRelatedFactsUnderOneTypeHeading() throws {
  let report = try compare(
    "struct A { let x: Int; func f() {} }",
    "struct A { let x: Int; let y: Bool; func f() { if flag {} } }")
  let text = Renderer.text(report)
  #expect(text.components(separatedBy: "  A\n").count == 2)
  #expect(text.contains("[members-changed]"))
  #expect(text.contains("[body-structure-changed]"))
}

@Test func reorderedParametersAreNotSilentlyDropped() throws {
  let report = try compare(
    "struct A { func f(a: Int, b: Int) {} }", "struct A { func f(b: Int, a: Int) {} }")
  #expect(Renderer.text(report).contains("order before:"))
  let text = try Renderer.json(report)
  #expect(text.contains("beforeOrder"))
}

@Test func parameterSummaryPreservesOtherDeclarationChanges() throws {
  let report = try compare(
    "struct S { private func f(x: Int) -> Int { x } }",
    "struct S { func f(x: Int, y: Int) -> String { text } }")
  let text = Renderer.text(report)
  #expect(text.contains("+ y : Int"))
  #expect(text.contains("declaration before: private func f ( ) -> Int"))
  #expect(text.contains("declaration after: func f ( ) -> String"))
  #expect(try Renderer.json(report).contains("declarationBefore"))
  #expect(Renderer.github(report).contains("private func f"))
  #expect(report.coverage.bodyComparisons[0].status == "not-compared")
}

@Test func fileCoverageIncludesDeletionAndUnobservedAddition() throws {
  let old = try Analyzer.analyze([("Gone.swift", "struct A {}"), ("Same.swift", "struct Same {}")])
  let new = try Analyzer.analyze([
    ("OnlyCalls.swift", "do { call() }"), ("Same.swift", "struct Same {}"),
  ])
  let report = Differ.compare(old, new, beforeLabel: "old", afterLabel: "new")
  #expect(report.coverage.changedFiles.map(\.file) == ["Gone.swift", "OnlyCalls.swift"])
  #expect(report.coverage.changedFiles.map(\.change) == ["deleted", "added"])
  #expect(report.coverage.changedFiles[1].observationCount == 0)
}

@Test func fullAndCompactDiffOrderIsDeterministic() throws {
  let before = [("B.swift", "struct B { func f() {} }"), ("A.swift", "struct A {}")]
  let after = [
    ("B.swift", "struct B { func f() { x() } }"), ("A.swift", "struct A { let x: Int }"),
  ]
  let one = try Differ.compare(
    Analyzer.analyze(before), Analyzer.analyze(after), beforeLabel: "old", afterLabel: "new")
  let two = try Differ.compare(
    Analyzer.analyze(before.reversed()), Analyzer.analyze(after.reversed()), beforeLabel: "old",
    afterLabel: "new")
  #expect(try Renderer.json(one) == Renderer.json(two))
  #expect(try Renderer.json(one, detail: .full) == Renderer.json(two, detail: .full))
}
