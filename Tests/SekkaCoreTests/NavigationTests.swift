import Foundation
import Testing

@testable import SekkaCore

private func navigate(_ before: String, _ after: String, at: String?) throws -> String {
  let a = try Analyzer.analyze([("space name.swift", before)])
  let b = try Analyzer.analyze([("space name.swift", after)])
  let report = Differ.compare(a, b, beforeLabel: "old", afterLabel: "new")
  return try DiffNavigation.render(before: a, after: b, report: report, file: "space name.swift", at: at)
}

@Test func declarationSelectionFindsDistantChangeAndOmitsOtherFunction() throws {
  let padding = String(repeating: "    work()\n", count: 15)
  let before = "struct S {\n  func target() {\n\(padding)    value = 1\n\(padding)  }\n  func other() {\n\(padding)    different = 1\n  }\n}\n"
  let after = before.replacingOccurrences(of: "value = 1", with: "value = 2")
    .replacingOccurrences(of: "different = 1", with: "different = 2")
  let selected = try navigate(before, after, at: "after:2")
  #expect(selected.contains("+    value = 2"))
  #expect(!selected.contains("different = 2"))
  #expect(selected.contains("-before +after"))
  #expect(try navigate(before, after, at: nil).contains("different = 2"))
}

@Test func multipleHunksInOneBodyAndParameterChangeRemainReachable() throws {
  let padding = String(repeating: "    work()\n", count: 15)
  let before = "struct S {\n  func target() {\n    first = 1\n\(padding)    last = 1\n  }\n}\n"
  let after = before.replacingOccurrences(of: "target()", with: "target(mode: Bool)")
    .replacingOccurrences(of: "= 1", with: "= 2")
  let result = try navigate(before, after, at: "before:2")
  #expect(result.contains("first = 2"))
  #expect(result.contains("last = 2"))
  #expect(result.components(separatedBy: "@@ -").count - 1 == 2)
}

@Test func deletedTypeUsesBeforeRangeAndAmbiguousMemberFallsBack() throws {
  let before = "struct Removed {\n  func run() { previous() }\n}\n"
  let output = try navigate(before, "", at: "before:2")
  #expect(output.contains("-  func run()"))
  #expect(output.contains("Hunks overlapping"))
  let fallback = try navigate(
    "struct A { func old() {} }", "struct A { func new() {} }", at: "after:1")
  #expect(fallback.contains("showing all file hunks"))
  #expect(try navigate("func f() { a() }", "func f() { b() }", at: "after:1")
    .contains("showing all file hunks"))
}

@Test func fingerprintChangesWithSourcesAndPathsButNotEnumerationOrder() throws {
  let a = try Analyzer.analyze([("A.swift", "struct A {}"), ("B.swift", "struct B {}")])
  let b = try Analyzer.analyze([("B.swift", "struct B {}"), ("A.swift", "struct A {}")])
  let c = try Analyzer.analyze([("A.swift", "// moved\nstruct A {}"), ("B.swift", "struct B {}")])
  #expect(try Inputs.fingerprint(before: a, after: b) == Inputs.fingerprint(before: a, after: a))
  #expect(try Inputs.fingerprint(before: a, after: c) != Inputs.fingerprint(before: a, after: a))
}
