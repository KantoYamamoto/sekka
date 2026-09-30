import Foundation
import Testing
@testable import StructuralContext

private let helper = "extension Buffer where Element: P { func prune(from index: Int, where predicate: (Int) -> Bool) { storage.compact() } }"
private func spellingReport(_ before: String, _ after: String, oldHelper: String = helper, newHelper: String = helper) throws -> ContextReport {
  try UnchangedContext.compare(before: [("Caller.swift", before), ("Helper.swift", oldHelper)], after: [("Caller.swift", after), ("Helper.swift", newHelper)])
}
private func spellingEntries(_ report: ContextReport) -> [MemberSpellingEntry] {
  report.contexts.flatMap(\.entries).compactMap { if case let .memberSpelling(evidence) = $0 { return evidence }; return nil }
}

@Test func changedSignatureReachesUnchangedSplitExtensionMember() throws {
  let source = "extension Worker { func run() -> Bool { defer { target.prune(from: 0, where: { $0 == 0 }) }; return true } }"
  let split = helper + "\nextension Buffer where Element: P { func other() {} }"
  let report = try spellingReport(source, source.replacingOccurrences(of: "-> Bool", with: "-> Int"), oldHelper: split, newHelper: split)
  let target = try #require(report.contexts.first)
  #expect(report.contexts.count == 1 && target.fileUnchanged)
  #expect(target.after.declaration == "extension Buffer.prune(from:where:)")
  let entry = try #require(spellingEntries(report).first)
  #expect(entry.beforeCaller == nil && entry.callerEvidence == "no-unique-old-indexed-correspondence")
  #expect(entry.call.receiverSpelling == "target" && entry.call.selector == "prune(from:where:)")
  #expect(entry.eligibleOccurrences == 1 && entry.matchingIndexedDeclarations == 1)
  #expect(report.text().contains("一意な旧索引対応は未確認"))
  #expect(report.text().contains("実calleeは未解決"))
}

@Test func onlyEligibleCallOccurrencesAreGroupedAndLocated() throws {
  let before = """
  func run() {
    buffer.clean(1)
  }
  """
  let after = """
  func run() {
    buffer.clean(1)
    buffer.clean(2)
    buffer.clean(2)
  }
  """
  let h = "extension Buffer { func clean(_ value: Int) {} }"
  let entry = try #require(spellingEntries(try spellingReport(before, after, oldHelper: h, newHelper: h)).first)
  #expect(entry.beforeCaller?.line == 1)
  #expect(entry.callerEvidence == "call-text-absent-from-paired-old-body")
  #expect(entry.call.site.line == 3 && entry.eligibleOccurrences == 2)
  #expect(entry.call.tokens == "buffer . clean ( 2 )")
}

@Test func newCallerIsUnknownBeforeAndUnchangedMemberCallsAreNotReopened() throws {
  let h = "struct Helper { func clean(_ value: Int) {} }"
  let entry = try #require(spellingEntries(try spellingReport("", "func fresh() { helper.clean(0) }", oldHelper: h, newHelper: h)).first)
  #expect(entry.beforeCaller == nil && entry.callerEvidence == "no-unique-old-indexed-correspondence")
  #expect(try spellingReport("func run() { helper.clean(0) }", "func run() { helper.clean(0); unrelated() }", oldHelper: h, newHelper: h).contexts.isEmpty)
}

@Test func newAndChangedSameShapeDeclarationsStillCountAsAmbiguous() throws {
  let h = "struct Helper { func clean(_ value: Int) {} }"
  let extra = "\nstruct Other { func clean(_ value: Int) { new() } }"
  let report = try spellingReport("", "func run() { helper.clean(0) }", oldHelper: h, newHelper: h + extra)
  #expect(report.contexts.isEmpty)
  #expect(report.skipped.contains { $0.reason == "spelling:multiple-exact-label-declarations" && $0.count == 1 })
  let changed = try spellingReport("", "func run() { helper.clean(0) }", oldHelper: h, newHelper: h.replacingOccurrences(of: "{}", with: "{ new() }"))
  #expect(changed.contexts.isEmpty)
  #expect(changed.skipped.contains { $0.reason == "spelling:target-declaration-changed" })
}

@Test func everyEnclosingNominalHeaderMustStayEqual() throws {
  let old = "struct Parent<T: P> { struct Child { func clean(_ value: Int) {} } }"
  let new = old.replacingOccurrences(of: "T: P", with: "T: Q")
  let report = try spellingReport("", "func run() { helper.clean(0) }", oldHelper: old, newHelper: new)
  #expect(report.contexts.isEmpty)
  #expect(report.skipped.contains { $0.reason == "spelling:target-scope-header-changed" })
  let extensionChanged = try spellingReport("", "func run() { target.prune(from: 0, where: { true }) }", newHelper: helper.replacingOccurrences(of: "Element: P", with: "Element: Q"))
  #expect(extensionChanged.contexts.isEmpty)
  #expect(extensionChanged.skipped.contains { $0.reason == "spelling:target-correspondence-unknown" })
}

@Test func nominalAndConditionalDuplicateScopesRemainUnknown() throws {
  let conditional = "#if A\nextension S { func clean(_ value: Int) {} }\n#endif\n#if A\nextension S { func other() {} }\n#endif"
  let report = try spellingReport("", "func run() { helper.clean(0) }", oldHelper: conditional, newHelper: conditional)
  #expect(report.contexts.isEmpty)
  #expect(report.skipped.contains { $0.reason == "spelling:target-correspondence-unknown" })
  let duplicate = "struct S { func clean(_ value: Int) {} }\nstruct S { func other() {} }"
  #expect(try spellingReport("", "func run() { helper.clean(0) }", oldHelper: duplicate, newHelper: duplicate).contexts.isEmpty)
}

@Test func localDeclarationsAndTrailingClosuresAreOutsideWrittenMemberRoute() throws {
  let h = "struct Helper { func clean(_ value: Int) {} }"
  let source = "func run() { func local() { helper.clean(0) }; struct Local { func inner() { helper.clean(1) } }; helper.clean { 2 }; clean(3) }"
  #expect(try spellingReport("", source, oldHelper: h, newHelper: h).contexts.isEmpty)
  let closure = "func run() { let block = { helper.clean(4) } }"
  #expect(try spellingEntries(spellingReport("", closure, oldHelper: h, newHelper: h)).count == 1)
}

@Test func exactSpellingDoesNotClaimDefaultArgumentApplicability() throws {
  let h = "struct Helper { func clean(_ value: Int) {}; func clean(_ value: Int, mode: Bool = true) {} }"
  let report = try spellingReport("", "func run() { helper.clean(0) }", oldHelper: h, newHelper: h)
  #expect(spellingEntries(report).count == 1)
  #expect(report.text().contains("同一記載ラベル列の索引内宣言 1件"))
  #expect(report.limitations.contains { $0.contains("default arguments") })
}

@Test func sameDeclarationReachedByBothRoutesIsNotDuplicated() throws {
  let h = "struct Helper { func clean(_ value: Int) {} }"
  let before = "struct S { let helper: Helper; func run(_ value: Int) { helper.clean(value) } }"
  let after = before.replacingOccurrences(of: "helper.clean(value)", with: "helper.clean(value); tracking.record(value); helper.clean(0)")
  let report = try spellingReport(before, after, oldHelper: h, newHelper: h)
  #expect(report.contexts.count == 1 && spellingEntries(report).count == 1)
  #expect(report.contexts[0].entries.count == 2 && report.contexts[0].entries[0].call != nil)
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  let a = [("A.swift", before), ("Helper.swift", h)], b = [("A.swift", after), ("Helper.swift", h)]
  #expect(try encoder.encode(UnchangedContext.compare(before: a, after: b)) == encoder.encode(UnchangedContext.compare(before: a.reversed(), after: b.reversed())))
}

@Test func writtenMemberTargetsAndEntriesRespectCommonCaps() throws {
  let helpers = (0..<9).map { "func method\($0)() {}" }.joined(separator: "\n")
  let h = "struct Helper { \(helpers) }"
  let body = (0..<9).map { "helper.method\($0)()" }.joined(separator: ";")
  let targets = try spellingReport("", "func run() { \(body) }", oldHelper: h, newHelper: h)
  #expect(targets.contexts.count == 8 && targets.omittedTargets == 1)
  let callers = (0..<10).map { "func caller\($0)() { helper.method0() }" }.joined(separator: "\n")
  let entries = try spellingReport("", callers, oldHelper: h, newHelper: h)
  #expect(entries.contexts.count == 1 && entries.contexts[0].entries.count == 8 && entries.contexts[0].omittedEntries == 2)
}
