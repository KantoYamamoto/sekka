import Foundation
import Testing
@testable import StructuralContext

private let dispatch = "switch value { case .a: old(input); case .b: buffer.withOld { p in sink(p) } }"
private func pair(_ body: String = dispatch) -> String {
  "struct Box { init() { callback { \(body) } }; static func report() { \(body) }; var finalize: () -> Void { { Box.report() } } }"
}
private func compare(_ old: String, _ new: String, all: Bool = false) throws -> RelationReport {
  try ContextRelations.compare(before: [("Fixture.swift", old)], after: [("Fixture.swift", new)], allEvidence: all)
}
@Test func changedHelperAndInitializerWithUnchangedPropertyUser() throws {
  let old = pair(), new = old.replacingOccurrences(of: "withOld", with: "withNew")
  let report = try compare(old, new)
  #expect(report.relationships.count == 1)
  #expect(report.text().contains("[owner changed]"))
  let r = try #require(report.relationships.first)
  #expect(Set(r.members.map { $0.after.owner.kind }) == ["initializer", "function"])
  #expect(r.enclosingConditionsDiffer)
  #expect(r.users.count == 2)
  #expect(r.users.allSatisfy { $0.ownerState == "token-identical" && $0.owner.kind == "property-body" })
  #expect(r.introducedCommonCallSpellings.contains { $0.spelling.calledExpression == "buffer . withNew" })
}
@Test func sharedImplementationIsCounterEvidenceNotResolution() throws {
  let old = pair(), new = old.replacingOccurrences(of: "withOld", with: "withNew") + "\nfunc withNew(_ body: () -> Void) { body() }"
  let r = try #require(try compare(old, new).relationships.first)
  let call = try #require(r.introducedCommonCallSpellings.first { $0.spelling.calledExpression == "buffer . withNew" })
  #expect(call.sameBasenameDeclarations.count == 1)
  #expect(call.sameBasenameDeclarations[0].selector == "withNew(_:)")
  #expect(call.match.contains("callee-unresolved"))
}
@Test func argumentsAndClosureBodiesAreNotEquivalent() throws {
  let old = pair().replacingOccurrences(of: "init() { callback { switch value { case .a: old(input)", with: "init() { callback { switch value { case .a: old(other)")
  let r = try #require(try compare(old, old.replacingOccurrences(of: "withOld", with: "withNew")).relationships.first)
  #expect(r.argumentSpellingsDiffer)
  let closures = "func first() { switch x { case .a: old { 1 }; case .b: fallback() } }; func second() { switch x { case .a: old { 2 }; case .b: fallback() } }"
  #expect(try compare(closures, closures.replacingOccurrences(of: "old", with: "new")).relationships[0].argumentSpellingsDiffer)
}
@Test func duplicateSwitchesAndOwnersRemainUnknown() throws {
  for source in ["func first() { \(dispatch); \(dispatch) }; func second() { \(dispatch) }",
                 "func same() { \(dispatch) }; func same() { \(dispatch) }"] {
    let report = try compare(source, source.replacingOccurrences(of: "withOld", with: "withNew"))
    #expect(report.relationships.isEmpty)
    #expect(!report.unknown.isEmpty)
    #expect(report.unknown.flatMap(\.before).count >= 2)
  }
}
@Test func changedEnclosingConditionsAndSubscriptHeaderCannotPair() throws {
  for wrapper in ["if outerA {} else if inner { BODY }", "while outerA { BODY }", "repeat { BODY } while outerA", "for item in outerA { BODY }", "guard outerA else { BODY; return }", "do { work() } catch where outerA { BODY }"] {
    let old = "func first() { \(wrapper.replacingOccurrences(of: "BODY", with: dispatch)) }; func second() { \(dispatch) }"
    let new = old.replacingOccurrences(of: "withOld", with: "withNew").replacingOccurrences(of: "outerA", with: "outerB")
    let report = try compare(old, new)
    #expect(report.relationships.isEmpty)
    #expect(report.unknown.count == 2)
  }
  let old = "struct Box { subscript(index: Int) -> Int { get { \(dispatch) } }; var other: Int { \(dispatch) } }"
  #expect(try compare(old, old.replacingOccurrences(of: "withOld", with: "withNew").replacingOccurrences(of: "index: Int", with: "index: String")).relationships.isEmpty)
}
@Test func conditionalCasesAreNotCompleteButLexicalBranchesStaySeparate() throws {
  let cases = "switch value {\n#if FLAG\ncase .a: old()\n#endif\ndefault: fallback()\n}"
  let old = "func first() { \(cases) }; func second() { \(cases) }"
  let report = try compare(old, old.replacingOccurrences(of: "old()", with: "new()"))
  #expect(report.relationships.isEmpty)
  #expect(report.unknown.count == 2)
  #expect(report.unknown.allSatisfy { $0.reason == "conditional-case-list-not-expanded" })
  let branches = "#if FLAG\nfunc first() { \(dispatch) }\n#else\nfunc second() { \(dispatch) }\n#endif"
  #expect(try compare(branches, branches.replacingOccurrences(of: "withOld", with: "withNew")).relationships[0].enclosingConditionsDiffer)
}
@Test func trailingLabelsBelongToShape() throws {
  let old = "func first() { switch x { case .a: old {} success: {}; case .b: fallback() } }; func second() { switch x { case .a: old {} failure: {}; case .b: fallback() } }"
  #expect(try compare(old, old.replacingOccurrences(of: "old", with: "new")).relationships.isEmpty)
  let same = old.replacingOccurrences(of: "failure", with: "success")
  #expect(try compare(same, same.replacingOccurrences(of: "success", with: "failure")).relationships.count == 1)
}
@Test func readerOwnershipDoesNotAbsorbHeaderOrLocalType() throws {
  let source = "func caller(_ value: Int = source()) { let stored = source(); struct Local { var closure = { source() } }; source() }"
  let snapshot = try RegionSnapshot([("Fixture.swift", source)])
  #expect(snapshot.calls.map { $0.owner?.kind } == [nil, "binding-initializer", "binding-initializer", "function"])
  #expect(key(snapshot.calls[1].owner!.key) != key(snapshot.calls[2].owner!.key))
}
@Test func errorsDoNotReturnPartialReportsAndNormalZeroIsDistinct() throws {
  #expect(throws: RelationInputError.self) { try ContextRelations.compare(before: [("A.swift", "struct A {}")], after: [("A.swift", "struct A {}"), ("Bad.swift", "func {")]) }
  #expect(throws: RelationInputError.self) { try ContextRelations.compare(before: [("A.swift", "struct A {}"), ("A.swift", "struct A {}")], after: []) }
  #expect(try compare("struct A {}", "struct B {}").relationships.isEmpty)
}
@Test func byteEqualityAndOrderingKeepDistinctUnicodePathsAndSpellings() throws {
  let composed = "é", decomposed = "e\u{301}"
  #expect(composed == decomposed)
  #expect(bytes(composed) != bytes(decomposed))
  let first = "func \(composed)() { \(dispatch) }", second = "func \(decomposed)() { \(dispatch) }"
  let report = try ContextRelations.compare(before: [(composed + ".swift", first), (decomposed + ".swift", second)], after: [(decomposed + ".swift", second.replacingOccurrences(of: "withOld", with: "withNew")), (composed + ".swift", first.replacingOccurrences(of: "withOld", with: "withNew"))])
  #expect(report.relationships.count == 1)
  #expect(report.unknown.isEmpty)
  #expect(Set(report.relationships[0].members.map { bytes($0.after.site.file) }).count == 2)
  let old = "func first() { switch x { case .a: \(composed)(); case .b: old() } }; func second() { switch x { case .a: \(decomposed)(); case .b: old() } }"
  #expect(try compare(old, old.replacingOccurrences(of: "old", with: "new")).relationships.isEmpty)
}
@Test func inputOrderDoesNotChangeAnyOutputBytes() throws {
  let a = ("A.swift", pair()), b = ("B.swift", "struct Other {}")
  let x = (a.0, a.1.replacingOccurrences(of: "withOld", with: "withNew"))
  let first = try ContextRelations.compare(before: [a,b], after: [b,x])
  let second = try ContextRelations.compare(before: [b,a], after: [x,b])
  #expect(key(first) == key(second)); #expect(first.text() == second.text())
}
@Test func detailLimitNeverDropsNavigationOrUnknownSites() throws {
  let bodies = (0..<10).map { i in
    "func first\(i)() { switch value { case .a: old\(i)(); case .b: fallback() } }; func second\(i)() { switch value { case .a: old\(i)(); case .b: fallback() } }"
  }.joined(separator: "\n")
  let new = bodies.replacingOccurrences(of: "old", with: "new")
  let limited = try compare(bodies, new), all = try compare(bodies, new, all: true)
  #expect(limited.relationships.count == 10 && limited.omittedShapeDetails == 2)
  #expect(all.omittedShapeDetails == 0)
  #expect(limited.relationships.map { key($0.members) } == all.relationships.map { key($0.members) })
  #expect(limited.relationships.map { key($0.users) } == all.relationships.map { key($0.users) })
  #expect(limited.relationships.map { key($0.introducedCommonCallSpellings) } == all.relationships.map { key($0.introducedCommonCallSpellings) })
  #expect(limited.text().contains("Shape detail omitted"))
}
@Test func physicalLocationsAndQuotedControls() throws {
  let old = "#sourceLocation(file: \"Virtual.swift\", line: 900)\n" + pair()
  let report = try ContextRelations.compare(before: [("odd\nname.swift", old)], after: [("odd\nname.swift", old.replacingOccurrences(of: "withOld", with: "withNew"))])
  #expect(report.relationships[0].members.allSatisfy { $0.after.site.line == 2 })
  #expect(report.text().contains("odd\\nname.swift"))
  #expect(!report.text().contains("odd\nname.swift"))
}
