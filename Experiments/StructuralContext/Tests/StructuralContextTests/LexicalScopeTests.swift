import Testing
@testable import StructuralContext

private func lexical(_ source: String) throws -> SourceInventory {
  try SourceInventory(files: [("Input.swift", source)])
}
private func delta(_ before: String, _ after: String) throws -> ContextReport {
  try UnchangedContext.compare(before: [("Input.swift", before)], after: [("Input.swift", after)])
}

@Test func fileAndExtensionFunctionsAreRecordedWithoutLookupEligibility() throws {
  let before = "func run() { old() }\nstruct S { func run() {} }\nextension S { func work() { old() } }"
  let value = try lexical(before)
  #expect(value.functions.count == 3)
  #expect(Set(value.functions.map(\.id)).count == 3)
  let extensionFunction = try #require(value.functions.first { $0.scopeKind == "extension" })
  #expect(extensionFunction.site.line == 3)
  #expect(value.scopes.first { $0.id == extensionFunction.ownerID }?.headerTokens == "extension S")
  #expect(value.memberCandidate(callerID: extensionFunction.id, receiver: "service", selector: "work()").evidence == nil)
  let report = try delta(before, before.replacingOccurrences(of: "old()", with: "new()"))
  #expect(report.changedFunctions == 2)
  #expect(report.unpairedBefore == 0 && report.unpairedAfter == 0)
  #expect(report.contexts.isEmpty)
  #expect(report.skipped.contains { $0.reason == "unsupported-caller-scope" && $0.count == 2 })
}

@Test func extensionHeadersPairWithoutLineIdentity() throws {
  let before = "extension Box where T: P { func run() { old() } }"
  let after = "\n\n" + before.replacingOccurrences(of: "old()", with: "new()")
  #expect(try delta(before, after).changedFunctions == 1)
  let alteredConstraint = try delta(before, after.replacingOccurrences(of: "T: P", with: "T: Q"))
  #expect(alteredConstraint.changedFunctions == 0)
  #expect(alteredConstraint.unpairedBefore == 1 && alteredConstraint.unpairedAfter == 1)
  let separate = try lexical(before + "\nextension Box where T: Q { func run() {} }")
  #expect(Set(separate.functions.map(\.correspondenceID)).count == 2)
}

@Test func duplicateExtensionScopesRemainAmbiguousEvenForDifferentMembers() throws {
  let source = "extension S { func a() {} }\nextension S { func b() {} }"
  let value = try lexical(source)
  #expect(value.functions.count == 2)
  #expect(value.functions.allSatisfy { !value.hasUniqueScope($0) })
  let report = try delta(source, source)
  #expect(report.unpairedBefore == 2 && report.unpairedAfter == 2)
  let overload = try delta("extension S { func run(_ a: Int) {}; func run(_ b: Int) {} }", "extension S { func run(_ a: Int) {}; func run(_ b: Int) {} }")
  #expect(overload.unpairedBefore == 2 && overload.unpairedAfter == 2)
}

@Test func extensionNestedNominalsKeepAncestryAndStayOutsideTypeQuery() throws {
  let source = "struct Inner { func run() {} }\nextension Outer { struct Inner { var value: Buffer; func run() {} } }\nstruct Buffer {}"
  let value = try lexical(source)
  #expect(value.functions.count == 2 && Set(value.functions.map(\.id)).count == 2)
  #expect(value.types.filter { $0.name == "Inner" }.count == 1)
  #expect(value.properties.isEmpty)
  let before = source.replacingOccurrences(of: "var value: Buffer;", with: "")
  #expect(try delta(before, source).contexts.isEmpty)
  let duplicate = try lexical("extension Outer { struct A { func a() {} } }\nextension Outer { struct B { func b() {} } }")
  #expect(duplicate.functions.allSatisfy { !duplicate.hasUniqueScope($0) })
}

@Test func writtenConditionalPathPairsWithoutSelectingActiveBranches() throws {
  let before = "#if A\nextension S { func run() { old() } }\n#else\nextension S { func run() {} }\n#endif"
  let after = before.replacingOccurrences(of: "old()", with: "new()")
  let value = try lexical(before)
  #expect(value.functions.count == 2)
  #expect(Set(value.functions.map(\.correspondenceID)).count == 2)
  #expect(value.functions.allSatisfy { !$0.conditionalPath.isEmpty })
  let report = try delta(before, after)
  #expect(report.changedFunctions == 1 && report.unpairedAfter == 0)
  #expect(report.contexts.isEmpty)
  #expect(report.skipped.contains { $0.reason == "unsupported-caller-scope" && $0.count == 1 })
  let changedGuard = try delta(before, before.replacingOccurrences(of: "#if A", with: "#if B"))
  #expect(changedGuard.unpairedBefore == 2 && changedGuard.unpairedAfter == 2)
  #expect(try delta(before, "\n" + after.replacingOccurrences(of: "#if A", with: "#if  A")).changedFunctions == 1)
}

@Test func conditionalElseifNestingAndRepeatedBlocksStayDistinct() throws {
  let original = "#if A\n#elseif B\nfunc run() {}\n#endif"
  let changed = try delta(original, original.replacingOccurrences(of: "#if A", with: "#if C"))
  #expect(changed.unpairedBefore == 1 && changed.unpairedAfter == 1)
  let nested = "#if A\n#if B\nfunc run() {}\n#endif\n#endif"
  let reversed = "#if B\n#if A\nfunc run() {}\n#endif\n#endif"
  #expect(try delta(nested, reversed).unpairedAfter == 1)
  #expect(try delta(nested, "func run() {}").unpairedAfter == 1)
  let duplicate = try lexical("#if A\nfunc a() {}\n#endif\n#if A\nfunc b() {}\n#endif")
  #expect(duplicate.functions.allSatisfy { !duplicate.hasUniqueScope($0) })
  let inherited = try lexical("#if A\nextension S { struct Inner { func run() {} } }\n#endif")
  #expect(inherited.functions[0].conditionalPath.count == 1)
  #expect(inherited.functions[0].unsupported.contains("extension-scope"))
}

@Test func executableLocalFunctionsDoNotBecomeFileScopeMembers() throws {
  let value = try lexical("""
  func outer() { func local() {} }
  if flag { func localIf() {} }
  do { func localDo() {} }
  switch flag { default: func localSwitch() {}; struct LocalSwitch { var value: Buffer } }
  let closure = { func localClosure() {} }
  struct S { var value: Int { func localAccessor() {}; return 1 } }
  """)
  #expect(value.functions.map(\.selector) == ["outer()"])
  #expect(value.types.map(\.name) == ["S"])
}
