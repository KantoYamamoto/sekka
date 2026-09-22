import Foundation
import Testing
@testable import StructuralContext

private let target = "struct Logger { func record(_ event: String) { systemLog(event); crashReport(event) } }"
private func screen(_ name: String = "Screen", extra: String = "", beforeCall: String = "logger.record(event)") -> String {
  "struct \(name) { let logger: Logger; func run(_ event: String) { \(beforeCall)\n\(extra) } }"
}
private func compare(_ before: String, _ after: String, targetBefore: String = target, targetAfter: String = target) throws -> ContextReport {
  try UnchangedContext.compare(before: [("Screen.swift", before), ("Logger.swift", targetBefore)],
    after: [("Screen.swift", after), ("Logger.swift", targetAfter)])
}

@Test func oneAdditionFindsUnchangedTargetWithEvidence() throws {
  let report = try compare(screen(), screen(extra: "analytics.track(event)"))
  let context = try #require(report.contexts.first)
  #expect(context.after.declaration == "Logger.record(_:)")
  #expect(context.fileUnchanged)
  #expect(context.entries.first?.writtenType == "Logger")
  #expect(context.entries.first?.sharedArgumentSpellings == ["event"])
  #expect(context.entries.first?.afterReceiver.file == "Screen.swift")
  #expect(report.skipped.isEmpty)
}

@Test func multipleEntrypointsShareOneTarget() throws {
  let before = (0..<3).map { screen("Screen\($0)") }.joined(separator: "\n")
  let after = (0..<3).map { screen("Screen\($0)", extra: "analytics.track(event)") }.joined(separator: "\n")
  let report = try compare(before, after)
  #expect(report.contexts.count == 1)
  #expect(report.contexts.first?.entries.count == 3)
  #expect(report.text().components(separatedBy: "┌ 未変更の関数候補").count == 2)
}

@Test func receiverTypeAndTypeHeaderChangeDoNotReuseOldPath() throws {
  let after = screen(extra: "analytics.track(event)").replacingOccurrences(of: "logger: Logger", with: "logger: Other")
  let report = try compare(screen(), after, targetAfter: target + "\nstruct Other { func record(_ event: String) {} }")
  #expect(report.contexts.isEmpty)
  #expect(report.skipped.contains { $0.reason == "candidate-path-changed" })
  let changedKind = try compare(screen(), screen(extra: "analytics.track(event)"), targetAfter: target.replacingOccurrences(of: "struct Logger", with: "class Logger"))
  #expect(changedKind.contexts.isEmpty)
}

@Test func candidateDeclarationChangeIsNotOutsideContext() throws {
  let report = try compare(screen(), screen(extra: "analytics.track(event)"), targetAfter: target.replacingOccurrences(of: "crashReport(event)", with: "another(event)"))
  #expect(report.contexts.isEmpty)
  #expect(report.skipped.contains { $0.reason == "target-declaration-changed" })
}

@Test func unchangedDeclarationInsideChangedFileUsesNewPosition() throws {
  let before = [("All.swift", target + "\n" + screen())]
  let after = [("All.swift", "// header\n" + target + "\n" + screen(extra: "analytics.track(event)"))]
  let report = try UnchangedContext.compare(before: before, after: after)
  #expect(report.contexts.first?.fileUnchanged == false)
  #expect(report.contexts.first?.before.line == 1)
  #expect(report.contexts.first?.after.line == 2)
  #expect(report.text().contains("この宣言のトークンは未変更"))
}

@Test func unrelatedCallElsewhereInFunctionIsNotReturned() throws {
  let before = screen(beforeCall: "logger.record(event)\ncache.prepare(other)")
  let after = screen(extra: "analytics.track(event)", beforeCall: "logger.record(event)\ncache.prepare(other)")
  let report = try compare(before, after)
  #expect(report.contexts.isEmpty)
  #expect(report.skipped.contains { $0.reason == "no-shared-identifier-argument" })
}

@Test func literalOnlyAndNestedOrWrappedCallsAreOutsideInitialScope() throws {
  #expect(try compare(screen(beforeCall: "logger.record(\"same\")"), screen(extra: "analytics.track(\"same\")", beforeCall: "logger.record(\"same\")")).contexts.isEmpty)
  #expect(try compare(screen(beforeCall: "if active { logger.record(event) }"), screen(beforeCall: "if active { logger.record(event); analytics.track(event) }")).contexts.isEmpty)
  #expect(try compare(screen(), screen(extra: "try analytics.track(event)")).contexts.isEmpty)
  #expect(try compare(screen(), screen(extra: "await analytics.track(event)")).contexts.isEmpty)
}

@Test func ambiguousExistingStatementIsNotPairedByOrder() throws {
  let before = screen(beforeCall: "logger.record(event); logger.record(event)")
  let after = screen(extra: "analytics.track(event)", beforeCall: "logger.record(event); logger.record(event)")
  let report = try compare(before, after)
  #expect(report.contexts.isEmpty)
  #expect(report.skipped.contains { $0.reason == "existing-call-not-unique-or-changed" })
}

@Test func unchangedInputTriviaAndExternalPolicyDoNotCreateObservations() throws {
  let source = screen(extra: "analytics.track(event)")
  #expect(try compare(source, source).contexts.isEmpty)
  #expect(try compare(screen(), "// policy differs\n" + screen()).contexts.isEmpty)
}

@Test func shadowAndUnknownExpansionRemainVisibleAsSkippedReasons() throws {
  let source = screen(beforeCall: "let logger = Other(); logger.record(event)")
  let report = try compare(source, screen(extra: "analytics.track(event)", beforeCall: "let logger = Other(); logger.record(event)"))
  #expect(report.contexts.isEmpty)
  #expect(report.skipped.contains { $0.reason == "before:receiver-shadowed" })
  let macro = try compare(screen(), screen(extra: "analytics.track(event)"), targetAfter: target + "\n#moreDeclarations")
  #expect(macro.contexts.isEmpty)
  #expect(macro.skipped.contains { $0.reason == "after:unexpanded-global-declarations" })
}

@Test func existingCallerAndPropertyMustNotBeNew() throws {
  let report = try compare("", screen(extra: "analytics.track(event)"))
  #expect(report.contexts.isEmpty)
  #expect(report.unpairedAfter == 1)
  let before = screen().replacingOccurrences(of: "let logger: Logger;", with: "")
  #expect(try compare(before, screen(extra: "analytics.track(event)")).contexts.isEmpty)
}

@Test func entryCapsAndInputOrderAreExplicitAndStable() throws {
  let before = (0..<10).map { screen("Screen\($0)") }.joined(separator: "\n")
  let after = (0..<10).map { screen("Screen\($0)", extra: "analytics.track(event)") }.joined(separator: "\n")
  let report = try compare(before, after)
  #expect(report.contexts.first?.entries.count == 8)
  #expect(report.contexts.first?.omittedEntries == 2)
  let a = [("Screen.swift", before), ("Logger.swift", target)], b = [("Screen.swift", after), ("Logger.swift", target)]
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  #expect(try encoder.encode(UnchangedContext.compare(before: a, after: b)) == encoder.encode(UnchangedContext.compare(before: a.reversed(), after: b.reversed())))
}

@Test func malformedInputAndControlCharactersRemainSafe() throws {
  #expect(throws: ContextError.self) { try UnchangedContext.compare(before: [], after: [("bad.swift", "struct {")]) }
  let report = try UnchangedContext.compare(before: [("bad\nname.swift", target + "\n" + screen())], after: [("bad\nname.swift", target + "\n" + screen(extra: "analytics.track(event)"))])
  #expect(report.text().contains("bad\\u{a}name.swift"))
}

@Test func changedArgumentsAreNotDescribedAsAnInsertedCall() throws {
  let before = screen(extra: "analytics.track(event, mode: old)")
  let after = screen(extra: "analytics.track(event, mode: new)")
  let report = try compare(before, after)
  #expect(report.contexts.count == 1)
  #expect(report.contexts.first?.entries.first?.newOrChangedCall.line == 2)
  #expect(report.text().contains("旧版に同じ文なし"))
  #expect(!report.text().contains("追加call"))
  let data = try JSONEncoder().encode(report)
  #expect(String(decoding: data, as: UTF8.self).contains("newOrChangedCall"))
}
