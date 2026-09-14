import Foundation
import Testing
@testable import StructuralContext

private let logger = "struct Logger { func record(_ event: String) { systemLog(event) } }"
private func inventory(_ caller: String, target: String = logger) throws -> SourceInventory {
  try SourceInventory(files: [("Caller.swift", caller), ("Logger.swift", target)])
}
private let caller = "struct Screen { let logger: Logger; func run(_ event: String) { logger.record(event) } }"
private func lookup(_ value: SourceInventory, receiver: String = "logger", explicitSelf: Bool = false) throws -> MemberLookup {
  let function = try #require(value.functions.first { $0.site.declaration == "Screen.run(_:)" })
  return value.memberCandidate(callerID: function.id, receiver: receiver, selector: "record(_:)", explicitSelf: explicitSelf)
}

@Test func writtenTypeProducesLocatedCandidateNotCallee() throws {
  let value = try inventory(caller)
  let result = try lookup(value)
  #expect(result.reason == "written-type-and-selector-candidate")
  #expect(result.evidence?.property.typeSpelling == "Logger")
  #expect(result.evidence?.property.typeSite?.file == "Caller.swift")
  #expect(result.evidence?.target.site.file == "Logger.swift")
  #expect(result.evidence?.target.bodyTokens == "{ systemLog ( event ) }")
}

@Test func sameNameTypeAndOverloadRemainUnknown() throws {
  let duplicate = try SourceInventory(files: [("A.swift", logger), ("B.swift", logger), ("Caller.swift", caller)])
  #expect(try lookup(duplicate).reason == "target-type-not-unique")
  let overloaded = try inventory(caller, target: "struct Logger { func record(_ x: Int) {}; func record(_ x: String) {} }")
  #expect(try lookup(overloaded).reason == "member-not-unique")
}

@Test func typeAliasExtensionAndInheritanceAreExplicitlyUnsupported() throws {
  let aliased = try inventory(caller, target: "typealias Logger = Other")
  #expect(try lookup(aliased).reason == "type-alias-unsupported")
  let extended = try inventory(caller, target: logger + "\nextension Logger { func extra() {} }")
  #expect(try lookup(extended).reason == "target-has-extension")
  let inherited = try inventory(caller, target: "class Logger: Base { func record(_ x: String) {} }")
  #expect(try lookup(inherited).reason == "target-type-unsupported")
  let owner = try inventory(caller + "\nextension Screen { func extra() {} }")
  #expect(try lookup(owner).reason == "owner-has-extension")
}

@Test func parameterLocalAndTypeShadowsDoNotUsePropertyType() throws {
  let param = try inventory(caller.replacingOccurrences(of: "_ event: String", with: "_ logger: Other"))
  #expect(try lookup(param).reason == "receiver-shadowed")
  let local = try inventory(caller.replacingOccurrences(of: "logger.record(event)", with: "let logger = Other(); logger.record(event)"))
  #expect(try lookup(local).reason == "receiver-shadowed")
  let type = try inventory(caller.replacingOccurrences(of: "logger.record(event)", with: "struct logger {}; logger.record(event)"))
  #expect(try lookup(type).reason == "receiver-shadowed")
  #expect(try lookup(local, explicitSelf: true).evidence != nil)
}

@Test func closuresAndConditionalDeclarationsDoNotSilentlyResolve() throws {
  let closure = try inventory(caller.replacingOccurrences(of: "logger.record(event)", with: "work { logger in logger.record(event) }"))
  #expect(try lookup(closure).reason == "caller-scope-unsupported")
  let conditional = try inventory(caller, target: "#if os(macOS)\n" + logger + "\n#endif")
  #expect(try lookup(conditional).reason == "target-type-unsupported")
}

@Test func optionalInferredGenericAndProtocolTypesStayUnknown() throws {
  for annotation in ["Logger?", "Logger<Int>", "any Logger", "Module.Logger"] {
    #expect(try lookup(inventory(caller.replacingOccurrences(of: "let logger: Logger", with: "let logger: " + annotation))).reason == "property-type-unsupported")
  }
  #expect(try lookup(inventory(caller.replacingOccurrences(of: "let logger: Logger", with: "let logger = Logger()"))).reason == "property-type-unsupported")
  #expect(try lookup(inventory(caller, target: "protocol Logger { func record(_ x: String) }")).reason == "target-type-unsupported")
}

@Test func staticComputedAndAttributedDeclarationsStayUnknown() throws {
  for field in ["static let logger: Logger", "var logger: Logger { Logger() }", "@Injected var logger: Logger"] {
    #expect(try lookup(inventory(caller.replacingOccurrences(of: "let logger: Logger", with: field))).reason == "property-type-unsupported")
  }
  #expect(try lookup(inventory(caller, target: "struct Logger { static func record(_ x: String) {} }")).reason == "member-scope-unsupported")
  #expect(try lookup(inventory(caller, target: "@Other struct Logger { func record(_ x: String) {} }")).reason == "target-type-unsupported")
}

@Test func sameFileAndLineMovementKeepBodiesButUpdatePositions() throws {
  let a = try SourceInventory(files: [("All.swift", logger + "\n" + caller)])
  let b = try SourceInventory(files: [("All.swift", "// header\n\n" + logger + "\n" + caller)])
  let before = try #require(try lookup(a).evidence)
  let after = try #require(try lookup(b).evidence)
  #expect(before.target.id == after.target.id)
  #expect(before.target.bodyTokens == after.target.bodyTokens)
  #expect(after.target.site.line == before.target.site.line + 2)
}

@Test func propertyTypeAndStorageChangeArePreservedForPairing() throws {
  let a = try inventory(caller)
  let b = try inventory(caller.replacingOccurrences(of: "logger: Logger", with: "logger: Other"), target: logger + "\nstruct Other { func record(_ x: String) {} }")
  let ae = try #require(try lookup(a).evidence), be = try #require(try lookup(b).evidence)
  #expect(ae.property.typeSpelling != be.property.typeSpelling)
  #expect(ae.targetType.id != be.targetType.id)
  let variable = try inventory(caller.replacingOccurrences(of: "let logger", with: "var logger"))
  #expect(a.properties[0].declarationTokens != variable.properties[0].declarationTokens)
}

@Test func unqualifiedGlobalAndLocalFunctionsAreNotTypeMembers() throws {
  let value = try inventory(caller + "\nfunc unrelated() { func record(_ x: String) {} }")
  #expect(value.functions.count == 2)
  #expect(try lookup(value).evidence != nil)
}

@Test func duplicatePropertyAndCallerAreNotSelectedByOrder() throws {
  let duplicate = try inventory(caller.replacingOccurrences(of: "let logger: Logger;", with: "let logger: Logger; let logger: Logger;"))
  #expect(try lookup(duplicate).reason == "property-not-unique")
  let repeated = try inventory(caller.replacingOccurrences(of: "func run(_ event: String)", with: "func run(_ event: String) {}; func run(_ event: String)"))
  #expect(try lookup(repeated).reason == "caller-not-unique")
}

@Test func inventoryIsOrderStableAndRejectsMalformedOrDuplicateInput() throws {
  let a = try SourceInventory(files: [("Caller.swift", caller), ("Logger.swift", logger)])
  let b = try SourceInventory(files: [("Logger.swift", logger), ("Caller.swift", caller)])
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  #expect(try encoder.encode(lookup(a)) == encoder.encode(lookup(b)))
  #expect(throws: ContextError.self) { try SourceInventory(files: [("bad.swift", "struct {")]) }
  #expect(throws: InventoryError.self) { try SourceInventory(files: [("same.swift", logger), ("same.swift", caller)]) }
}

@Test func implicitCatchErrorShadowsProperty() throws {
  let source = "struct Screen { let error: Logger; func run(_ event: String) { do { try work() } catch { error.record(event) } } }"
  let value = try inventory(source)
  #expect(try lookup(value, receiver: "error").reason == "receiver-shadowed")
  #expect(try lookup(value, receiver: "error", explicitSelf: true).evidence != nil)
}

@Test func omittedDefaultArgumentDoesNotHideCompetingOverload() throws {
  let target = "struct Logger { func record(_ value: String) {}; func record(_ value: Int, debug: Bool = false) {} }"
  #expect(try lookup(inventory(caller, target: target)).reason == "member-call-shape-unsupported")
  let variadic = "struct Logger { func record(_ values: String...) {} }"
  #expect(try lookup(inventory(caller, target: variadic)).reason == "member-call-shape-unsupported")
}
