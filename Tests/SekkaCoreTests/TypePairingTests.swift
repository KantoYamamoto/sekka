import Testing

@testable import SekkaCore

private func pairingReport(_ before: String, _ after: String) throws -> DiffReport {
  try Differ.compare(
    Analyzer.analyze([("App.swift", before)]),
    Analyzer.analyze([("App.swift", after)]), beforeLabel: "before", afterLabel: "after")
}

@Test func repeatedExtensionsDoNotInventStructuralReplacement() throws {
  let first = "extension A { func existing() {} }\n"
  let second = "extension A { var count: Int { 0 } }\n"
  let added = "extension A { typealias Value = String }\n"
  let cases = [
    (first, added + first),
    (first + second, first + added + second),
    (first + second, second + first),
    (first + second, first + "extension A { var count: String { \"\" } }"),
    (added + first, first),
  ]
  for (before, after) in cases {
    let report = try pairingReport(before, after)
    #expect(report.findings.isEmpty)
    #expect(report.coverage.changedFiles.count == 1)
    #expect(report.coverage.changedFiles[0].syntaxChanged)
    #expect(report.coverage.comparedBodyCount == 0)
    #expect(report.notices.contains { $0.message.contains("structural and body comparisons are skipped") })
    #expect(Renderer.text(report).contains("inspect the ordinary diff"))
    #expect(report.coverage.bodyComparisons.allSatisfy { $0.reason == "ambiguous-type-identity" })
  }
}

@Test func conditionalDuplicatesDoNotPairButUniqueFamiliesStillCompare() throws {
  let before = "#if DEBUG\nstruct A { var value: Int }\n#else\nstruct A {}\n#endif\nstruct B {}"
  let after = "#if DEBUG\nstruct A { var value: String }\n#else\nstruct A {}\n#endif\nstruct B { var name: String }"
  let report = try pairingReport(before, after)
  #expect(!report.findings.contains { $0.type == "A" })
  #expect(report.findings.contains { $0.type == "B" && $0.rule == "members-changed" })
}

@Test func whollyOneSidedDuplicateFamiliesRemainKnownAdditionsAndRemovals() throws {
  let declarations = "extension A { func first() {} }; extension A { func second() {} }"
  let added = try pairingReport("", declarations)
  let removed = try pairingReport(declarations, "")
  #expect(added.findings.count == 2)
  #expect(added.findings.allSatisfy { $0.rule == "type-added" })
  #expect(removed.findings.count == 2)
  #expect(removed.findings.allSatisfy { $0.rule == "type-removed" })
}
