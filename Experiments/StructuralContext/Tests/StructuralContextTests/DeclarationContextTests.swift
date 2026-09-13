import Foundation
import Testing
@testable import StructuralContext

private func compare(_ before: String, _ after: String) throws -> ContextReport {
  try DeclarationContext.compare(before: [("Input.swift", before)], after: [("Input.swift", after)])
}

@Test func constructionAcrossPropertyAndExistingMethod() throws {
  let before = "struct Menu { func open() { Picker(source: Source(service: Service())); Welcome() } }"
  let report = try compare(before, before + "\nstruct Sheet { var body: View { Welcome(); Picker(source: Source(service: Service())) } }")
  let context = try #require(report.contexts.first { $0.after.declaration == "Sheet.body" })
  #expect(context.before.isEmpty)
  #expect(context.sharedCalls.first?.before.site.declaration == "Menu.open()")
  #expect(context.sharedCalls.first?.before.spellings == ["Picker(source:)", "Service()", "Source(service:)", "Welcome()"])
  #expect(context.sharedCalls.first?.after.first?.site.line == 1)
}

@Test func existingSharedEntryAndGenericOwner() throws {
  let before = "class Work<T> { func decode(_ data: Data, decoder: Decoder, _ done: () -> Void) {} }\nfunc disk() { decode(data, decoder: d) {} }\nfunc network() { task.decode(data, decoder: d) {} }"
  let report = try compare(before, before.replacingOccurrences(of: "-> Void) {}", with: "-> Void) { await run() }"))
  let context = try #require(report.contexts.first)
  #expect(report.selectorGroups.first?.selector == "decode(_:decoder:_:)" )
  #expect(report.selectorGroups.first?.before.count == 2)
  #expect(report.selectorGroups.first?.after.count == 2)
  #expect(report.selectorGroups.first?.after.map(\.expression) == ["decode", "task . decode"])
  #expect(report.selectorGroups.first?.declarationCandidates.count == 1)
}

@Test func sameInputAndTriviaProduceNoChange() throws {
  let code = "func old() { a(); b() }"
  #expect(try compare(code, code).changedDeclarations == 0)
  #expect(try compare(code, "// comment\nfunc old() {\n a() ; b()\n}").changedDeclarations == 0)
}

@Test func overloadAndDuplicateIdentityAreNotPaired() throws {
  let before = "func run(_ x: Int) {}\nfunc run(_ x: String) {}"
  let report = try compare(before, before + "\nfunc caller() { run(1) }")
  #expect(report.ambiguous.isEmpty)
  #expect(report.contexts.isEmpty)
}

@Test func localShadowRemainsADeclarationCandidate() throws {
  let before = "func work(_ x: Int) {}\nfunc outer() { func work(_ x: Int) {} ; work(1) }"
  let report = try compare(before, before.replacingOccurrences(of: "func work(_ x: Int) {}\n", with: "func work(_ x: Int) { changed() }\n"))
  let incoming = try #require(report.selectorGroups.first)
  #expect(incoming.declarationCandidates.map(\.declaration) == ["work(_:)", "outer().work(_:)"])
  #expect(incoming.after.first?.site.declaration == "outer()")
}

@Test func nestedBodyIsNotAttributedToOuter() throws {
  let before = "func old() { a(); b() }"
  let report = try compare(before, before + "\nfunc outer() { func inner() { a(); b() } }")
  #expect(report.contexts.map { $0.after.declaration } == ["outer().inner()"])
  #expect(report.withoutContext.map(\.declaration) == ["outer()"])
}

@Test func propertiesHaveOwnCallsAndLocalVariablesStayInFunction() throws {
  let before = "func old() { A(); B() }"
  let report = try compare(before, before + "\nstruct View { var body: Any { let local = A(); return B() } }\nfunc make() { let value = A(); B() }")
  #expect(report.contexts.map { $0.after.declaration } == ["View.body", "make()"])
  #expect(report.changedDeclarations == 2)
}

@Test func commonCallsAreCandidatesNotWarningsAndAreCapped() throws {
  let before = (0..<5).map { "func old\($0)() { print(1); String(1) }" }.joined(separator: "\n")
  let report = try compare(before, before + "\nfunc new() { print(2); String(2) }")
  let context = try #require(report.contexts.first)
  #expect(context.sharedCalls.count == 3)
  #expect(context.omittedNeighbors == 2)
  #expect(context.sharedCalls.first?.before.spellings == ["String(_:)", "print(_:)"])
  #expect(report.limitations.contains { $0.contains("Common APIs may produce noise") })
}

@Test func incomingUseCapIsCountedPerSide() throws {
  let before = "func target() {}\n" + (0..<10).map { "func use\($0)() { target() }" }.joined(separator: "\n")
  let report = try compare(before, before.replacingOccurrences(of: "target() {}", with: "target() { changed() }"))
  let incoming = try #require(report.selectorGroups.first)
  #expect(incoming.before.count == 8 && incoming.after.count == 8)
  #expect(incoming.omittedBefore == 2 && incoming.omittedAfter == 2)
}

@Test func removedNeighborAndSameFileNameScopeRemainVisible() throws {
  let before = "func old() { a(); b() }"
  let report = try compare(before, "func new() { a(); b() }")
  #expect(report.contexts.first?.sharedCalls.first?.after.isEmpty == true)
  #expect(report.contexts.first?.sharedCalls.first?.before.site.declaration == "old()")
}

@Test func argumentLabelsAndTrailingClosuresAreWrittenNotResolved() throws {
  let before = "func target(completion: () -> Void) {}\nfunc old() { target {} }"
  let report = try compare(before, before.replacingOccurrences(of: "Void) {}", with: "Void) { change() }"))
  #expect(report.contexts.isEmpty)
  #expect(report.withoutContext.first?.declaration == "target(completion:)")
}

@Test func conditionalOverloadsRemainAmbiguous() throws {
  let code = "#if FLAG\nfunc hook() {}\n#else\nfunc hook() {}\n#endif"
  let report = try compare(code, code.replacingOccurrences(of: "hook() {}", with: "hook() { changed() }"))
  #expect(report.ambiguous.count == 2)
}

@Test func malformedInputFailsBeforeReport() throws {
  #expect(throws: ContextError.self) { try compare("struct {", "func valid() {}") }
}

@Test func fileOrderingAndEncodingAreDeterministic() throws {
  let old = [("B.swift", "func old() { A(); B() }"), ("A.swift", "struct Other {}")]
  let new = old + [("C.swift", "func new() { B(); A() }")]
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  let a = try encoder.encode(DeclarationContext.compare(before: old, after: new))
  let b = try encoder.encode(DeclarationContext.compare(before: old.reversed(), after: new.reversed()))
  #expect(a == b)
}

@Test func receiverSpellingPreventsBareSelectorSimilarity() throws {
  let before = "func old() { left.clean(); left.trim() }"
  let report = try compare(before, before + "\nfunc new() { right.clean(); right.trim() }")
  #expect(report.contexts.isEmpty)
}

@Test func changedOverloadKeepsSameSelectorAmbiguityVisible() throws {
  let before = "func run(_ x: Int) {}\nfunc run(_ x: String) {}\nfunc caller() { run(1) }"
  let report = try compare(before, before.replacingOccurrences(of: "x: Int) {}", with: "x: Int) { changed() }"))
  #expect(report.changedDeclarations == 1)
  #expect(report.selectorGroups.first?.declarationCandidates.count == 2)
}

@Test func compilationConditionIsNotAnExecutedCallSpelling() throws {
  let before = "func old() { #if os(macOS)\n a()\n #endif\n }"
  let report = try compare(before, before + "\nfunc new() { #if os(macOS)\n a()\n #endif\n }")
  #expect(report.contexts.isEmpty)
}

@Test func matchingSelectorGroupIsNotRepeatedForOverloads() throws {
  let before = "func run(_ x: Int) {}\nfunc run(_ x: String) {}\nfunc caller() { run(1) }"
  let report = try compare(before, before.replacingOccurrences(of: ") {}", with: ") { changed() }"))
  #expect(report.contexts.count == 2)
  #expect(report.selectorGroups.count == 1)
  #expect(report.contexts.allSatisfy { $0.sameSelector == "run(_:)" })
}

@Test func implicitBasesDoNotCreateSharedResponsibilityCandidates() throws {
  let before = "func old() { finish(.success(1)); end(.failure(2)) }"
  let report = try compare(before, before + "\nfunc new() { other(.success(3)); another(.failure(4)) }")
  #expect(report.contexts.isEmpty)
}

@Test func textGroupsUsesOnceAndShowsLimits() throws {
  let before = "func run(_ x: Int) {}\nfunc run(_ x: String) {}\nfunc caller() { run(1) }"
  let report = try compare(before, before.replacingOccurrences(of: ") {}", with: ") { changed() }"))
  let text = report.text()
  #expect(text.components(separatedBy: "┌ 同じ名前・引数ラベル:").count == 2)
  #expect(text.contains("宣言候補 2件"))
  #expect(text.contains("呼び出し先は未解決"))
  #expect(text.contains("before Input.swift:3"))
}

@Test func textEscapesControlCharactersInPaths() throws {
  let report = try DeclarationContext.compare(before: [], after: [("A\nB.swift", "func new() {}")])
  #expect(report.text().contains("A\\u{a}B.swift:1"))
}

@Test func selectorGroupIncludesRecursiveUsesAcrossAllAnchors() throws {
  let before = "func run(_ x: Int) { run(x) }\nfunc run(_ x: String) { run(x) }"
  let report = try compare(before, before.replacingOccurrences(of: "run(x)", with: "changed(); run(x)"))
  #expect(report.selectorGroups.count == 1)
  #expect(report.selectorGroups.first?.before.count == 2)
  #expect(report.selectorGroups.first?.after.count == 2)
}

@Test func sameLineNeighborsAreNotInsideEachOther() throws {
  let before = "func old() { a(); b() }; func target() { a() }"
  let after = "func old() { a(); b() }; func target() { a(); b() }"
  let report = try compare(before, after)
  #expect(report.contexts.first?.sharedCalls.first?.before.site.declaration == "old()")
}

@Test func observerPropertyIncludesInitializerAndObserver() throws {
  let before = "func old() { a(); b() }"
  let report = try compare(before, before + "\nvar value = a() { didSet { b() } }")
  #expect(report.contexts.first?.after.declaration == "value")
  #expect(report.contexts.first?.sharedCalls.first?.before.spellings == ["a()", "b()"])
}

@Test func propertyLocalFunctionIsNotPairedWithFileFunction() throws {
  let before = "func helper() { a(); b() }"
  let report = try compare(before, "var value: Int { func helper() { a(); b() }; return 0 }")
  let local = try #require(report.contexts.first { $0.after.declaration == "value.helper()" })
  #expect(local.before.isEmpty)
  #expect(local.sharedCalls.first?.before.site.declaration == "helper()")
}

@Test func localTypePropertyIsIndexedButDeinitLocalIsNot() throws {
  let before = "func old() { a(); b() }"
  let report = try compare(before, before + "\nfunc outer() { struct Local { var value: Int { a(); b() } } }\nclass Owner { deinit { let local = a(); b() } }")
  #expect(report.contexts.contains { $0.after.declaration == "outer().Local.value" })
  #expect(!report.withoutContext.contains { $0.declaration == "Owner.local" })
  #expect(!report.contexts.contains { $0.after.declaration == "Owner.local" })
}

@Test func extractedHelperDoesNotImplyRemainingDuplicateCalls() throws {
  let before = "func old() { a(); b() }"
  let report = try compare(before, "func old() { shared() }; func shared() { a(); b() }")
  let context = try #require(report.contexts.first { $0.after.declaration == "shared()" })
  #expect(context.sharedCalls.first?.before.spellings == ["a()", "b()"])
  #expect(context.sharedCalls.first?.after.first?.spellings.isEmpty == true)
  #expect(report.text().contains("共通表記なし"))
}
