import Foundation
import Testing

@testable import PatchworkCore

private func snapshot(_ source: String, path: String = "App.swift") throws -> Snapshot {
  try Analyzer.analyze([(path, source)])
}

private func delta(_ before: String, _ after: String) throws -> DiffReport {
  try Differ.compare(snapshot(before), snapshot(after), beforeLabel: "before", afterLabel: "after")
}

@Test func formattingAndCommentsDoNotGenerateObservations() throws {
  let report = try delta(
    "struct A { let value: Int; func f(_ x: Int) -> Int { x + 1 } }",
    """
    // A comment should not change structure.
    struct A {
        let value : Int
        func f(_ x: Int) -> Int {
            // Different whitespace and a literal-only change.
            x + 2
        }
    }
    """)
  #expect(report.findings.isEmpty)
}

@Test func addedReferencesAndEnumCasesAreVisible() throws {
  let report = try delta(
    "enum Payment { case cash }; struct VM { let repo: Repo }",
    "enum Payment { case cash, card(Card) }; struct VM { let repo: Repo; let analytics: Analytics }"
  )
  #expect(
    report.findings.contains {
      $0.rule == "type-references-changed" && $0.after.contains("Analytics")
    })
  #expect(report.findings.contains { $0.rule == "members-changed" && $0.type == "Payment" })
}

@Test func nestedDeclarationsAndExtensionsAreSeparate() throws {
  let scan = try snapshot(
    "struct A { struct B {} }; struct C { struct B {} }; extension A { func f() {} }; extension A { func g() {} }"
  )
  #expect(scan.types.map(\.name).contains("A.B"))
  #expect(scan.types.map(\.name).contains("C.B"))
  #expect(scan.types.filter { $0.kind == "extension" }.count == 2)
  #expect(Set(scan.types.map(\.id)).count == scan.types.count)
  #expect(scan.notices.count == 1)
}

@Test func sameNamesInDifferentFilesDoNotMerge() throws {
  let scan = try Analyzer.analyze([("One.swift", "struct A {}"), ("Two.swift", "struct A {}")])
  #expect(scan.types.count == 2)
  #expect(Set(scan.types.map(\.id)).count == 2)
}

@Test func inferredTypesAreNotInvented() throws {
  let scan = try snapshot(
    "struct A { let service = Service(); let known: Box<User>; let existential: any Store }")
  let references = scan.types[0].referencedTypeSpellings
  #expect(!references.contains("Service"))
  #expect(references.contains("Box < User >"))
  #expect(references.contains("any Store"))
}

@Test func malformedSourceFailsInsteadOfAppearingClean() {
  #expect(throws: PatchworkError.self) { try snapshot("struct {") }
}

@Test func conditionalDeclarationsRemainExplicitlyUnresolved() throws {
  let scan = try snapshot(
    """
    #if DEBUG
    struct A { let debug: Debug }
    #else
    struct A { let live: Live }
    #endif
    """)
  #expect(scan.types.count == 2)
  #expect(!scan.notices.isEmpty)
}

@Test func directForwardingRejectsTransformationsAndExtraStatements() throws {
  let scan = try snapshot(
    """
    struct A {
        func forward(_ x: Int) { service.send(x) }
        func transform(_ x: Int) { service.send(x + 1) }
        func extra(_ x: Int) { print(x); service.send(x) }
        func missing(_ x: Int, _ y: Int) { service.send(x) }
        func factory(_ x: Int) { makeService().send(x) }
    }
    """)
  let forwarding = scan.types[0].members.filter { $0.forwardingCall != nil }
  #expect(forwarding.count == 1)
  #expect(forwarding.first?.key.hasPrefix("func forward") == true)
}

@Test func isolationSyntaxChangesRemainFacts() throws {
  let report = try delta(
    "final class A { func f() {} }", "@MainActor final class A { nonisolated func f() {} }")
  #expect(
    report.findings.contains {
      $0.rule == "type-header-changed" && $0.after[0].contains("MainActor")
    })
  #expect(
    report.findings.contains { $0.rule == "members-changed" && $0.after[0].contains("nonisolated") }
  )
}

@Test func bodyMetricsSeparateExplicitSelfWritesFromLocalWrites() throws {
  let report = try delta(
    "struct A { func f() {} }",
    "struct A { func f() { var local = 0; local = 1; if flag { self.value = local }; items.map { $0 } } }"
  )
  let finding = try #require(report.findings.first { $0.rule == "body-structure-changed" })
  #expect(finding.after.contains("explicit self.property = sites: 1"))
  #expect(finding.after.contains("control-flow sites: 1"))
  #expect(finding.after.contains("closures: 1"))
}

@Test func inheritanceIsNotMislabelledAsConformance() throws {
  let scan = try snapshot("class A: B, C {}")
  #expect(scan.types[0].references.allSatisfy { $0.role == "inheritance-clause" })
}

@Test func githubOutputEscapesUntrustedSource() throws {
  let report = try Differ.compare(
    snapshot(""), snapshot("struct A {}", path: "a,b\n::error::oops.swift"), beforeLabel: "old",
    afterLabel: "new")
  let text = Renderer.github(report)
  #expect(text.contains("%2C"))
  #expect(text.contains("%0A"))
  #expect(!text.contains("\n::error::"))
}

@Test func deterministicJSONAndFileOrder() throws {
  let files = [(path: "B.swift", source: "struct B {}"), (path: "A.swift", source: "struct A {}")]
  #expect(
    try Renderer.json(Analyzer.analyze(files)) == Renderer.json(Analyzer.analyze(files.reversed())))
}

@Test func directoryExclusionsAndSymlinks() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(
    at: root.appendingPathComponent(".build"), withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  try "struct A {}".write(
    to: root.appendingPathComponent("A.swift"), atomically: true, encoding: .utf8)
  try "broken {".write(
    to: root.appendingPathComponent(".build/Skip.swift"), atomically: true, encoding: .utf8)
  try FileManager.default.createSymbolicLink(
    atPath: root.appendingPathComponent("Link.swift").path,
    withDestinationPath: root.appendingPathComponent("A.swift").path)
  #expect(try Inputs.directory(root.path).map(\.path) == ["A.swift"])
  #expect(try Inputs.directory(root.path, excluding: ["A.swift"]).isEmpty)
}
