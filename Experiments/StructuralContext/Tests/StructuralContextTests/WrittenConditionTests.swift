import Foundation
import Testing
@testable import StructuralContext

private let conditionHelper = "extension Helper { func clean(_ value: Int) {} }"
private func conditionReport(_ source: String, before: String = "") throws -> ContextReport {
  try UnchangedContext.compare(before: [("Caller.swift", before), ("Helper.swift", conditionHelper)],
    after: [("Caller.swift", source), ("Helper.swift", conditionHelper)])
}
private func conditionEntries(_ report: ContextReport) -> [MemberSpellingEntry] {
  report.contexts.flatMap(\.entries).compactMap { if case let .callSpelling(.introduced(value)) = $0 { return value }; return nil }
}

@Test func nestedConditionsRetainSelectedAndPrecedingHeaders() throws {
  let source = """
  #if OUTER
  func run() {
  #if false
    helper.clean(1)
  #elseif INNER
    helper.clean(2)
  #else
    helper.clean(3)
  #endif
  }
  #endif
  """
  let report = try conditionReport(source), entries = conditionEntries(report)
  #expect(entries.count == 3)
  #expect(entries.map { $0.call.site.line } == [4, 6, 8])
  #expect(entries.allSatisfy { $0.call.writtenConditions.count == 2 && $0.call.writtenConditions[0].selected.condition == "OUTER" })
  let branches = entries.map { $0.call.writtenConditions[1] }
  #expect(branches.map { $0.selected.keyword } == ["#if", "#elseif", "#else"])
  #expect(branches.map { $0.selected.site.line } == [3, 5, 7])
  #expect(branches.allSatisfy { $0.selected.site.line == $0.selected.site.endLine })
  #expect(branches[1].preceding.map(\.condition) == ["false"])
  #expect(branches[2].preceding.map(\.condition) == ["false", "INNER"])
  #expect(branches[2].selected.condition == nil)
  #expect(report.text().contains("#if false [Caller.swift:3]"))
  #expect(report.text().contains("先行節: #if false [Caller.swift:3] → #elseif INNER [Caller.swift:5]"))
  #expect(report.text().contains("有効節未判定"))
  let data = try JSONEncoder().encode(report)
  #expect(conditionEntries(try JSONDecoder().decode(ContextReport.self, from: data)).map { $0.call.writtenConditions } == entries.map { $0.call.writtenConditions })
}

@Test func conditionPatternsSeparateCountsIncludingUnconditionalOccurrences() throws {
  let source = """
  func run() {
    helper.clean(0)
  #if FLAG
    helper.clean(0)
    helper.clean(0)
  #else
    helper.clean(0)
  #endif
  #if OTHER
    helper.clean(0)
  #endif
  }
  """
  let entries = conditionEntries(try conditionReport(source))
  #expect(entries.count == 4)
  #expect(entries.map(\.eligibleOccurrences) == [1, 2, 1, 1])
  #expect(entries.map { $0.call.site.line } == [2, 4, 7, 10])
  #expect(entries[0].call.writtenConditions.isEmpty)
  #expect(entries[1].call.writtenConditions[0].selected.condition == "FLAG")
  #expect(entries[2].call.writtenConditions[0].selected.keyword == "#else")
  #expect(entries[3].call.writtenConditions[0].selected.condition == "OTHER")
}

@Test func repeatedWrittenConditionsGroupWithoutUsingHeaderPositions() throws {
  let source = """
  func run() {
  #if FLAG
    helper.clean(0)
  #endif
  #if FLAG
    helper.clean(0)
  #endif
  }
  """
  let entry = try #require(conditionEntries(conditionReport(source)).first)
  #expect(entry.eligibleOccurrences == 2 && entry.call.site.line == 3)
  let shifted = try #require(conditionEntries(conditionReport("\n\n" + source)).first)
  #expect(shifted.eligibleOccurrences == 2 && shifted.call.site.line == 5)
  #expect(entry.call.writtenConditions.map(\.groupingKey) == shifted.call.writtenConditions.map(\.groupingKey))
}

@Test func elsePredecessorChangesDoNotCollapseIntoOneGroup() throws {
  let source = """
  func run() {
  #if A
  #elseif B
  #else
    helper.clean(0)
  #endif
  #if A
  #elseif C
  #else
    helper.clean(0)
  #endif
  }
  """
  let entries = conditionEntries(try conditionReport(source))
  #expect(entries.count == 2 && entries.allSatisfy { $0.eligibleOccurrences == 1 })
  #expect(entries[0].call.writtenConditions[0].preceding.map(\.condition) == ["A", "B"])
  #expect(entries[1].call.writtenConditions[0].preceding.map(\.condition) == ["A", "C"])
}

@Test func closureConditionsKeepOuterContextAndExcludeLocalBodies() throws {
  let source = """
  #if OUTER
  func run() {
  #if INNER
    func local() { helper.clean(0) }
    struct Local { func run() { helper.clean(0) } }
    let block = { helper.clean(0) }
  #endif
  }
  #endif
  """
  let entries = conditionEntries(try conditionReport(source))
  #expect(entries.count == 1 && entries[0].eligibleOccurrences == 1)
  #expect(entries[0].call.site.line == 6)
  #expect(entries[0].call.writtenConditions.map { $0.selected.condition } == ["OUTER", "INNER"])
}

@Test func movingUnchangedCallBetweenConditionsDoesNotChangeEligibility() throws {
  let source = "func run() {\n#if A\nhelper.clean(0)\n#endif\n}"
  #expect(try conditionReport(source.replacingOccurrences(of: "#if A", with: "#if B"), before: source).contexts.isEmpty)
}

@Test func conditionalEvidenceIsStableForInputOrderAndHeaderTrivia() throws {
  let source = "func run() {\n#if A  /* written condition */ && B\nhelper.clean(0)\n#endif\n}"
  let old = [("Caller.swift", ""), ("Helper.swift", conditionHelper)]
  let new = [("Caller.swift", source), ("Helper.swift", conditionHelper)]
  let report = try UnchangedContext.compare(before: old, after: new)
  let branch = try #require(conditionEntries(report).first?.call.writtenConditions.first)
  #expect(branch.selected.condition == "A && B")
  #expect(branch.selected.site.line == 2 && branch.selected.site.endLine == 2)
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  #expect(try encoder.encode(report) == encoder.encode(UnchangedContext.compare(before: old.reversed(), after: new.reversed())))
}

@Test func malformedMultilineConditionDoesNotReturnPartialEvidence() throws {
  #expect(throws: ContextError.self) {
    try conditionReport("func run() {\n#if A &&\n B\nhelper.clean(0)\n#endif\n}")
  }
}
