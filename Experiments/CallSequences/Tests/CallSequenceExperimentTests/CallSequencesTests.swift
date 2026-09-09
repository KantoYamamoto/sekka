import Foundation
import Testing
@testable import CallSequenceExperiment

private let pair = "logger.record(event); analytics.record(event)"
private func function(_ name: String, _ body: String = pair) -> String {
  "func \(name)(_ event: String) { \(body) }"
}

@Test func growthIncludesUnchangedSitesAndCountsDeclarations() throws {
  let unchanged = ("Old.swift", function("old"))
  let result = try CallSequences.compare(before: [unchanged], after: [
    ("New.swift", function("a") + "\n" + function("b", pair + "; " + pair)), unchanged,
  ])
  #expect(result.expansions.count == 1)
  let item = try #require(result.expansions.first)
  #expect(item.before.map(\.file) == ["Old.swift"])
  #expect(item.after.map(\.function) == ["a", "b", "old"])
  #expect(item.after.map(\.declarationLine) == [1, 2, 1])
}

@Test func singleAndUnchangedOrShrinkingRepetitionAreNotGrowth() throws {
  let one = [("A.swift", function("a", pair + "; " + pair))]
  let two = one + [("B.swift", function("b"))]
  #expect(try CallSequences.compare(before: [], after: one).expansions.isEmpty)
  #expect(try CallSequences.compare(before: two, after: two).expansions.isEmpty)
  #expect(try CallSequences.compare(before: two, after: one).expansions.isEmpty)
}

@Test func namesArgumentsOrderAndNonadjacencyStayDistinct() throws {
  let inputs = [function("a"), function("b", "analytics.record(event); logger.record(event)"),
    function("c", "logger.record(other); analytics.record(other)"),
    function("d", "logger.record(event); let x = 1; analytics.record(event)"),
    function("e", "log.record(event); analytics.record(event)")]
  #expect(try CallSequences.compare(before: [], after: [("A.swift", inputs.joined(separator: "\n"))]).expansions.isEmpty)
}

@Test func unsupportedContextsAreNotCounted() throws {
  let input = function("a") + "\n" + function("b", "let work = { " + pair + " }")
    + "\n" + function("c", function("nested"))
    + "\n#if FLAG\n" + function("d") + "\n#endif\n"
    + function("e", "try logger.record(event); analytics.record(event)")
  #expect(try CallSequences.compare(before: [], after: [("A.swift", input)]).expansions.isEmpty)
}

@Test func conditionalBranchesCountOneLexicalFunctionNotExecutions() throws {
  let body = "if flag { " + pair + " } else { " + pair + " }"
  let report = try CallSequences.compare(before: [], after: [("A.swift", function("a", body) + "\n" + function("b"))])
  #expect(report.expansions.first?.after.count == 2)
}

@Test func identicalSpellingDoesNotResolveDifferentReceiverTypes() throws {
  let input = "struct A { let logger: Log; let analytics: Metrics; " + function("run") + " }\n"
    + "struct B { let logger: TestDouble; let analytics: Stub; " + function("run") + " }"
  let result = try CallSequences.compare(before: [], after: [("A.swift", input)])
  #expect(result.expansions.first?.after.count == 2)
  #expect(result.limitations.contains { $0.contains("different objects") })
}

@Test func triviaDoesNotChangeSpellingAndLocationsAreStable() throws {
  let source = function("a") + "\nfunc b(_ event: String) {\n logger.record( event ) // comment\n analytics.record(event)\n}"
  let report = try CallSequences.compare(before: [], after: [("B.swift", source)])
  let sites = try #require(report.expansions.first?.after)
  #expect(sites.map(\.line) == [1, 3])
  #expect(sites.map(\.endLine) == [1, 4])
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  #expect(try encoder.encode(report) == encoder.encode(CallSequences.compare(before: [], after: [("B.swift", source)])))
}

@Test func malformedInputStopsInsteadOfReturningOtherFileResults() {
  #expect(throws: ExperimentError.self) {
    try CallSequences.compare(before: [], after: [("A.swift", function("a") + "\n" + function("b")), ("Z.swift", "struct {")])
  }
}

@Test func firstSourcePositionWinsOverVisitorNestingOrder() throws {
  let source = "func a(_ event: String) {\n if flag { " + pair + " }\n " + pair + "\n}\n" + function("b")
  let result = try CallSequences.compare(before: [], after: [("A.swift", source)])
  #expect(result.expansions.first?.after.first?.line == 2)
}

@Test func localFunctionsInInitializersAndAccessorsAreExcluded() throws {
  let input = function("a") + "\nstruct Box { init() { " + function("local") + " }; var value: Int { " + function("insideGetter") + "; return 0 } }"
  #expect(try CallSequences.compare(before: [], after: [("A.swift", input)]).expansions.isEmpty)
}
