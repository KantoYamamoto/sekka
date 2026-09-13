import Foundation
import Testing
@testable import StructuralContext

private func compare(_ before: String, _ after: String) throws -> ContextReport {
  try ReferenceDelta.compare(before: [("Input.swift", before)], after: [("Input.swift", after)])
}

@Test func partialMigrationShowsExistingUnchangedContext() throws {
  let old = "func a() { Clock.shared.tick() }; func b() { Clock.shared.tick() }"
  let new = "func a() { Instant() }; func b() { Clock.shared.tick() }"
  let report = try compare(old, new)
  let context = try #require(report.contexts.first)
  #expect(context.spelling == "Clock.shared.tick()")
  #expect(context.reductions.first?.before.count == 1)
  #expect(context.reductions.first?.after.count == 0)
  #expect(context.reductions.first?.increasedReferences.first?.spelling == "Instant()")
  #expect(context.retained.first?.after.declaration.declaration == "b()")
  #expect(context.retained.first?.bodyChanged == false)
  #expect(!report.text().contains("移行漏れあり"))
}

@Test func memberReadHasNoPrefixDuplicates() throws {
  let old = "func a() { let x = ProcessInfo.processInfo.systemUptime }; func b() { let x = ProcessInfo.processInfo.systemUptime }"
  let new = old.replacingOccurrences(of: "func a() { let x = ProcessInfo.processInfo.systemUptime }", with: "func a() { let x = Instant().value }")
  let report = try compare(old, new)
  #expect(report.contexts.map(\.spelling) == ["ProcessInfo.processInfo.systemUptime"])
}

@Test func completeMigrationAndOnlyDeletionHaveNoRetainedContext() throws {
  let old = "func a() { old.clock }; func b() { old.clock }"
  #expect(try compare(old, old.replacingOccurrences(of: "old.clock", with: "new.clock")).contexts.isEmpty)
  let deleted = try compare(old, "func a() { new.clock }")
  #expect(deleted.contexts.isEmpty)
  #expect(deleted.unpairedBefore == 1)
}

@Test func newImplementationIsNotLabeledRetained() throws {
  let report = try compare("func a() { old.clock }", "func a() { new.clock }; func b() { old.clock }")
  #expect(report.contexts.isEmpty)
  #expect(report.unpairedAfter == 1)
}

@Test func intentionalSeparationHasSameFactsNotDefectVerdict() throws {
  let old = "func live() { clock.now }; func legacy() { clock.now }"
  let new = "func live() { other.now }; func legacy() { clock.now }"
  let report = try compare(old, new)
  #expect(report.contexts.count == 1)
  #expect(report.text().contains("移行漏れ・統合必要性は判定しません"))
}

@Test func differentReceiversAndImplicitBaseDoNotUnify() throws {
  #expect(try compare("func a() { first.send() }; func b() { second.send() }", "func a() { replacement() }; func b() { second.send() }").contexts.isEmpty)
  #expect(try compare("func a() { .send() }; func b() { .send() }", "func a() { replacement() }; func b() { .send() }").contexts.isEmpty)
}

@Test func bareCallsDoNotTriggerAndArgumentsAreNotSymbolIdentity() throws {
  #expect(try compare("func a() { send(1) }; func b() { send(2) }", "func a() {}; func b() { send(2) }").contexts.isEmpty)
  let report = try compare("func a() { sink.send(1) }; func b() { sink.send(2) }", "func a() {}; func b() { sink.send(2) }")
  #expect(report.contexts.first?.spelling == "sink.send(_:)")
  #expect(report.limitations.first?.contains("not resolved") == true)
}

@Test func occurrenceDecreaseIsCountNotAnExactRemovedStatement() throws {
  let old = "func a() { x.now; x.now }; func b() { x.now }"
  let report = try compare(old, "func a() { x.now }; func b() { x.now; other() }")
  #expect(report.contexts.first?.reductions.first?.before.count == 2)
  #expect(report.contexts.first?.reductions.first?.after.count == 1)
  #expect(report.contexts.first?.retained.first?.bodyChanged == true)
}

@Test func unchangedAndTriviaInputsAreEmpty() throws {
  let code = "func a() { x.now }; func b() { x.now }"
  #expect(try compare(code, code).contexts.isEmpty)
  #expect(try compare(code, "// comment\n" + code).changedDeclarations == 0)
}

@Test func overloadsPairBySignatureAndDuplicatesRemainUnknown() throws {
  let old = "func a(_ x: Int) { c.now }; func a(_ x: String) { c.now }"
  let report = try compare(old, "func a(_ x: Int) {}; func a(_ x: String) { c.now }")
  #expect(report.contexts.first?.retained.first?.after.declaration.signature?.contains("String") == true)
  let duplicates = try compare("func a() { c.now }; func a() { c.now }; func b() { c.now }", "func a() {}; func a() { c.now }; func b() { c.now }")
  #expect(duplicates.ambiguousKeys == 1)
  #expect(duplicates.contexts.isEmpty)
}

@Test func propertyInitializerAndObserverBothContribute() throws {
  let old = "struct A { var x = c.now { didSet { c.now } }; var y = c.now }"
  let new = "struct A { var x = newer.now { didSet { c.now } }; var y = c.now }"
  let report = try compare(old, new)
  #expect(report.contexts.first?.reductions.first?.before.count == 2)
  #expect(report.contexts.first?.reductions.first?.after.count == 1)
  #expect(report.contexts.first?.retained.first?.after.declaration.declaration == "A.y")
}

@Test func localDeclarationsDoNotDoubleCountOrShareOwner() throws {
  let old = "var property: Int { func f() { c.now }; return 1 }; func f() { c.now }"
  let new = "var property: Int { func f() { new.now }; return 1 }; func f() { c.now }"
  let report = try compare(old, new)
  #expect(report.contexts.first?.reductions.count == 1)
  #expect(report.contexts.first?.reductions.first?.after.declaration.declaration == "property.f()")
  #expect(report.contexts.first?.retained.first?.after.declaration.declaration == "f()")
}

@Test func conditionalBodiesAreReadButConditionsAreNotCalls() throws {
  let old = "func a() { c.now }\n#if os(macOS)\nfunc b() { c.now }\n#endif"
  let report = try compare(old, old.replacingOccurrences(of: "func a() { c.now }", with: "func a() { other.now }"))
  #expect(report.contexts.map(\.spelling) == ["c.now"])
}

@Test func unsupportedDynamicReceiverDoesNotBecomeFalseSimpleChain() throws {
  let old = "func a() { factory().clock.now }; func b() { factory().clock.now }"
  #expect(try compare(old, "func a() {}; func b() { factory().clock.now }").contexts.isEmpty)
}

@Test func capsCarryCountsAndInputOrderIsDeterministic() throws {
  let old = "func a() { c.now }" + (0..<12).map { "; func b\($0)() { c.now }" }.joined()
  let report = try compare(old, old.replacingOccurrences(of: "func a() { c.now }", with: "func a() { n.now }"))
  #expect(report.contexts.first?.retained.count == 8)
  #expect(report.contexts.first?.omittedRetained == 4)
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  let before = [("a.swift", "func a() { c.now }"), ("b.swift", "func b() { c.now }")]
  let after = [("a.swift", "func a() { n.now }"), before[1]]
  #expect(try encoder.encode(ReferenceDelta.compare(before: before, after: after)) == encoder.encode(ReferenceDelta.compare(before: before.reversed(), after: after.reversed())))
}

@Test func malformedInputFailsBeforePartialReportAndTextEscapesControl() throws {
  #expect(throws: ContextError.self) { try ReferenceDelta.compare(before: [], after: [("bad.swift", "struct {")]) }
  let report = try ReferenceDelta.compare(before: [("bad\nname.swift", "func a() { c.now }; func b() { c.now }")], after: [("bad\nname.swift", "func a() {}; func b() { c.now }")])
  #expect(report.text().contains("bad\\u{a}name.swift"))
}

@Test func explicitFunctionValueLabelsAndGenericArgumentsStayDistinct() throws {
  let labeled = try compare("func a() { sink.send(first:) }; func b() { sink.send(second:) }", "func a() {}; func b() { sink.send(second:) }")
  #expect(labeled.contexts.isEmpty)
  let generic = try compare("func a() { sink.send<Int>() }; func b() { sink.send<String>() }", "func a() {}; func b() { sink.send<String>() }")
  #expect(generic.contexts.isEmpty)
  let equal = try compare("func a() { sink.send<Int>() }; func b() { sink.send<Int>() }", "func a() {}; func b() { sink.send<Int>() }")
  #expect(equal.contexts.count == 1)
  #expect(equal.contexts.first?.spelling.contains("Int") == true)
  #expect(equal.contexts.first?.reductions.first?.before.count == 1)
}

@Test func qualifiedTypeArgumentDoesNotTurnBareCallIntoQualifiedReference() throws {
  let report = try compare("func a() { send<Module.Value>() }; func b() { send<Module.Value>() }", "func a() {}; func b() { send<Module.Value>() }")
  #expect(report.contexts.isEmpty)
}
