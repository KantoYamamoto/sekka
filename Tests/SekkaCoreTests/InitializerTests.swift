import Foundation
import Testing

@testable import SekkaCore

private func initializerDelta(_ before: String, _ after: String) throws -> DiffReport {
  Differ.compare(
    try Analyzer.analyze([("App.swift", before)]),
    try Analyzer.analyze([("App.swift", after)]), beforeLabel: "before", afterLabel: "after")
}

@Test func initializerChangeSurvivesOtherObservations() throws {
  let report = try initializerDelta(
    "struct A { static let limit = 3 }",
    "struct A {\n static let limit = 8\n func reset() {}\n}")
  let finding = try #require(report.findings.first { $0.rule == "property-initializer-changed" })
  #expect(finding.location.line == 2)
  #expect(finding.message.contains("property limit: initializer syntax changed"))
  #expect(report.findings.contains { $0.rule == "members-changed" })
  #expect(report.coverage.changedFiles.first?.observationCount == report.findings.count)
  #expect(try Renderer.json(report).contains("property-initializer-changed"))
  #expect(
    Renderer.text(report).contains(
      "property limit: initializer syntax changed; behavior/effects unknown (after:2)"))
}

@Test func initializerPresenceAndMultipleBindings() throws {
  for (before, after, expected) in [
    ("var x: Int", "var x: Int = 1", "added"),
    ("var x: Int = 1", "var x: Int", "removed"),
  ] {
    let report = try initializerDelta("struct A { \(before) }", "struct A { \(after) }")
    #expect(report.findings.contains { $0.message.contains("initializer syntax \(expected)") })
  }
  let report = try initializerDelta(
    "struct A { var x = 1, y = 2 }", "struct A { var x = 1, y = 3 }")
  #expect(report.findings.count == 1)
  #expect(report.findings[0].message.contains("property y:"))
}

@Test func initializerUsesExactTokensWithoutTrivia() throws {
  let unchanged = try initializerDelta(
    "struct A { let x = f(1) }", "struct A { let x = f( /* note */ 1 ) }")
  #expect(unchanged.findings.isEmpty)
  let unicode = try initializerDelta(
    "struct A { let x = \"é\" }", "struct A { let x = \"e\u{301}\" }")
  #expect(unicode.findings.count == 1)
  #expect(unicode.findings[0].rule == "property-initializer-changed")
  let closure = try initializerDelta("struct A { let x = { 1 }() }", "struct A { let x = { 2 }() }")
  #expect(closure.findings.count == 1)
}

@Test func initializerDoesNotGuessAmbiguousOrRenamedDeclarations() throws {
  for (before, after) in [
    ("struct A { let x = 1; let x = 2 }", "struct A { let x = 3; let x = 2 }"),
    ("struct A { let x = 1 }; struct A {}", "struct A { let x = 2 }; struct A {}"),
    ("struct A { let x = 1 }", "struct A { let y = 2 }"),
    ("", "struct A { let x = 1 }"),
    ("struct A { let x = 1 }", ""),
  ] {
    let report = try initializerDelta(before, after)
    #expect(!report.findings.contains { $0.rule == "property-initializer-changed" })
  }
}

@Test func initializerDoesNotBecomeAccessorOrLocalBody() throws {
  let report = try initializerDelta(
    "struct A { var x = 1 { didSet {} }; func f() { let local = 1 } }",
    "struct A { var x = 2 { didSet {} }; func f() { let local = 2 } }")
  #expect(report.findings.filter { $0.rule == "property-initializer-changed" }.count == 1)
  #expect(!report.findings.contains { $0.message.contains("property local") })
  let snapshot = try Analyzer.analyze([("App.swift", "struct A { let x = 3 }")])
  #expect(!((try Renderer.json(snapshot)).contains("initializerTokens")))
}

@Test func initializerLocationReachesMultilineExpression() throws {
  let padding = String(repeating: "    0,\n", count: 15)
  let before = "struct A {\n  let values = [\n\(padding)    3\n  ]\n}"
  let after = before.replacingOccurrences(of: "    3", with: "    8")
  let a = try Analyzer.analyze([("App.swift", before)])
  let b = try Analyzer.analyze([("App.swift", after)])
  let report = Differ.compare(a, b, beforeLabel: "before", afterLabel: "after")
  let finding = try #require(report.findings.first { $0.rule == "property-initializer-changed" })
  let selected = try DiffNavigation.render(
    before: a, after: b, report: report,
    file: finding.location.file, at: "after:\(finding.location.line)")
  #expect(selected.contains("+    8"))
}
