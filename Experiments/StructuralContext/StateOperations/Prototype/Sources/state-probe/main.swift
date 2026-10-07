import Foundation
import CryptoKit
import SwiftParser
import SwiftSyntax

func literal(_ text: String) -> Data { Data(text.utf8) }
func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
func tokens(_ node: some SyntaxProtocol) -> [String] { node.tokens(viewMode: .sourceAccurate).map(\.text) }
func encode<T: Encodable>(_ value: T) throws -> Data {
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
  return try encoder.encode(value)
}
struct Site: Encodable { let file: String; let line: Int; let offset: Int }
struct Reference: Encodable {
  let name: String; let form: String; let site: Site; let usageSHA256: String
}
struct WrittenCall: Encodable { let selector: String; let expression: String; let site: Site; let conditions: [String] }
struct Property: Encodable {
  let owner: String; let ownerKey: String; let name: String; let kind: String
  let conditions: [String]; let site: Site
}
struct Operation: Encodable {
  let key: String; let owner: String; let ownerKey: String; let ownerMatchKey: String; let kind: String
  let selector: String?; let conditions: [String]; let site: Site; let tokenSHA256: String
  let references: [Reference]; let possibleShadowNames: [String]; let calls: [WrittenCall]
}
func nominalHeader(_ node: Syntax) -> [String]? {
  let brace: TokenSyntax?
  if let n = node.as(StructDeclSyntax.self) { brace = n.memberBlock.leftBrace }
  else if let n = node.as(ClassDeclSyntax.self) { brace = n.memberBlock.leftBrace }
  else if let n = node.as(ActorDeclSyntax.self) { brace = n.memberBlock.leftBrace }
  else if let n = node.as(EnumDeclSyntax.self) { brace = n.memberBlock.leftBrace }
  else if let n = node.as(ExtensionDeclSyntax.self) { brace = n.memberBlock.leftBrace }
  else { return nil }
  return node.tokens(viewMode: .sourceAccurate).prefix { $0.position < brace!.position }.map(\.text)
}
func context(_ node: Syntax, includingNode: Bool = false) -> (headers: [[String]], owners: [Syntax], conditions: [String], nested: Bool) {
  var headers: [[String]] = [], owners: [Syntax] = [], conditions: [String] = [], nested = false
  var parent = includingNode ? node : node.parent
  while let p = parent {
    if let h = nominalHeader(p) { headers.insert(h, at: 0); owners.insert(p, at: 0) }
    // Any executable/property declaration between a member and its owner is a boundary,
    // including implicit getters and stored-property initializer closures.
    if p.is(FunctionDeclSyntax.self) || p.is(InitializerDeclSyntax.self) || p.is(AccessorDeclSyntax.self)
      || p.is(VariableDeclSyntax.self) || p.is(SubscriptDeclSyntax.self) { nested = true }
    if let clause = p.as(IfConfigClauseSyntax.self) {
      let selected = clause.poundKeyword.text + " " + (clause.condition?.trimmedDescription ?? "")
      let all = clause.parent?.as(IfConfigClauseListSyntax.self)?.map { $0.poundKeyword.text + " " + ($0.condition?.trimmedDescription ?? "") } ?? []
      conditions.insert("selected=" + selected + "; branches=" + all.joined(separator: " | "), at: 0)
    }
    parent = p.parent
  }
  return (headers, owners, conditions, nested)
}
func ownerMatchKey(file: String, node: Syntax) -> String {
  let c = context(node, includingNode: true)
  return hash(try! encode([file, hash(try! encode(c.headers)), hash(try! encode(c.conditions))]))
}
func lexicalOwnerKey(file: String, owners: [Syntax]) -> String {
  hash(try! encode([file] + owners.map { String($0.positionAfterSkippingLeadingTrivia.utf8Offset) }))
}
final class OwnerCounter: SyntaxVisitor {
  let file: String; var counts: [String: Int] = [:]
  var nameCounts: [String: Int] = [:]; var ownerNames: [String: String] = [:]
  var extensionOwners: Set<String> = []
  init(file: String) { self.file = file; super.init(viewMode: .sourceAccurate) }
  func record(_ node: Syntax) -> SyntaxVisitorContinueKind {
    counts[ownerMatchKey(file: file, node: node), default: 0] += 1
    return .visitChildren
  }
  func name(_ name: String, node: Syntax, isExtension: Bool = false) {
    let c = context(node)
    guard c.owners.isEmpty, !c.nested else { return }
    let nameKey = hash(try! encode([file, literal(name).base64EncodedString()]))
    let ownerKey = lexicalOwnerKey(file: file, owners: [node])
    ownerNames[ownerKey] = nameKey
    if isExtension { extensionOwners.insert(ownerKey) }
    else { nameCounts[nameKey, default: 0] += 1 }
  }
  override func visit(_ n: StructDeclSyntax) -> SyntaxVisitorContinueKind { name(n.name.text, node: Syntax(n)); return record(Syntax(n)) }
  override func visit(_ n: ClassDeclSyntax) -> SyntaxVisitorContinueKind { name(n.name.text, node: Syntax(n)); return record(Syntax(n)) }
  override func visit(_ n: ActorDeclSyntax) -> SyntaxVisitorContinueKind { name(n.name.text, node: Syntax(n)); return record(Syntax(n)) }
  override func visit(_ n: EnumDeclSyntax) -> SyntaxVisitorContinueKind { name(n.name.text, node: Syntax(n)); return record(Syntax(n)) }
  override func visit(_ n: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind { name(n.name.text, node: Syntax(n)); return .visitChildren }
  override func visit(_ n: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind { name(n.name.text, node: Syntax(n)); return .visitChildren }
  override func visit(_ n: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
    if let identifier = n.extendedType.as(IdentifierTypeSyntax.self), identifier.genericArgumentClause == nil {
      name(identifier.name.text, node: Syntax(n), isExtension: true)
    }
    return record(Syntax(n))
  }
}
final class BodyReader: SyntaxVisitor {
  let site: (Syntax) -> Site
  var references: [Reference] = []; var shadows: [String] = []; var calls: [WrittenCall] = []
  init(site: @escaping (Syntax) -> Site) { self.site = site; super.init(viewMode: .sourceAccurate) }
  func usage(_ node: Syntax) -> String {
    var expression = node
    while let parent = expression.parent,
      !parent.is(CodeBlockItemSyntax.self), !parent.is(StmtSyntax.self),
      !parent.is(ConditionElementSyntax.self), !parent.is(InitializerClauseSyntax.self),
      !parent.is(CodeBlockSyntax.self), !parent.is(PatternBindingSyntax.self) {
      expression = parent
    }
    return hash(try! encode(tokens(expression)))
  }
  override func visit(_ n: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
    if let member = n.parent?.as(MemberAccessExprSyntax.self), member.declName.id == n.id { return .skipChildren }
    references.append(Reference(name: n.baseName.text, form: "unqualified-binding-unresolved", site: site(Syntax(n)), usageSHA256: usage(Syntax(n))))
    return .visitChildren
  }
  override func visit(_ n: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
    if n.base?.trimmedDescription == "self" {
      references.append(Reference(name: n.declName.baseName.text, form: "explicit-self-written-member", site: site(Syntax(n)), usageSHA256: usage(Syntax(n))))
    }
    return .visitChildren
  }
  override func visit(_ n: IdentifierPatternSyntax) -> SyntaxVisitorContinueKind {
    shadows.append(n.identifier.text); return .visitChildren
  }
  override func visit(_ n: ClosureShorthandParameterSyntax) -> SyntaxVisitorContinueKind {
    shadows.append(n.name.text); return .visitChildren
  }
  override func visit(_ n: ClosureParameterSyntax) -> SyntaxVisitorContinueKind {
    shadows.append((n.secondName ?? n.firstName).text); return .visitChildren
  }
  override func visit(_ n: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
    let name: String?
    if let m = n.calledExpression.as(MemberAccessExprSyntax.self) { name = m.declName.baseName.text }
    else { name = n.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text }
    if let name {
      let labels = n.arguments.map { ($0.label?.text ?? "_") + ":" }.joined()
      calls.append(WrittenCall(selector: name + "(" + labels + ")", expression: n.calledExpression.trimmedDescription, site: site(Syntax(n)), conditions: context(Syntax(n)).conditions))
    }
    return .visitChildren
  }
  override func visit(_ n: StructDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ n: ClassDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ n: ActorDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ n: EnumDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
}
final class Inventory: SyntaxVisitor {
  let file: String; let converter: SourceLocationConverter
  var properties: [Property] = []; var operations: [Operation] = []
  init(file: String, tree: SourceFileSyntax) {
    self.file = file; converter = SourceLocationConverter(fileName: file, tree: tree)
    super.init(viewMode: .sourceAccurate)
  }
  func site(_ n: Syntax) -> Site {
    let p = n.positionAfterSkippingLeadingTrivia
    return Site(file: file, line: converter.location(for: p).line, offset: p.utf8Offset)
  }
  func add(_ node: Syntax, body: Syntax, header: [String], kind: String, selector: String?, params: [String] = []) throws {
    let c = context(node)
    guard !c.headers.isEmpty, !c.nested else { return }
    let reader = BodyReader(site: site); reader.walk(body)
    let owner = c.headers.map { $0.joined(separator: " ") }.joined(separator: " / ")
    let ownerKey = lexicalOwnerKey(file: file, owners: c.owners)
    let matchKey = ownerMatchKey(file: file, node: c.owners.last!)
    let key = hash(try encode([matchKey, kind, hash(try encode(header)), hash(try encode(c.conditions))]))
    operations.append(Operation(key: key, owner: owner, ownerKey: ownerKey, ownerMatchKey: matchKey, kind: kind, selector: selector,
      conditions: c.conditions, site: site(node), tokenSHA256: hash(try encode(tokens(node))),
      references: reader.references, possibleShadowNames: params + reader.shadows, calls: reader.calls))
  }
  override func visit(_ n: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
    guard let body = n.body else { return .visitChildren }
    let header = n.tokens(viewMode: .sourceAccurate).prefix { $0.position < body.leftBrace.position }.map(\.text)
    let params = n.signature.parameterClause.parameters.map { ($0.secondName ?? $0.firstName).text }
    let selector = n.name.text + "(" + n.signature.parameterClause.parameters.map { $0.firstName.text + ":" }.joined() + ")"
    try! add(Syntax(n), body: Syntax(body), header: header, kind: "function", selector: selector, params: params)
    return .visitChildren
  }
  override func visit(_ n: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
    guard let body = n.body else { return .visitChildren }
    let header = n.tokens(viewMode: .sourceAccurate).prefix { $0.position < body.leftBrace.position }.map(\.text)
    try! add(Syntax(n), body: Syntax(body), header: header, kind: "initializer", selector: nil,
      params: n.signature.parameterClause.parameters.map { ($0.secondName ?? $0.firstName).text })
    return .visitChildren
  }
  override func visit(_ n: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
    let c = context(Syntax(n)); guard !c.headers.isEmpty, !c.nested else { return .visitChildren }
    let owner = c.headers.map { $0.joined(separator: " ") }.joined(separator: " / ")
    let ownerKey = lexicalOwnerKey(file: file, owners: c.owners)
    for binding in n.bindings {
      guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { continue }
      var kind = "stored"
      if let accessors = binding.accessorBlock {
        if case .accessors(let list) = accessors.accessors,
          list.allSatisfy({ ["willSet", "didSet"].contains($0.accessorSpecifier.text) }) { kind = "observed-stored" }
        else { kind = "accessor; storage-unresolved" }
        let header = n.tokens(viewMode: .sourceAccurate).prefix { $0.position < accessors.leftBrace.position }.map(\.text) + [name]
        try! add(Syntax(n), body: Syntax(accessors), header: header, kind: "property-body", selector: nil)
      }
      properties.append(Property(owner: owner, ownerKey: ownerKey, name: name, kind: kind, conditions: c.conditions, site: site(Syntax(binding))))
    }
    return .visitChildren
  }
}
struct Snapshot {
  var properties: [Property] = []; var operations: [Operation] = []
  var ownerCounts: [String: Int] = [:]; var files = 0; var inputSHA256 = ""
  var nameCounts: [String: Int] = [:]; var ownerNames: [String: String] = [:]
  var extensionOwners: Set<String> = []
}
func load(_ path: String) throws -> Snapshot {
  let input = URL(fileURLWithPath: path).standardizedFileURL
  guard try input.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw CocoaError(.fileReadUnsupportedScheme) }
  let root = input.resolvingSymlinksInPath()
  var directory: ObjCBool = false
  guard FileManager.default.fileExists(atPath: root.path, isDirectory: &directory), directory.boolValue else { throw CocoaError(.fileReadNoSuchFile) }
  var readError: (any Error)?
  guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey], errorHandler: { _, e in readError = e; return false }) else { throw CocoaError(.fileReadUnknown) }
  var files: [URL] = []
  for case let url as URL in enumerator {
    if url.lastPathComponent.hasPrefix(".") { enumerator.skipDescendants(); continue }
    let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
    guard values.isSymbolicLink != true else { throw CocoaError(.fileReadUnsupportedScheme) }
    if url.pathExtension == "swift", values.isRegularFile == true { files.append(url) }
  }
  if let readError { throw readError }
  var snapshot = Snapshot()
  var pairs: [[String]] = []
  for url in files.sorted(by: { literal($0.path).lexicographicallyPrecedes(literal($1.path)) }) {
    let data = try Data(contentsOf: url); let source = String(decoding: data, as: UTF8.self)
    guard literal(source) == data else { throw CocoaError(.fileReadInapplicableStringEncoding) }
    let components = url.resolvingSymlinksInPath().pathComponents
    guard Array(components.prefix(root.pathComponents.count)) == root.pathComponents else { throw CocoaError(.fileReadUnknown) }
    let relative = components.dropFirst(root.pathComponents.count).joined(separator: "/")
    pairs.append([relative, source])
    let tree = Array(source.utf8).withUnsafeBufferPointer { Parser.parse(source: $0, swiftVersion: .v6) }
    guard !tree.hasError else { throw CocoaError(.fileReadCorruptFile) }
    let owners = OwnerCounter(file: relative); owners.walk(tree)
    for (key, count) in owners.counts { snapshot.ownerCounts[key, default: 0] += count }
    for (key, count) in owners.nameCounts { snapshot.nameCounts[key, default: 0] += count }
    snapshot.ownerNames.merge(owners.ownerNames, uniquingKeysWith: { first, _ in first })
    snapshot.extensionOwners.formUnion(owners.extensionOwners)
    let reader = Inventory(file: relative, tree: tree); reader.walk(tree)
    snapshot.properties += reader.properties; snapshot.operations += reader.operations; snapshot.files += 1
  }
  snapshot.inputSHA256 = hash(try encode(pairs))
  return snapshot
}
struct CallerCandidate: Encodable {
  let caller: Site; let call: Site; let target: Site; let selector: String; let depth: Int
  let callerOwner: String; let conditions: [String]; let ownerRelation: String
  let matchingOwnerDeclarations: Int
  let meaning = "same-written-selector; callee-unresolved"
}
struct RelatedOperation: Encodable {
  let site: Site; let kind: String; let selector: String?; let conditions: [String]
  let beforeCorrespondence: String
  let references: [Reference]; let writtenCallerCandidates: [CallerCandidate]
  let shadowCandidates: [String]
  let changedUsageExpressions: Bool
}
struct Relation: Encodable {
  let propertyCandidates: [Property]; let changedOperations: [RelatedOperation]
  let existingOperations: [RelatedOperation]
  let meaning = "same-written-property-name-candidates-in-lexical-owner; binding/callee/unification-unresolved"
}
struct Report: Encodable {
  let schema = "sekka-state-operation-scratch/1"
  let beforeFiles: Int; let afterFiles: Int; let relationships: [Relation]
  let beforeInputSHA256: String; let afterInputSHA256: String
  let limitations = ["Known-input scratch, not utility or design warning", "Property edges stay in the lexical owner; caller search adds same-file unqualified extension-name candidates, not type resolution", "Duplicate owner headers/conditions have no unique before correspondence; no cross-file/nested/qualified extension joining", "Unqualified references and scope shadowing are unresolved", "Changed usage means enclosing expression tokens differ, not a changed effect; removed-only uses not selected", "Call selector matches are written candidates, not dependencies; arbitrary receivers and overloads unresolved; at most two incoming hops", "Conditions, storage of computed properties, effects, intent and performance unresolved", "Zero is not design approval; non-Swift and top-level changes not analyzed"]
}
func compare(_ old: Snapshot, _ new: Snapshot) -> Report {
  let oldKeys = Dictionary(grouping: old.operations, by: \.key)
  let newKeys = Dictionary(grouping: new.operations, by: \.key)
  func related(_ op: Operation, name: String) -> RelatedOperation {
    let previous = oldKeys[op.key, default: []]
    let state = previous.count == 1 && newKeys[op.key]?.count == 1
      && old.ownerCounts[op.ownerMatchKey] == 1 && new.ownerCounts[op.ownerMatchKey] == 1 ?
      (previous[0].tokenSHA256 == op.tokenSHA256 ? "token-identical" : "changed") : "no-unique-old-correspondence"
    let refs = op.references.filter { literal($0.name) == literal(name) }
    let ownerName = new.ownerNames[op.ownerKey]
    let local = new.operations.filter {
      if $0.ownerKey == op.ownerKey { return true }
      return ownerName != nil && new.nameCounts[ownerName!] == 1
        && !new.extensionOwners.contains(op.ownerKey) && new.extensionOwners.contains($0.ownerKey)
        && new.ownerNames[$0.ownerKey] == ownerName
    }
    var users: [CallerCandidate] = []; var frontier = [op]; var visited: Set<String> = [op.key]
    for depth in 1...2 {
      var next: [Operation] = []
      for target in frontier {
        guard let selector = target.selector else { continue }
        let matches = local.filter { $0.selector.map { literal($0) == literal(selector) } ?? false }.count
        for caller in local {
          for call in caller.calls where literal(call.selector) == literal(selector) {
            let relation = caller.ownerKey == target.ownerKey ? "same-lexical-owner" : "same-file-unqualified-extension-name-candidate; owner-unresolved"
            users.append(CallerCandidate(caller: caller.site, call: call.site, target: target.site, selector: selector, depth: depth,
              callerOwner: caller.owner, conditions: call.conditions, ownerRelation: relation, matchingOwnerDeclarations: matches))
            if visited.insert(caller.key).inserted { next.append(caller) }
          }
        }
      }
      frontier = next
    }
    let oldRefs = state == "no-unique-old-correspondence" ? [] : previous.flatMap { $0.references }.filter { literal($0.name) == literal(name) }
    let oldUses = Dictionary(grouping: oldRefs, by: \.usageSHA256).mapValues(\.count)
    let newUses = Dictionary(grouping: refs, by: \.usageSHA256).mapValues(\.count)
    let changedUse = state != "token-identical" && newUses.contains { $0.value > oldUses[$0.key, default: 0] }
    return RelatedOperation(site: op.site, kind: op.kind, selector: op.selector, conditions: op.conditions, beforeCorrespondence: state, references: refs, writtenCallerCandidates: users,
      shadowCandidates: op.possibleShadowNames.filter { literal($0) == literal(name) }, changedUsageExpressions: changedUse)
  }
  let grouped = Dictionary(grouping: new.properties, by: { $0.ownerKey + ":" + literal($0.name).base64EncodedString() })
  var relationships: [Relation] = []
  for key in grouped.keys.sorted() {
    let props = grouped[key]!, first = props[0]
    let operations = new.operations.filter { $0.ownerKey == first.ownerKey && $0.references.contains { literal($0.name) == literal(first.name) } }
      .map { related($0, name: first.name) }
    let changed = operations.filter { $0.changedUsageExpressions }
    let existing = operations.filter { !$0.changedUsageExpressions && $0.beforeCorrespondence != "no-unique-old-correspondence" }
    // An existing helper may itself change. Do not reintroduce an unchanged-target gate.
    if !changed.isEmpty && operations.count > 1 && operations.contains(where: { $0.beforeCorrespondence != "no-unique-old-correspondence" }) {
      relationships.append(Relation(propertyCandidates: props, changedOperations: changed, existingOperations: existing))
    }
  }
  return Report(beforeFiles: old.files, afterFiles: new.files, relationships: relationships, beforeInputSHA256: old.inputSHA256, afterInputSHA256: new.inputSHA256)
}
func text(_ report: Report) -> String {
  func quote(_ value: String) -> String { String(decoding: try! encode(value), as: UTF8.self) }
  func location(_ site: Site) -> String { quote(site.file + ":" + String(site.line)) }
  func operation(_ op: RelatedOperation) -> String {
    quote(op.selector ?? op.kind) + " @ " + location(op.site) + " [" + op.beforeCorrespondence + "]"
      + (op.shadowCandidates.isEmpty ? "" : " [shadow-name candidate]")
  }
  var lines = ["State / operation map — syntax candidates, not design warnings",
    "Swift files: \(report.beforeFiles) → \(report.afterFiles); groups: \(report.relationships.count)",
    "Property binding, receiver/callee, effect and need for unification are unresolved."]
  for relation in report.relationships {
    let first = relation.propertyCandidates[0]
    lines.append("├─ " + quote(first.owner) + " · " + quote(first.name))
    for property in relation.propertyCandidates {
      lines.append("│  property " + location(property.site) + " [" + property.kind + "]")
      if !property.conditions.isEmpty { lines.append("│  conditions " + quote(property.conditions.joined(separator: " / "))) }
    }
    for op in relation.changedOperations { lines.append("│  + usage " + operation(op)) }
    for op in relation.existingOperations { lines.append("│  = existing " + operation(op)) }
    for op in relation.changedOperations + relation.existingOperations where !op.conditions.isEmpty {
      lines.append("│  conditions " + location(op.site) + " " + quote(op.conditions.joined(separator: " / ")))
    }
  }
  lines.append("└─ Incoming written-call candidates (deduplicated; no dependency resolution)")
  var seen: Set<Data> = []
  for relation in report.relationships {
    for op in relation.changedOperations + relation.existingOperations {
      for caller in op.writtenCallerCandidates where seen.insert(try! encode(caller)).inserted {
        lines.append("   " + location(caller.call) + " (in " + location(caller.caller) + ") → " + location(caller.target) + " " + quote(caller.selector)
          + " [hop \(caller.depth), declarations \(caller.matchingOwnerDeclarations), " + caller.ownerRelation + "]")
        if !caller.conditions.isEmpty { lines.append("   conditions " + quote(caller.conditions.joined(separator: " / "))) }
      }
    }
  }
  lines.append("Limits: " + report.limitations.map(quote).joined(separator: "; "))
  return lines.joined(separator: "\n") + "\n"
}
do {
  let args = CommandLine.arguments
  guard args.count == 3 || (args.count == 4 && args[3] == "--text") else { throw CocoaError(.fileReadInvalidFileName) }
  let report = compare(try load(CommandLine.arguments[1]), try load(CommandLine.arguments[2]))
  if args.count == 4 { FileHandle.standardOutput.write(Data(text(report).utf8)) }
  else {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
    FileHandle.standardOutput.write(try encoder.encode(report)); print("")
  }
} catch {
  let e = error as NSError
  FileHandle.standardError.write(Data("state-probe: \(e.domain) \(e.code)\n".utf8)); exit(2)
}
