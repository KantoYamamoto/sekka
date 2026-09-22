import SwiftParser
import SwiftSyntax

/// Written declarations and annotations. A unique candidate is not a resolved callee.
public struct SourceInventory: Sendable {
  public let types: [InventoryType]
  public let functions: [InventoryFunction]
  public let properties: [InventoryProperty]
  public let extensionNames: [String]
  public let aliasNames: [String]
  public let uncertainOwnerIDs: [String]
  public let hasUnexpandedGlobalDeclarations: Bool

  public init(files: [(String, String)]) throws {
    guard Set(files.map(\.0)).count == files.count else { throw InventoryError.duplicatePath }
    var types: [InventoryType] = [], functions: [InventoryFunction] = [], properties: [InventoryProperty] = []
    var extensions: [String] = [], aliases: [String] = [], uncertain: [String] = []
    var unknownGlobal = false
    for (file, source) in files.sorted(by: { $0.0 < $1.0 }) {
      let tree = Array(source.utf8).withUnsafeBufferPointer { Parser.parse(source: $0, swiftVersion: .v6) }
      guard !tree.hasError else { throw ContextError.malformed(file) }
      let reader = InventoryReader(file: file, tree: tree)
      reader.walk(tree)
      types += reader.types; functions += reader.functions; properties += reader.properties
      extensions += reader.extensions; aliases += reader.aliases
      uncertain += reader.uncertainOwners; unknownGlobal = unknownGlobal || reader.unknownGlobal
    }
    self.types = types; self.functions = functions; self.properties = properties
    extensionNames = Array(Set(extensions)).sorted(); aliasNames = Array(Set(aliases)).sorted()
    uncertainOwnerIDs = Array(Set(uncertain)).sorted(); hasUnexpandedGlobalDeclarations = unknownGlobal
  }

  public func memberCandidate(callerID: String, receiver: String, selector: String, explicitSelf: Bool = false) -> MemberLookup {
    guard !hasUnexpandedGlobalDeclarations else { return .unknown("unexpanded-global-declarations") }
    let callers = functions.filter { $0.id == callerID }
    guard callers.count == 1 else { return .unknown("caller-not-unique") }
    let caller = callers[0]
    guard !uncertainOwnerIDs.contains(caller.ownerID) else { return .unknown("unexpanded-owner-members") }
    guard caller.unsupported.isEmpty else { return .unknown("caller-scope-unsupported") }
    let owners = types.filter { $0.id == caller.ownerID }
    guard owners.count == 1, owners[0].unsupported.isEmpty else { return .unknown("owner-scope-unsupported") }
    guard !extensionNames.contains(owners[0].name) else { return .unknown("owner-has-extension") }
    // Conservatively reject any shadow in the function, even one after the call.
    if !explicitSelf && (caller.parameterNames + caller.localNames).contains(receiver) { return .unknown("receiver-shadowed") }
    let properties = properties.filter { $0.ownerID == caller.ownerID && $0.name == receiver }
    guard properties.count == 1 else { return .unknown("property-not-unique") }
    let property = properties[0]
    guard property.unsupported.isEmpty, let typeName = property.simpleType else { return .unknown("property-type-unsupported") }
    guard !aliasNames.contains(typeName) else { return .unknown("type-alias-unsupported") }
    let targets = types.filter { $0.name == typeName }
    guard targets.count == 1 else { return .unknown("target-type-not-unique") }
    let target = targets[0]
    guard !uncertainOwnerIDs.contains(target.id) else { return .unknown("unexpanded-target-members") }
    guard target.unsupported.isEmpty else { return .unknown("target-type-unsupported") }
    guard !extensionNames.contains(typeName) else { return .unknown("target-has-extension") }
    let basename = selector.split(separator: "(").first.map(String.init) ?? selector
    let sameName = functions.filter { $0.ownerID == target.id && $0.selector.split(separator: "(").first.map(String.init) == basename }
    guard !sameName.contains(where: { $0.unsupported.contains("flexible-parameters") }) else {
      return .unknown("member-call-shape-unsupported")
    }
    let candidates = sameName.filter { $0.selector == selector }
    guard candidates.count == 1 else { return .unknown("member-not-unique") }
    let function = candidates[0]
    guard function.unsupported.isEmpty, function.bodyTokens != nil else { return .unknown("member-scope-unsupported") }
    return MemberLookup(evidence: MemberEvidence(caller: caller.site, property: property,
      targetType: target, target: function), reason: "written-type-and-selector-candidate")
  }
}

public enum InventoryError: Error { case duplicatePath }

public struct InventoryType: Codable, Sendable {
  public let id: String
  public let name: String
  public let headerTokens: String
  public let site: SourceSite
  public let unsupported: [String]
}
public struct InventoryFunction: Codable, Sendable {
  public let id: String
  public let ownerID: String
  public let selector: String
  public let site: SourceSite
  public let declarationTokens: String
  public let bodyTokens: String?
  public let statements: [InventoryStatement]
  public let parameterNames: [String]
  public let localNames: [String]
  public let unsupported: [String]
}
public struct InventoryStatement: Codable, Sendable {
  public let tokens: String
  public let call: InventoryCall?
}
public struct InventoryCall: Codable, Sendable {
  public let site: SourceSite
  public let selector: String
  public let receiver: String?
  public let explicitSelf: Bool
  public let identifierArguments: [String]
}
public struct InventoryProperty: Codable, Sendable {
  public let ownerID: String
  public let name: String
  public let simpleType: String?
  public let typeSpelling: String?
  public let declarationTokens: String
  public let site: SourceSite
  public let typeSite: SourceSite?
  public let unsupported: [String]
}
public struct MemberEvidence: Codable, Sendable {
  public let caller: SourceSite
  public let property: InventoryProperty
  public let targetType: InventoryType
  public let target: InventoryFunction
}
public struct MemberLookup: Codable, Sendable {
  public let evidence: MemberEvidence?
  public let reason: String
  static func unknown(_ reason: String) -> Self { Self(evidence: nil, reason: reason) }
}

private func inventoryTokens(_ node: some SyntaxProtocol) -> String {
  node.tokens(viewMode: .sourceAccurate).map(\.text).joined(separator: " ")
}
private func inventorySelector(_ node: FunctionDeclSyntax) -> String {
  node.name.text + "(" + node.signature.parameterClause.parameters.map { $0.firstName.text + ":" }.joined() + ")"
}
private func inventorySignature(_ node: FunctionDeclSyntax) -> String {
  node.name.text + (node.genericParameterClause.map(inventoryTokens) ?? "") + "(" + node.signature.parameterClause.parameters.map {
    $0.firstName.text + ":" + inventoryTokens($0.modifiers) + inventoryTokens($0.type) + ($0.ellipsis == nil ? "" : "...")
  }.joined(separator: ",") + ")" + (node.signature.effectSpecifiers.map(inventoryTokens) ?? "")
    + (node.signature.returnClause.map(inventoryTokens) ?? "") + (node.genericWhereClause.map(inventoryTokens) ?? "")
}

private final class LocalNames: SyntaxVisitor {
  var names: [String] = []
  var closure = false
  var macro = false
  init() { super.init(viewMode: .sourceAccurate) }
  override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind { macro = true; return .skipChildren }
  override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind { macro = true; return .skipChildren }
  override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
    if !node.attributes.isEmpty { macro = true }; return .visitChildren
  }
  override func visit(_ node: IdentifierPatternSyntax) -> SyntaxVisitorContinueKind {
    names.append(node.identifier.text); return .visitChildren
  }
  override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
    if !node.attributes.isEmpty { macro = true }; names.append(node.name.text); return .skipChildren
  }
  override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind {
    if node.catchItems.isEmpty { names.append("error") }
    return .visitChildren
  }
  override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind { closure = true; return .skipChildren }
  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind { if !node.attributes.isEmpty { macro = true }; names.append(node.name.text); return .skipChildren }
  override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind { if !node.attributes.isEmpty { macro = true }; names.append(node.name.text); return .skipChildren }
  override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind { if !node.attributes.isEmpty { macro = true }; names.append(node.name.text); return .skipChildren }
  override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind { if !node.attributes.isEmpty { macro = true }; names.append(node.name.text); return .skipChildren }
  override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind { if !node.attributes.isEmpty { macro = true }; names.append(node.name.text); return .skipChildren }

}

private final class InventoryReader: SyntaxVisitor {
  let file: String
  let converter: SourceLocationConverter
  var owners: [InventoryType] = []
  var types: [InventoryType] = []
  var functions: [InventoryFunction] = []
  var properties: [InventoryProperty] = []
  var extensions: [String] = []
  var aliases: [String] = []
  var uncertainOwners: [String] = []
  var unknownGlobal = false
  init(file: String, tree: SourceFileSyntax) {
    self.file = file; converter = SourceLocationConverter(fileName: file, tree: tree)
    super.init(viewMode: .sourceAccurate)
  }
  func site(_ syntax: some SyntaxProtocol, name: String, signature: String? = nil) -> SourceSite {
    SourceSite(file: file, line: converter.location(for: syntax.positionAfterSkippingLeadingTrivia).line,
      endLine: converter.location(for: syntax.endPositionBeforeTrailingTrivia).line, declaration: name, signature: signature)
  }
  func conditional(_ syntax: some SyntaxProtocol) -> Bool {
    var parent = syntax.parent
    while let ancestor = parent {
      if ancestor.is(IfConfigDeclSyntax.self) { return true }
      parent = ancestor.parent
    }
    return false
  }
  func readType(_ syntax: some SyntaxProtocol, name: String, block: MemberBlockSyntax, unsupported: [String]) {
    let display = (owners.map { $0.site.declaration }.suffix(1) + [name]).joined(separator: ".")
    let attributed = syntax.asProtocol(DeclGroupSyntax.self).map { !$0.attributes.isEmpty } ?? false
    if attributed { markUnknownMembers() }
    let reasons = unsupported + (attributed ? ["attributed-type"] : []) + (owners.isEmpty ? [] : ["nested-type"]) + (conditional(syntax) ? ["conditional"] : [])
    let header = syntax.tokens(viewMode: .sourceAccurate).prefix { $0.positionAfterSkippingLeadingTrivia < block.leftBrace.positionAfterSkippingLeadingTrivia }.map(\.text).joined(separator: " ")
    let type = InventoryType(id: file + ":" + display, name: name, headerTokens: header, site: site(syntax, name: display), unsupported: reasons)
    types.append(type); owners.append(type)
    walk(block)
    owners.removeLast()
  }
  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
    readType(node, name: node.name.text, block: node.memberBlock,
      unsupported: (node.genericParameterClause == nil ? [] : ["generic"]) + (node.inheritanceClause == nil ? [] : ["inheritance-or-conformance"]))
    return .skipChildren
  }
  override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
    readType(node, name: node.name.text, block: node.memberBlock,
      unsupported: (node.genericParameterClause == nil ? [] : ["generic"]) + (node.inheritanceClause == nil ? [] : ["inheritance-or-conformance"]))
    return .skipChildren
  }
  override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
    readType(node, name: node.name.text, block: node.memberBlock,
      unsupported: (node.genericParameterClause == nil ? [] : ["generic"]) + (node.inheritanceClause == nil ? [] : ["inheritance-or-conformance"]))
    return .skipChildren
  }
  override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
    readType(node, name: node.name.text, block: node.memberBlock, unsupported: ["enum"]); return .skipChildren
  }
  override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
    readType(node, name: node.name.text, block: node.memberBlock, unsupported: ["protocol"]); return .skipChildren
  }
  override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
    // Use the final written name conservatively even for qualified/generic extensions.
    if let type = node.extendedType.as(IdentifierTypeSyntax.self) { extensions.append(type.name.text) }
    else if let type = node.extendedType.as(MemberTypeSyntax.self) { extensions.append(type.name.text) }
    return .skipChildren
  }
  override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
    if !node.attributes.isEmpty { markUnknownMembers() }
    aliases.append(node.name.text); return .skipChildren
  }
  func directCall(_ item: CodeBlockItemSyntax, display: String) -> InventoryCall? {
    guard let call = item.item.as(FunctionCallExprSyntax.self), call.trailingClosure == nil,
      call.additionalTrailingClosures.isEmpty else { return nil }
    var receiver: String?, explicitSelf = false
    let name: String
    if let member = call.calledExpression.as(MemberAccessExprSyntax.self) {
      guard member.declName.argumentNames == nil else { return nil }
      name = member.declName.baseName.text
      if let base = member.base?.as(DeclReferenceExprSyntax.self), base.argumentNames == nil {
        receiver = base.baseName.text
      } else if let base = member.base?.as(MemberAccessExprSyntax.self),
        base.base?.as(DeclReferenceExprSyntax.self)?.baseName.text == "self", base.declName.argumentNames == nil {
        receiver = base.declName.baseName.text; explicitSelf = true
      } else { return nil }
    } else if let reference = call.calledExpression.as(DeclReferenceExprSyntax.self), reference.argumentNames == nil {
      name = reference.baseName.text
    } else { return nil }
    let identifiers = call.arguments.compactMap { argument -> String? in
      guard let ref = argument.expression.as(DeclReferenceExprSyntax.self), ref.argumentNames == nil,
        !["self", "super", "nil", "true", "false"].contains(ref.baseName.text) else { return nil }
      return ref.baseName.text
    }
    return InventoryCall(site: site(call, name: display),
      selector: name + "(" + call.arguments.map { ($0.label?.text ?? "_") + ":" }.joined() + ")",
      receiver: receiver, explicitSelf: explicitSelf, identifierArguments: Array(Set(identifiers)).sorted())
  }
  override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
    if !node.attributes.isEmpty { markUnknownMembers() }
    guard let owner = owners.last else { return .skipChildren }
    let signature = inventorySignature(node), selector = inventorySelector(node)
    let locals = LocalNames(); if let body = node.body { locals.walk(body) }
    var reasons = conditional(node) ? ["conditional"] : []
    if node.modifiers.contains(where: { ["static", "class"].contains($0.name.text) }) { reasons.append("static-member") }
    if node.genericParameterClause != nil { reasons.append("generic-function") }
    if !node.attributes.isEmpty { reasons.append("attributed-function") }
    if locals.closure { reasons.append("closure-scope") }
    if locals.macro { reasons.append("unexpanded-local-macro") }
    if node.signature.parameterClause.parameters.contains(where: { $0.defaultValue != nil || $0.ellipsis != nil }) {
      reasons.append("flexible-parameters")
    }
    functions.append(InventoryFunction(id: owner.id + ":" + signature, ownerID: owner.id, selector: selector,
      site: site(node, name: owner.site.declaration + "." + selector, signature: signature),
      declarationTokens: inventoryTokens(node), bodyTokens: node.body.map(inventoryTokens),
      statements: node.body?.statements.map { statement in
        InventoryStatement(tokens: inventoryTokens(statement.item), call: directCall(statement, display: owner.site.declaration + "." + selector))
      } ?? [],
      parameterNames: node.signature.parameterClause.parameters.map { ($0.secondName ?? $0.firstName).text },
      localNames: Array(Set(locals.names)).sorted(), unsupported: reasons))
    return .skipChildren
  }
  func markUnknownMembers() {
    if let owner = owners.last { uncertainOwners.append(owner.id) } else { unknownGlobal = true }
  }
  override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind { markUnknownMembers(); return .skipChildren }
  override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind { markUnknownMembers(); return .skipChildren }
  override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
    if !node.attributes.isEmpty { markUnknownMembers() }; return .skipChildren
  }
  override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
    if !node.attributes.isEmpty { markUnknownMembers() }; return .skipChildren
  }
  override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
    if !node.attributes.isEmpty { markUnknownMembers() }
    guard let owner = owners.last else { return .skipChildren }
    for binding in node.bindings {
      guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { continue }
      let type = binding.typeAnnotation?.type
      let simple = type?.as(IdentifierTypeSyntax.self)
      var reasons = conditional(node) ? ["conditional"] : []
      if node.modifiers.contains(where: { ["static", "class"].contains($0.name.text) }) { reasons.append("static-property") }
      if !node.attributes.isEmpty { reasons.append("attributed-property") }
      if binding.accessorBlock != nil { reasons.append("computed-or-observed-property") }
      let display = owner.site.declaration + "." + name
      properties.append(InventoryProperty(ownerID: owner.id, name: name,
        simpleType: simple?.genericArgumentClause == nil ? simple?.name.text : nil,
        typeSpelling: type.map(inventoryTokens), declarationTokens: inventoryTokens(node.attributes) + "|" + inventoryTokens(node.modifiers) + "|" + node.bindingSpecifier.text + "|" + inventoryTokens(binding),
        site: site(binding, name: display), typeSite: type.map { site($0, name: display) }, unsupported: reasons))
    }
    return .skipChildren
  }
}
