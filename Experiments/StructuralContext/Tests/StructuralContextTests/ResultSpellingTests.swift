import Foundation
import Testing
@testable import StructuralContext

private let resultHelper = """
struct Receipt {}
func prior() -> Receipt {
  return Receipt(value: 1)
}
"""
private func resultReport(_ after: String, before: String = "", oldHelper: String = resultHelper, newHelper: String = resultHelper) throws -> ContextReport {
  try UnchangedContext.compare(before: [("Caller.swift", before), ("Helper.swift", oldHelper)],
    after: [("Caller.swift", after), ("Helper.swift", newHelper)])
}
private func resultEntries(_ report: ContextReport) -> [ResultSpellingEntry] {
  report.contexts.flatMap(\.entries).compactMap { if case let .resultSpelling(e) = $0 { return e }; return nil }
}

@Test func returnNameFindsExistingProducerRatherThanCallee() throws {
  let report = try resultReport("func fresh() -> (Receipt, Int) { (Receipt(value: 2), 0) }")
  let target = try #require(report.contexts.first)
  let entry = try #require(resultEntries(report).first)
  #expect(report.contexts.count == 1 && target.after.declaration == "prior()" && target.fileUnchanged)
  #expect(entry.beforeCaller == nil && entry.callerEvidence == "no-unique-old-indexed-correspondence")
  #expect(entry.anchorReturn.written == "Receipt" && entry.anchorReturn.site.file == "Caller.swift")
  #expect(entry.targetReturn.site.line == 2 && entry.matchingNominal.line == 1)
  #expect(entry.anchorCall.form == .unqualified && entry.anchorCall.receiverSpelling == nil)
  #expect(entry.targetCall.site.line == 3 && entry.anchorCall.selector == "Receipt(value:)")
  #expect(report.text().contains("calleeではない") && report.text().contains("引数値/挙動/責務は未比較"))
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  let data = try encoder.encode(report)
  #expect(try encoder.encode(JSONDecoder().decode(ContextReport.self, from: data)) == data)
}

@Test func resultCallsRequireBothReturnNameAndExplicitLabels() throws {
  for body in ["func fresh() -> Int { Receipt(value: 2); return 0 }",
    "func fresh() -> Receipt { Receipt(other: 2) }",
    "func fresh() -> SDKResult { SDKResult(value: 2) }",
    "func fresh() -> Receipt { Namespace.Receipt(value: 2) }",
    "func fresh() -> Receipt { Receipt<Int>(value: 2) }",
    "func fresh() -> Receipt { .init(value: 2) }",
    "func fresh() -> Receipt { Receipt { 2 } }"] {
    #expect(try resultEntries(resultReport(body)).isEmpty)
  }
  let noReturn = "struct Receipt {}\nfunc prior() { Receipt(value: 1) }"
  #expect(try resultEntries(resultReport("func fresh() -> Receipt { Receipt(value: 2) }", oldHelper: noReturn, newHelper: noReturn)).isEmpty)
}

@Test func pairedResultCallEligibilityPrecedesOccurrenceGrouping() throws {
  let before = "func fresh() -> Receipt { Receipt(value: 1) }"
  let after = """
  func fresh() -> Receipt {
    Receipt(value: 1)
    Receipt(value: 2)
    Receipt(value: 2)
  }
  """
  let entry = try #require(resultEntries(resultReport(after, before: before)).first)
  #expect(entry.beforeCaller?.line == 1 && entry.callerEvidence == "call-text-absent-from-paired-old-body")
  #expect(entry.anchorCall.site.line == 3 && entry.eligibleOccurrences == 2 && entry.targetOccurrences == 1)
  #expect(try resultEntries(resultReport(before + "\nfunc unrelated() {}", before: before)).isEmpty)
  #expect(try resultEntries(resultReport("func fresh() -> Receipt { Receipt(value: 1); unrelated() }", before: before)).isEmpty)
}

@Test func resultSignatureChangeRemainsUnknownOldCorrespondence() throws {
  let entry = try #require(resultEntries(resultReport("func fresh() -> (Receipt, Int) { (Receipt(value: 1), 0) }",
    before: "func fresh() -> Receipt { Receipt(value: 1) }")).first)
  #expect(entry.beforeCaller == nil && entry.eligibleOccurrences == 1)
}

@Test func genericAssociatedSelfAndValueBindingsDoNotBecomeNominals() throws {
  for caller in ["func fresh<Receipt>() -> Receipt { Receipt(value: 2) }",
    "struct Box<Receipt> { func fresh() -> Receipt { Receipt(value: 2) } }",
    "protocol Box { associatedtype Receipt; func fresh() -> Receipt { Receipt(value: 2) } }",
    "protocol Box { associatedtype Receipt }\nextension Box { func fresh() -> Receipt { Receipt(value: 2) } }",
    "struct Box<Receipt> {}\nextension Box { func fresh() -> Receipt { Receipt(value: 2) } }",
    "func fresh(_ Receipt: (Int) -> Receipt) -> Receipt { Receipt(value: 2) }",
    "func fresh() -> Receipt { let Receipt = factory; return Receipt(value: 2) }",
    "func fresh() -> Receipt { func Receipt(value: Int) -> Receipt { fatalError() }; return Receipt(value: 2) }",
    "func fresh() -> Receipt { protocol Receipt {}; return Receipt(value: 2) }",
    "func fresh() -> Receipt { consume { (Receipt: Factory) in Receipt(value: 2) }; return fallback() }",
    "func fresh() -> Receipt { consume { Receipt in Receipt(value: 2) }; return fallback() }",
    "func fresh() -> Receipt { consume { [Receipt = factory] in Receipt(value: 2) }; return fallback() }",
    "struct Box { let Receipt = factory; func fresh() -> Receipt { Receipt(value: 2) } }",
    "struct Box { func Receipt(value: Int) -> Receipt { fallback() }; func fresh() -> Receipt { Receipt(value: 2) } }",
    "struct Box { let (Receipt, other) = factory; func fresh() -> Receipt { Receipt(value: 2) } }",
    "enum Box { case Receipt(value: Int); static func fresh() -> Receipt { _ = Receipt(value: 2); return fallback() } }",
    "struct Box {}\nextension Box { let Receipt = factory }\nextension Box { func fresh() -> Receipt { Receipt(value: 2) } }",
    "func Receipt(value: Int) -> Receipt { fallback() }\nfunc fresh() -> Receipt { Receipt(value: 2) }"] {
    #expect(try resultEntries(resultReport(caller)).isEmpty)
  }
  let selfHelper = "struct `Self` {}\nfunc prior() -> Self { Self(value: 1) }"
  #expect(try resultEntries(resultReport("func fresh() -> Self { Self(value: 2) }", oldHelper: selfHelper, newHelper: selfHelper)).isEmpty)
  let boundHelper = "struct Receipt {}\nfunc prior<Receipt>() -> Receipt { Receipt(value: 1) }"
  #expect(try resultEntries(resultReport("func fresh() -> Receipt { Receipt(value: 2) }", oldHelper: boundHelper, newHelper: boundHelper)).isEmpty)
}

@Test func aliasesQualifiedReturnNamesAndNominalCollisionsRemainExcluded() throws {
  for helper in ["typealias Receipt = Int\nfunc prior() -> Receipt { Receipt(value: 1) }",
    resultHelper + "\ntypealias Receipt = Int", resultHelper + "\nstruct Other { struct Receipt {} }"] {
    let report = try resultReport("func fresh() -> Receipt { Receipt(value: 2) }", oldHelper: helper, newHelper: helper)
    #expect(resultEntries(report).isEmpty)
    #expect(report.skipped.contains { $0.reason == "result:nominal-name-unknown" })
  }
  #expect(try resultEntries(resultReport("func fresh() -> Namespace.Receipt { Receipt(value: 2) }")).isEmpty)
}

@Test func targetReturnShadowIsConservativelyExcluded() throws {
  let helper = resultHelper.replacingOccurrences(of: "return Receipt(value: 1)", with: "let Receipt = factory; return Receipt(value: 1)")
  #expect(try resultEntries(resultReport("func fresh() -> Receipt { Receipt(value: 2) }", oldHelper: helper, newHelper: helper)).isEmpty)
}

@Test func defaultsLocalFunctionAndLocalTypeCallsDoNotBelongToCallerBody() throws {
  for caller in ["func fresh(_ value: Receipt = Receipt(value: 2)) -> Receipt { fallback() }",
    "func fresh() -> Receipt { func local() { Receipt(value: 2) }; return fallback() }",
    "func fresh() -> Receipt { struct Local { var value = Receipt(value: 2) }; return fallback() }"] {
    #expect(try resultEntries(resultReport(caller)).isEmpty)
  }
  let entry = try #require(resultEntries(resultReport("func fresh() -> Receipt { consume({ Receipt(value: 2) }); return fallback() }")).first)
  #expect(entry.eligibleOccurrences == 1)
}

@Test func existingProducerMustBeFullyUnchangedAndUniquelyPaired() throws {
  let caller = "func fresh() -> Receipt { Receipt(value: 2) }"
  for helper in [resultHelper.replacingOccurrences(of: "value: 1", with: "value: 3"),
    resultHelper.replacingOccurrences(of: "func prior", with: "@available(*, deprecated) func prior"),
    resultHelper + "\nfunc prior() -> Receipt { Receipt(value: 1) }"] {
    #expect(try resultEntries(resultReport(caller, newHelper: helper)).isEmpty)
  }
  let old = "struct Receipt {}\nstruct Box<T: P> { func prior() -> Receipt { Receipt(value: 1) } }"
  let new = old.replacingOccurrences(of: "T: P", with: "T: Q")
  let report = try resultReport(caller, oldHelper: old, newHelper: new)
  #expect(resultEntries(report).isEmpty)
  #expect(report.skipped.contains { $0.reason == "result:target-scope-header-changed" })
  #expect(try resultEntries(resultReport(caller, oldHelper: "", newHelper: resultHelper)).isEmpty)
}

@Test func resultConditionalPathsAreKeptOnBothSides() throws {
  let helper = """
  struct Receipt {}
  func prior() -> Receipt {
  #if A
    return Receipt(value: 1)
  #else
    return Receipt(value: 1)
  #endif
  }
  """
  let caller = """
  #if OUTER
  func fresh() -> Receipt {
  #if false
    return Receipt(value: 2)
  #else
    return Receipt(value: 2)
  #endif
  }
  #endif
  """
  let report = try resultReport(caller, oldHelper: helper, newHelper: helper)
  let entries = resultEntries(report)
  #expect(entries.count == 4)
  #expect(entries.map { $0.anchorCall.site.line } == [4, 4, 6, 6])
  #expect(entries.map { $0.targetCall.site.line } == [4, 6, 4, 6])
  #expect(entries.allSatisfy { $0.anchorCall.writtenConditions.count == 2 && $0.targetCall.writtenConditions.count == 1 })
  #expect(report.text().contains("入口条件の記載") && report.text().contains("既存条件の記載"))
  #expect(report.text().contains("#if false [Caller.swift:3]") && report.text().contains("#else [Helper.swift:5]"))
}

@Test func returnOccurrenceCountsDoNotImplyEqualValues() throws {
  let helper = resultHelper.replacingOccurrences(of: "return Receipt(value: 1)", with: "Receipt(value: 1); return Receipt(value: 9)")
  let entry = try #require(resultEntries(resultReport("func fresh() -> Receipt { Receipt(value: 2); return Receipt(value: 3) }", oldHelper: helper, newHelper: helper)).first)
  #expect(entry.eligibleOccurrences == 2 && entry.targetOccurrences == 2)
}

@Test func multipleExistingProducersAreCandidatesNotArbitrarilyChosen() throws {
  let helper = resultHelper + "\nfunc other() -> Receipt { Receipt(value: 7) }"
  let report = try resultReport("func fresh() -> Receipt { Receipt(value: 2) }", oldHelper: helper, newHelper: helper)
  #expect(report.contexts.count == 2 && resultEntries(report).count == 2)
}

@Test func memberAndResultPathsShareTargetKeyAndCaps() throws {
  let h = "struct Receipt {}\nstruct Maker { func make() -> Receipt { Receipt(value: 1) } }"
  let report = try resultReport("func fresh() -> Receipt { maker.make(); return Receipt(value: 2) }", oldHelper: h, newHelper: h)
  #expect(report.contexts.count == 1 && report.contexts[0].entries.count == 2)
  #expect(resultEntries(report).count == 1)
  let many = "struct Receipt {}\n" + (0..<9).map { "func prior\($0)() -> Receipt { Receipt(value: 1) }" }.joined(separator: "\n")
  let capped = try resultReport("func fresh() -> Receipt { Receipt(value: 2) }", oldHelper: many, newHelper: many)
  #expect(capped.contexts.count == 8 && capped.omittedTargets == 1)
  let callers = (0..<10).map { "func fresh\($0)() -> Receipt { Receipt(value: 2) }" }.joined(separator: "\n")
  let cappedEntries = try resultReport(callers)
  #expect(cappedEntries.contexts[0].entries.count == 8 && cappedEntries.contexts[0].omittedEntries == 2)
}

@Test func resultInputOrderingAndTriviaHaveStableEvidence() throws {
  let before = [("Caller.swift", ""), ("Helper.swift", resultHelper)]
  let after = [("Caller.swift", "func fresh() -> Receipt { Receipt(value: 2) }"), ("Helper.swift", resultHelper)]
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  #expect(try encoder.encode(UnchangedContext.compare(before: before, after: after)) == encoder.encode(UnchangedContext.compare(before: before.reversed(), after: after.reversed())))
  #expect(try resultEntries(resultReport("func fresh() -> Receipt { Receipt(value: 2) }", newHelper: "// trivia\n" + resultHelper)).count == 1)
}
