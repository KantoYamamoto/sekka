import Foundation
import Testing
@testable import StructuralContext

private func typedReport(_ before: String, _ after: String, declarations: String, afterDeclarations: String? = nil) throws -> ContextReport {
  try UnchangedContext.compare(before: [("Use.swift", before), ("Types.swift", declarations)],
    after: [("Use.swift", after), ("Types.swift", afterDeclarations ?? declarations)])
}
private func property(_ type: String) -> String { "struct Store { var value: \(type) }" }

@Test func changedGenericAnnotationReachesAttributedConformingDeclaration() throws {
  let target = "@available(*, deprecated) struct OrderedMap<K, V>: Sendable {}\nstruct Entry {}"
  let report = try typedReport(property("[Entry]"), property("OrderedMap<String, Entry>"), declarations: target)
  let result = try #require(report.contexts.first)
  #expect(report.contexts.count == 1)
  #expect(result.kind == "struct")
  #expect(result.after.declaration == "OrderedMap")
  #expect(result.fileUnchanged)
  #expect(result.entries.first?.typeChange?.reference.name == "OrderedMap")
  #expect(result.entries.first?.typeChange?.beforeType == "[ Entry ]")
  #expect(report.changedTypeAnnotations == 1)
}

@Test func genericArgumentChangeDoesNotReintroduceContainerName() throws {
  let report = try typedReport(property("Box<A>"), property("Box<B>"), declarations: "struct Box<T> {}; struct A {}; struct B {}")
  #expect(report.contexts.map(\.after.declaration) == ["B"])
  #expect(report.contexts.first?.entries.first?.typeChange?.reference.written == "B")
}

@Test func qualifiedNameChangeIsTerminalNameSearchNotOwnerResolution() throws {
  let types = "enum Left { struct Item {} }; enum Right { struct Item {} }"
  let report = try typedReport(property("Left.Item"), property("Right.Item"), declarations: types)
  #expect(Set(report.contexts.map(\.after.declaration)) == ["Left.Item", "Right.Item"])
  #expect(report.contexts.allSatisfy { $0.entries.first?.typeChange?.reference.written == "Right.Item" })
  #expect(report.contexts.allSatisfy { $0.entries.first?.typeChange?.matchingDeclarations == 2 })
  #expect(report.text().contains("型の解決ではない"))
}

@Test func sameNameDeclarationsArePairedSeparatelyAndChangedOneExcluded() throws {
  let before = [("Use.swift", property("Int")), ("A.swift", "struct Item {}"), ("B.swift", "struct Item {}")]
  let after = [("Use.swift", property("Item")), ("A.swift", "struct Item { var extra: Int }"), ("B.swift", "struct Item {}")]
  let report = try UnchangedContext.compare(before: before, after: after)
  #expect(report.contexts.map(\.after.file) == ["B.swift"])
  #expect(report.skipped.contains { $0.reason == "type:declaration-changed" })
}

@Test func conditionalDuplicateDeclarationsAndPropertiesStayAmbiguous() throws {
  let types = "#if A\nstruct Item {}\n#else\nstruct Item {}\n#endif"
  let report = try typedReport(property("Int"), property("Item"), declarations: types)
  #expect(report.contexts.isEmpty)
  #expect(report.skipped.contains { $0.reason == "type:declaration-correspondence-ambiguous" })
  let before = "struct Store {\n#if A\nvar value: Int\n#else\nvar value: Int\n#endif\n}"
  let after = before.replacingOccurrences(of: "Int", with: "Item")
  let duplicateProperty = try typedReport(before, after, declarations: "struct Item {}")
  #expect(duplicateProperty.contexts.isEmpty)
  #expect(duplicateProperty.skipped.contains { $0.reason == "type:property-correspondence-ambiguous" })
}

@Test func aliasIsShownWithoutFollowingItsExpansion() throws {
  let report = try typedReport(property("Int"), property("Choice"), declarations: "struct Actual {}; typealias Choice = Actual")
  #expect(report.contexts.map(\.after.declaration) == ["Choice"])
  #expect(report.contexts.first?.kind == "typealias")
}

@Test func knownGenericParametersDoNotPointAtUnrelatedNamedTypes() throws {
  for type in ["T", "T.Item"] {
    let report = try typedReport("struct Store<T> { var value: Int }", "struct Store<T> { var value: \(type) }",
      declarations: "struct T {}; struct Item {}")
    #expect(report.contexts.isEmpty)
    #expect(report.skipped.contains { $0.reason == "type:bound-type-reference" })
  }
}

@Test func optionalArrayTupleNamesAndNewAnnotationRemainWrittenFacts() throws {
  let report = try typedReport("struct Store { var value = make() }", property("(Item?, [Other])"), declarations: "struct Item {}; struct Other {}")
  #expect(Set(report.contexts.map(\.after.declaration)) == ["Item", "Other"])
  #expect(report.contexts.allSatisfy { $0.entries.first?.typeChange?.beforeProperty != nil && $0.entries.first?.typeChange?.beforeType == nil })
}

@Test func extensionChangeDoesNotBecomeWholeTypeUnchangedGuarantee() throws {
  let before = "struct Item {}\nextension Item { func run() { old() } }"
  let after = "struct Item {}\nextension Item { func run() { new() } }"
  let report = try typedReport(property("Int"), property("Item"), declarations: before, afterDeclarations: after)
  #expect(report.contexts.map(\.after.declaration) == ["Item"])
  #expect(report.contexts.first?.fileUnchanged == false)
  #expect(report.text().contains("型全体の保証ではありません"))
}

@Test func typeAndMemberTargetsShareOneListButAreDistinctDeclarations() throws {
  let before = "struct Screen { let logger: Logger; var a: Int; var b: Int; func run(_ event: String) { logger.record(event) } }"
  let after = before.replacingOccurrences(of: "a: Int", with: "a: Logger").replacingOccurrences(of: "b: Int", with: "b: Logger")
    .replacingOccurrences(of: "logger.record(event)", with: "logger.record(event); analytics.record(event)")
  let report = try typedReport(before, after, declarations: "struct Logger { func record(_ event: String) { send(event) } }")
  #expect(report.contexts.count == 2)
  #expect(report.contexts.first(where: { $0.kind == "struct" })?.entries.count == 2)
  #expect(report.contexts.first(where: { $0.kind == "function" })?.entries.first?.call != nil)
  #expect(report.text().components(separatedBy: "┌ 未変更の宣言候補").count == 3)
}

@Test func initializerChangeAndNewTargetAreNotUnchangedContext() throws {
  let report = try typedReport("struct Store { var value: Item = a() }", "struct Store { var value: Item = b() }", declarations: "struct Item {}")
  #expect(report.contexts.isEmpty)
  let newTarget = try typedReport(property("Int"), property("Item"), declarations: "", afterDeclarations: "struct Item {}")
  #expect(newTarget.contexts.isEmpty)
  #expect(newTarget.skipped.contains { $0.reason == "type:no-before-declaration" })
}

@Test func typedTargetCapsAndOrderingRemainDeterministic() throws {
  let types = (0..<10).map { ("Type\($0).swift", "struct Item {}") }
  let before = types + [("Use.swift", property("Int"))], after = types + [("Use.swift", property("Item"))]
  let report = try UnchangedContext.compare(before: before, after: after)
  #expect(report.contexts.count == 8)
  #expect(report.omittedTargets == 2)
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  #expect(try encoder.encode(report) == encoder.encode(UnchangedContext.compare(before: before.reversed(), after: after.reversed())))
}

@Test func unchangedAmbiguousAnnotationsAreNotRepeatedAsSearchOmissions() throws {
  let before = "struct Store {\n#if A\nvar value: Int\n#else\nvar value: Int\n#endif\n}"
  let report = try typedReport(before, "// unrelated trivia\n" + before, declarations: "struct Item {}")
  #expect(report.changedTypeAnnotations == 0)
  #expect(report.skipped.isEmpty)
}

@Test func associatedTypeBindingsAndPlaceholderTypesStayUnknown() throws {
  for owner in ["protocol Store<T> { associatedtype T;", "protocol Store { associatedtype T;"] {
    for type in ["T", "Self.T"] {
      let report = try typedReport(owner + " var value: Int { get } }", owner + " var value: \(type) { get } }", declarations: "struct T {}")
      #expect(report.contexts.isEmpty)
      #expect(report.skipped.contains { $0.reason == "type:bound-type-reference" })
    }
  }
  let placeholder = try typedReport(property("Int"), property("_"), declarations: "struct Item {}")
  #expect(placeholder.contexts.isEmpty)
  #expect(placeholder.skipped.contains { $0.reason == "type:placeholder-type" })
  #expect(!placeholder.skipped.contains { $0.reason == "type:no-matching-declaration" })
}

@Test func unindexedOldPropertyIsNotDeclaredNonexistent() throws {
  let before = "struct Store {}\nextension Store { var value: Item { Item() } }"
  let report = try typedReport(before, property("Item"), declarations: "struct Item {}")
  let entry = try #require(report.contexts.first?.entries.first?.typeChange)
  #expect(entry.beforeStatus == "no-indexed-counterpart")
  #expect(report.text().contains("旧版索引に対応なし"))
  #expect(!report.text().contains("宣言なし"))
}
