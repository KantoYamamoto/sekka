import Foundation
import Testing
@testable import StructuralContext

private let retained = "extension Helper { func clean(_ value: Int) {} }"
private func decreaseReport(_ before: String, _ after: String, oldHelper: String = retained, newHelper: String = retained) throws -> ContextReport {
  try UnchangedContext.compare(before: [("Caller.swift", before), ("Helper.swift", oldHelper)],
    after: [("Caller.swift", after), ("Helper.swift", newHelper)])
}
private func decreases(_ report: ContextReport) -> [SelectorDecreaseEntry] {
  report.contexts.flatMap(\.entries).compactMap {
    if case let .callSpelling(.decreased(evidence)) = $0 { return evidence }; return nil
  }
}

@Test func deletedIndexedCallerReachesRetainedHelperWithoutDeletionVerdict() throws {
  let old = "func run() { helper.clean(0); helper.clean(1) }"
  let report = try decreaseReport(old, "")
  let entry = try #require(decreases(report).first)
  #expect(report.contexts.count == 1 && report.contexts[0].fileUnchanged)
  #expect(entry.beforeOccurrences.count == 2 && entry.afterOccurrences.isEmpty)
  #expect(entry.beforeOccurrences.allSatisfy { $0.side == .before && $0.counterpartCaller == nil })
  #expect(entry.beforeOccurrences.allSatisfy { $0.call.site.file == "Caller.swift" && $0.caller.declaration == "run()" })
  #expect(report.text().contains("before 2 → after 0件"))
  #expect(report.text().contains("削除とは断定しない") && report.text().contains("改修必要性は未判定"))
}

@Test func selectorCountsDoNotPairWhichSemanticCallDisappeared() throws {
  let before = "func run() { helper.clean(0); helper.clean(1) }"
  let after = "func run() { unrelated.clean(2) }"
  let entry = try #require(decreases(decreaseReport(before, after)).first)
  #expect(entry.beforeOccurrences.count == 2 && entry.afterOccurrences.count == 1)
  #expect(entry.afterOccurrences[0].side == .after && entry.afterOccurrences[0].call.receiverSpelling == "unrelated")
  #expect(entry.beforeOccurrences.allSatisfy { $0.counterpartCaller?.declaration == "run()" && $0.correspondence == "paired-declaration-changed" })
  #expect(entry.matchingBeforeDeclarations == 1 && entry.matchingAfterDeclarations == 1)
}

@Test func moveAndMemberToUnqualifiedWithEqualTotalsAreNotDecreases() throws {
  let old = "func old() { helper.clean(0) }"
  for new in ["func new() { helper.clean(0) }", "func old() { clean(0) }"] {
    #expect(try decreases(decreaseReport(old, new)).isEmpty)
  }
}

@Test func renameSignatureAndScopeChangeStayUnknownWithoutLosingOldPositions() throws {
  let old = "struct Worker<T: P> { func run() { helper.clean(0); helper.clean(1) } }"
  for new in [
    "struct Worker<T: P> { func renamed() { helper.clean(0) } }",
    "struct Worker<T: P> { func run(_ value: Int) { helper.clean(0) } }",
    "struct Worker<T: Q> { func run() { helper.clean(0) } }",
  ] {
    let entry = try #require(decreases(decreaseReport(old, new)).first)
    #expect(entry.beforeOccurrences.count == 2 && entry.afterOccurrences.count == 1)
    #expect(entry.beforeOccurrences.allSatisfy { $0.counterpartCaller == nil })
    #expect(entry.afterOccurrences.allSatisfy { $0.counterpartCaller == nil })
  }
}

@Test func decreaseRequiresBothUniqueRetainedDeclarationsWithBodyAndHeaders() throws {
  let old = "func run() { helper.clean(0) }"
  for newHelper in ["", retained.replacingOccurrences(of: "{}", with: "{ changed() }"),
    retained + "\nstruct Another { func clean(_ value: Int) {} }", "protocol Helper { func clean(_ value: Int) }"] {
    #expect(try decreases(decreaseReport(old, "", newHelper: newHelper)).isEmpty)
  }
  let parent = "struct Parent<T: P> { func clean(_ value: Int) {} }"
  #expect(try decreases(decreaseReport(old, "", oldHelper: parent, newHelper: parent.replacingOccurrences(of: "T: P", with: "T: Q"))).isEmpty)
  let conditional = "#if FLAG\n" + retained + "\n#endif"
  #expect(try decreases(decreaseReport(old, "", oldHelper: conditional, newHelper: conditional.replacingOccurrences(of: "FLAG", with: "OTHER"))).isEmpty)
  let ambiguousOld = retained + "\nstruct Another { func clean(_ value: Int) {} }"
  #expect(try decreases(decreaseReport(old, "", oldHelper: ambiguousOld)).isEmpty)
  let bodyless = "protocol Helper { func clean(_ value: Int) }"
  #expect(try decreases(decreaseReport(old, "", oldHelper: bodyless, newHelper: bodyless)).isEmpty)
}

@Test func retainedTargetMovingFilesIsNotSameCorrespondence() throws {
  let report = try UnchangedContext.compare(before: [("Old.swift", retained), ("Caller.swift", "func run() { helper.clean(0) }")],
    after: [("New.swift", retained)])
  #expect(decreases(report).isEmpty)
  #expect(report.skipped.contains { $0.reason == "decrease:target-correspondence-changed" })
}

@Test func sameNameSDKRemainsAnUnresolvedCandidate() throws {
  let report = try decreaseReport("func run() { buffer.clean(0); foreign.clean(1) }", "func run() { other.clean(2) }")
  #expect(decreases(report).count == 1)
  #expect(report.text().contains("実callee・消失call・移行対応は未解決"))
  #expect(report.limitations.contains { $0.contains("SDK/unindexed declarations") && $0.contains("not bypassing") })
}

@Test func decreasedOccurrencesKeepEveryConditionalPositionIncludingFalseBranches() throws {
  let old = """
  #if OUTER
  func run() {
  #if false
    helper.clean(0)
  #else
    helper.clean(1)
  #endif
  }
  #endif
  """
  let entry = try #require(decreases(decreaseReport(old, "")).first)
  #expect(entry.beforeOccurrences.map { $0.call.site.line } == [4, 6])
  #expect(entry.beforeOccurrences.allSatisfy { $0.call.writtenConditions.count == 2 })
  #expect(entry.beforeOccurrences[1].call.writtenConditions[1].preceding[0].condition == "false")
  #expect(try decreaseReport(old, "").text().contains("有効節未判定"))
}

@Test func decreasedCallsShareBodyBoundaryAndSupportedForms() throws {
  let old = """
  func run(_ value: Int = helper.clean(9)) {
    func local() { helper.clean(8) }
    struct Local { func run() { helper.clean(7) } }
    helper.clean { 6 }
    helper.clean<Int>(5)
    let closure = { clean(4) }
    helper.clean(3)
  }
  """
  let entry = try #require(decreases(decreaseReport(old, "")).first)
  #expect(entry.beforeOccurrences.count == 2)
  #expect(entry.beforeOccurrences.map { $0.call.site.line } == [6, 7])
  #expect(entry.beforeOccurrences.map { $0.call.form } == [.unqualified, .member])
}

@Test func sameTargetAggregatesIntroducedAndDecreasedRelations() throws {
  let report = try decreaseReport("func run() { helper.clean(0); helper.clean(1) }", "func run() { helper.clean(2) }")
  #expect(report.contexts.count == 1 && report.contexts[0].entries.count == 2)
  #expect(decreases(report).count == 1)
  if case let .callSpelling(.introduced(e)) = report.contexts[0].entries[0] { #expect(e.sourceSide == .after) }
  else { Issue.record("Expected introduced after relation before selector decrease") }
}

@Test func completeDecreaseGroupsRespectCommonTargetCap() throws {
  let helpers = (0..<9).map { "func clean\($0)() {}" }.joined(separator: "\n")
  let old = "func run() { " + (0..<9).map { "helper.clean\($0)()" }.joined(separator: ";") + " }"
  let report = try decreaseReport(old, "", oldHelper: helpers, newHelper: helpers)
  #expect(report.contexts.count == 8 && report.omittedTargets == 1)
  #expect(decreases(report).count == 8)
}

@Test func noDecreaseAndEmptyInputsAreNotApproval() throws {
  #expect(try decreases(decreaseReport("func run() { helper.clean(0) }", "func run() { helper.clean(0) }")).isEmpty)
  #expect(try UnchangedContext.compare(before: [], after: []).contexts.isEmpty)
}

@Test func decreaseJSONIsStableAcrossInputOrderAndRoundTrip() throws {
  let old = [("Z.swift", "func z() { helper.clean(0) }"), ("A.swift", "func a() { clean(1) }"), ("Helper.swift", retained)]
  let new = [("Helper.swift", retained)]
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  let data = try encoder.encode(UnchangedContext.compare(before: old, after: new))
  #expect(data == (try encoder.encode(UnchangedContext.compare(before: old.reversed(), after: new))))
  #expect(data == (try encoder.encode(JSONDecoder().decode(ContextReport.self, from: data))))
}

@Test func malformedOtherFileRejectsPotentialDecreaseReport() throws {
  #expect(throws: ContextError.self) { try decreaseReport("func run() { helper.clean(0) }", "struct Broken {") }
}
