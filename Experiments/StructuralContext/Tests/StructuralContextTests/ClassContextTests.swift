import Foundation
import Testing
@testable import StructuralContext

private let existing = """
class Host {
  func media(_ value: Request) { /* intentional hook */ }
}
class Old: Host {
  override func media(_ config: Request) { present(config) }
}
"""

private func compare(_ added: String, context: String = existing) throws -> ContextReport {
  try ClassContext.compare(before: [("Old.swift", context)],
    after: [("Old.swift", context), ("New.swift", added)])
}

@Test func newClassConnectsUnchangedParentAndPeer() throws {
  let result = try compare("class New: Host {}")
  let family = try #require(result.families.first)
  #expect(result.families.count == 1)
  #expect(family.addedType.name == "New")
  #expect(family.parentCandidate.location.line == 1)
  #expect(family.slots.first?.parentMethod.location.line == 2)
  #expect(family.slots.first?.existingPeers.first?.method.location.line == 5)
  #expect(family.slots.first?.addedTypeDeclarations.isEmpty == true)
  #expect(result.limitations.contains { $0.contains("intentional hook") })
}

@Test func alreadyImplementedAddedClassShowsItsDeclaration() throws {
  let result = try compare("class New: Host { override func media(_ value: Request) { other(value) } }")
  #expect(result.families.first?.slots.first?.addedTypeDeclarations.count == 1)
  #expect(result.families.first?.slots.first?.addedTypeDeclarations.first?.body == .statements)
}

@Test func extensionImplementationIsIncluded() throws {
  let result = try compare("class New: Host {}\nextension New { override func media(_ value: Request) {} }")
  #expect(result.families.first?.slots.first?.addedTypeDeclarations.first?.body == .empty)
}

@Test func ambiguityAndConditionalDeclarationsDoNotJoin() throws {
  for extra in ["class Host {}", "struct Host {}", "typealias Host = Other",
    "#if FLAG\nextension Host { func another() {} }\n#endif",
    "extension Host where T: Something { func another() {} }"] {
    #expect(try compare("class New: Host {}\n" + extra).families.isEmpty)
  }
  #expect(try compare("#if FLAG\nclass New: Host {}\n#endif").families.isEmpty)
}

@Test func differentLabelsTypesAndStaticFunctionsDoNotMatch() throws {
  for method in ["override func media(label: Request) { use(label) }",
    "override func media(_ value: Different) { use(value) }",
    "static func media(_ value: Request) { use(value) }"] {
    let context = "class Host { func media(_ value: Request) {} }\nclass Old: Host { \(method) }"
    #expect(try compare("class New: Host {}", context: context).families.isEmpty)
  }
}

@Test func nonemptyParentAndEmptyPeerDoNotFormSelectedSlot() throws {
  #expect(try compare("class New: Host {}", context: existing.replacingOccurrences(
    of: "/* intentional hook */", with: "return")).families.isEmpty)
  #expect(try compare("class New: Host {}", context: existing.replacingOccurrences(
    of: "present(config)", with: "")).families.isEmpty)
}

@Test func noNewTypeOrNoExistingPeerDoesNotCreateFamily() throws {
  #expect(try ClassContext.compare(before: [("A.swift", existing)], after: [("A.swift", existing)]).families.isEmpty)
  #expect(try ClassContext.compare(before: [], after: [("A.swift", existing)]).families.isEmpty)
}

@Test func duplicateMethodSpellingAndNestedClassesAreConservative() throws {
  let duplicate = existing + "\nextension Host { func media(_ value: Request) {} }"
  #expect(try compare("class New: Host {}", context: duplicate).families.isEmpty)
  #expect(try compare("struct Outer { class New: Host {} }").families.isEmpty)
}

@Test func malformedFilePreventsPartialResult() {
  #expect(throws: ContextError.self) {
    try compare("class New: Host {}\nclass {")
  }
}

@Test func conditionalBodiesDoNotChangeUnconditionalDeclarationAvailability() throws {
  let context = existing + "\nextension Host { func debug() {\n#if DEBUG\ntrace()\n#endif\n} }"
  #expect(try compare("class New: Host {}", context: context).families.count == 1)
  let conditionalMember = "\nextension Host {\n#if DEBUG\nfunc debug() {}\n#endif\n}"
  #expect(try compare("class New: Host {}", context: existing + conditionalMember).families.isEmpty)
}

@Test func unresolvedEquivalentSpellingsRemainVisibleAsAlternatives() throws {
  let result = try compare("class New: Host { override func media(_ value: Module.Request) { use(value) } }")
  let slot = try #require(result.families.first?.slots.first)
  #expect(slot.addedTypeDeclarations.isEmpty)
  #expect(slot.addedTypeOtherSpellings.count == 1)
  #expect(slot.addedTypeOtherSpellings.first?.spelling.contains("Module . Request") == true)
}

@Test func declarationWithoutBodyIsNotMissingDeclaration() throws {
  let result = try compare("class New: Host { @_silgen_name(\"media\") override func media(_ value: Request) }")
  #expect(result.families.first?.slots.first?.addedTypeDeclarations.first?.body == .unavailable)
}

@Test func genericQualifiedAndEffectBoundariesDoNotInventMatches() throws {
  #expect(try compare("class New<T>: Host {}").families.isEmpty)
  #expect(try compare("class New: Module.Host {}").families.isEmpty)
  #expect(try compare("class New: Host {}\nextension Module.Host { func other() {} }").families.isEmpty)
  for suffix in ["async", "throws", "-> Int"] {
    let context = "class Host { func media(_ value: Request) \(suffix) {} }\nclass Old: Host { override func media(_ value: Request) { use(value) } }"
    #expect(try compare("class New: Host {}", context: context).families.isEmpty)
  }
}

@Test func parentAndPeerExtensionsAcrossFilesAreCollected() throws {
  let files = [("Types.swift", "class Host {}\nclass Old: Host {}"),
    ("Parent.swift", "extension Host { func media(_ value: Request) {} }"),
    ("Peer.swift", "extension Old { override func media(_ value: Request) { use(value) } }")]
  let result = try ClassContext.compare(before: files, after: files + [("New.swift", "class New: Host {}")])
  #expect(result.families.first?.slots.first?.parentMethod.location.file == "Parent.swift")
  #expect(result.families.first?.slots.first?.existingPeers.first?.method.location.file == "Peer.swift")
}

@Test func beforeAmbiguityIsExplainedWithItsSide() throws {
  let result = try ClassContext.compare(before: [("Old.swift", existing + "\nclass Host {}")],
    after: [("Old.swift", existing), ("New.swift", "class New: Host {}")])
  #expect(result.families.isEmpty)
  #expect(result.skipped.contains { $0.hasPrefix("before: Host:") })
}

@Test func orderingIsDeterministicAndInputPolicyDoesNotChangeFacts() throws {
  let files = [("Old.swift", existing), ("B.swift", "class B: Host {}"), ("A.swift", "class A: Host {}")]
  let before = [("Old.swift", existing)]
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  let one = try ClassContext.compare(before: before, after: files)
  let two = try ClassContext.compare(before: before, after: files.reversed())
  #expect(try encoder.encode(one) == encoder.encode(two))
  #expect(one.families.map(\.addedType.name) == ["A", "B"])
  // Requirements outside the source cannot change this report or turn it into a warning.
  #expect(one.scope.contains("spellings"))
}
