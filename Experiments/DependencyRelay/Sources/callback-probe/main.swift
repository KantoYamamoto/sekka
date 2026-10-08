import Foundation
import CallbackContracts
import SwiftSyntax

struct Site: Encodable, Hashable { let file: String; let line: Int }
struct Field {
  let owner: String; let name: String; let signature: [String]; let declaration: Site
  let node: VariableDeclSyntax
  var id: String { owner + "." + name }
}
struct Owner {
  let name: String; let members: MemberBlockItemListSyntax; let fields: [Field]
  let names: Set<String>; let eligible: Bool
}
struct Pass: Encodable {
  let field: String; let declaration: Site; let argument: Site; let destination: String
}
struct Path: Encodable {
  let start: String; let signature: [String]; let passes: [Pass]
  let terminal: String; let terminalDeclaration: Site; let invocation: Site; let callers: [Site]
  var key: String { start + "\u{1f}" + terminal + "\u{1f}" + signature.joined(separator: "\u{1f}") }
}
struct Comparison: Encodable {
  let alternative = "Assemble the leaf at the calling site and pass content into the layouts"
  let benefit = "Leaf action/dependency changes can stay at the calling site when the items contract is stable"
  let conditions = ["Preserve ownership, View identity, updates and snapshot substitution", "Generic content slots also have a cost"]
}
struct Change: Encodable {
  let kind: String; let before: Path; let after: Path?; let comparison: Comparison?
  init(kind: String, before: Path, after: Path?) {
    self.kind = kind; self.before = before; self.after = after
    comparison = after == nil ? nil : Comparison()
  }
}
struct Report: Encodable {
  let beforeSHA256: String; let afterSHA256: String; let beforeFiles: [String]; let afterFiles: [String]
  let changes: [Change]; let unknown: [String]; let limits: [String]
}
enum Failure: Error { case message(String) }
func fail(_ s: String) throws -> Never { throw Failure.message(s) }
func name(_ decl: DeclSyntax) -> [String] {
  if let d = decl.as(VariableDeclSyntax.self) { return d.bindings.compactMap { $0.pattern.as(IdentifierPatternSyntax.self)?.identifier.text } }
  if let d = decl.as(FunctionDeclSyntax.self) { return [d.name.text] }
  if let d = decl.as(StructDeclSyntax.self) { return [d.name.text] }
  if let d = decl.as(ClassDeclSyntax.self) { return [d.name.text] }
  if let d = decl.as(EnumDeclSyntax.self) { return [d.name.text] }
  if let d = decl.as(ActorDeclSyntax.self) { return [d.name.text] }
  if let d = decl.as(ProtocolDeclSyntax.self) { return [d.name.text] }
  if let d = decl.as(TypeAliasDeclSyntax.self) { return [d.name.text] }
  return []
}
final class Reads: SyntaxVisitor {
  let field: Field
  var references: [ExprSyntax] = []; var shadows = Set<String>()
  init(_ field: Field) { self.field = field; super.init(viewMode: .sourceAccurate) }
  override func visit(_ n: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
    n.id == field.node.id ? .skipChildren : .visitChildren
  }
  override func visit(_ n: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
    if let m = n.parent?.as(MemberAccessExprSyntax.self), m.declName.id == n.id { return .skipChildren }
    if n.baseName.text == field.name { references.append(ExprSyntax(n)) }
    return .visitChildren
  }
  override func visit(_ n: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
    if n.base?.trimmedDescription == "self", n.declName.baseName.text == field.name { references.append(ExprSyntax(n)) }
    return .visitChildren
  }
  override func visit(_ n: IdentifierPatternSyntax) -> SyntaxVisitorContinueKind {
    shadows.insert(n.identifier.text); return .visitChildren
  }
  override func visit(_ n: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
    shadows.insert((n.secondName ?? n.firstName).text); return .visitChildren
  }
  override func visit(_ n: ClosureParameterSyntax) -> SyntaxVisitorContinueKind {
    shadows.insert((n.secondName ?? n.firstName).text); return .visitChildren
  }
  override func visit(_ n: ClosureShorthandParameterSyntax) -> SyntaxVisitorContinueKind {
    shadows.insert(n.name.text); return .visitChildren
  }
  override func visit(_ n: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
    shadows.insert(n.name.text); return .visitChildren
  }
  override func visit(_ n: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
    if let parameter = n.parameters { shadows.insert(parameter.name.text) }
    else if ["set", "willSet"].contains(n.accessorSpecifier.text) { shadows.insert("newValue") }
    else if n.accessorSpecifier.text == "didSet" { shadows.insert("oldValue") }
    return .visitChildren
  }
  override func visit(_ n: GenericParameterSyntax) -> SyntaxVisitorContinueKind { shadows.insert(n.name.text); return .visitChildren }
  override func visit(_ n: ClosureCaptureSyntax) -> SyntaxVisitorContinueKind {
    shadows.insert(n.name.text); return .visitChildren
  }
  override func visit(_ n: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind { shadows.insert(n.name.text); return .skipChildren }
  override func visit(_ n: StructDeclSyntax) -> SyntaxVisitorContinueKind { shadows.insert(n.name.text); return .skipChildren }
  override func visit(_ n: ClassDeclSyntax) -> SyntaxVisitorContinueKind { shadows.insert(n.name.text); return .skipChildren }
  override func visit(_ n: EnumDeclSyntax) -> SyntaxVisitorContinueKind { shadows.insert(n.name.text); return .skipChildren }
  override func visit(_ n: ActorDeclSyntax) -> SyntaxVisitorContinueKind { shadows.insert(n.name.text); return .skipChildren }
}
final class Calls: SyntaxVisitor {
  var calls: [FunctionCallExprSyntax] = []
  var declarations: [StructDeclSyntax] = []; var extensions = Set<String>()
  override func visit(_ n: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
    calls.append(n); return .visitChildren
  }
  override func visit(_ n: StructDeclSyntax) -> SyntaxVisitorContinueKind {
    declarations.append(n); return .visitChildren
  }
  override func visit(_ n: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
    extensions.insert(n.extendedType.trimmedDescription); return .visitChildren
  }
}
final class Bindings: SyntaxVisitor {
  var names = Set<String>()
  override func visit(_ n: IdentifierPatternSyntax) -> SyntaxVisitorContinueKind { names.insert(n.identifier.text); return .visitChildren }
  override func visit(_ n: FunctionParameterSyntax) -> SyntaxVisitorContinueKind { names.insert((n.secondName ?? n.firstName).text); return .visitChildren }
  override func visit(_ n: ClosureParameterSyntax) -> SyntaxVisitorContinueKind { names.insert((n.secondName ?? n.firstName).text); return .visitChildren }
  override func visit(_ n: ClosureShorthandParameterSyntax) -> SyntaxVisitorContinueKind { names.insert(n.name.text); return .visitChildren }
  override func visit(_ n: FunctionDeclSyntax) -> SyntaxVisitorContinueKind { names.insert(n.name.text); return .visitChildren }
  override func visit(_ n: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
    if let parameter = n.parameters { names.insert(parameter.name.text) }
    else if ["set", "willSet"].contains(n.accessorSpecifier.text) { names.insert("newValue") }
    else if n.accessorSpecifier.text == "didSet" { names.insert("oldValue") }
    return .visitChildren
  }
  override func visit(_ n: GenericParameterSyntax) -> SyntaxVisitorContinueKind { names.insert(n.name.text); return .visitChildren }
  override func visit(_ n: ClosureCaptureSyntax) -> SyntaxVisitorContinueKind {
    names.insert(n.name.text); return .visitChildren
  }
  override func visit(_ n: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind { names.insert(n.name.text); return .visitChildren }
}
struct Inventory {
  let hash: String; let files: [String]
  var owners: [String: Owner] = [:]; var fields: [String: Field] = [:]
  var unknown: [String] = []; var paths: [Path] = []
  init(_ directory: String) throws {
    let input = try SourceInventory(directory)
    hash = input.hash; files = input.files
    let trees = input.sources.map { ($0.tree, $0.converter) }
    var definitions: [(StructDeclSyntax, SourceLocationConverter)] = []
    var allCalls: [(FunctionCallExprSyntax, SourceLocationConverter)] = []
    var extensions = Set<String>(), globals = Set<String>()
    for (tree, converter) in trees {
      let reader = Calls(viewMode: .sourceAccurate); reader.walk(tree)
      let bindings = Bindings(viewMode: .sourceAccurate); bindings.walk(tree); globals.formUnion(bindings.names)
      definitions += reader.declarations.map { ($0, converter) }; allCalls += reader.calls.map { ($0, converter) }
      extensions.formUnion(reader.extensions)
      for item in tree.statements {
        if let d = item.item.as(DeclSyntax.self), !d.is(StructDeclSyntax.self) { globals.formUnion(name(d)) }
      }
    }
    let counts = Dictionary(grouping: definitions, by: { $0.0.name.text }).mapValues(\.count)
    for (decl, converter) in definitions {
      let ownerName = decl.name.text
      guard counts[ownerName] == 1, !globals.contains(ownerName) else {
        unknown.append(ownerName + ": ambiguous written nominal name"); continue
      }
      var ancestor = Syntax(decl).parent
      var nested = false
      while let node = ancestor {
        if node.is(StructDeclSyntax.self) || node.is(ClassDeclSyntax.self) || node.is(EnumDeclSyntax.self) || node.is(ActorDeclSyntax.self) || node.is(FunctionDeclSyntax.self) || node.is(ClosureExprSyntax.self) || node.is(IfConfigDeclSyntax.self) { nested = true }
        ancestor = node.parent
      }
      let eligible = !nested && decl.attributes.isEmpty && decl.genericParameterClause == nil && !extensions.contains(ownerName)
        && !decl.memberBlock.members.contains { $0.decl.is(InitializerDeclSyntax.self) || $0.decl.is(IfConfigDeclSyntax.self) || $0.decl.is(MacroExpansionDeclSyntax.self) }
      var collected: [Field] = []
      if eligible {
        for member in decl.memberBlock.members {
          guard let variable = member.decl.as(VariableDeclSyntax.self), variable.bindingSpecifier.text == "let",
            variable.attributes.isEmpty, !variable.modifiers.contains(where: { $0.name.text == "static" }) else { continue }
          for binding in variable.bindings {
            guard binding.initializer == nil, binding.accessorBlock == nil,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self), let type = binding.typeAnnotation?.type.as(FunctionTypeSyntax.self),
              type.returnClause.type.trimmedDescription == "Void" else { continue }
            collected.append(Field(owner: ownerName, name: identifier.identifier.text, signature: type.tokens(viewMode: .sourceAccurate).map(\.text),
              declaration: Site(file: converter.location(for: AbsolutePosition(utf8Offset: 0)).file, line: converter.location(for: binding.positionAfterSkippingLeadingTrivia).line), node: variable))
          }
        }
      }
      if Set(collected.map(\.name)).count != collected.count {
        unknown.append(ownerName + ": duplicate callback fields"); collected = []
      }
      if !eligible { unknown.append(ownerName + ": unsupported declaration scope or owner") }
      let memberNames = Set(decl.memberBlock.members.flatMap { name($0.decl) })
      owners[ownerName] = Owner(name: ownerName, members: decl.memberBlock.members, fields: collected, names: memberNames, eligible: eligible)
      for field in collected { fields[field.id] = field }
    }
    var edges: [String: Pass] = [:], terminals: [String: Site] = [:], callers: [String: [Site]] = [:]
    func locate(_ n: some SyntaxProtocol, _ c: SourceLocationConverter) -> Site {
      Site(file: c.location(for: AbsolutePosition(utf8Offset: 0)).file, line: c.location(for: n.positionAfterSkippingLeadingTrivia).line)
    }
    for (call, converter) in allCalls {
      guard let callee = call.calledExpression.as(DeclReferenceExprSyntax.self), let child = owners[callee.baseName.text], child.eligible else { continue }
      for argument in call.arguments {
        if let field = child.fields.first(where: { $0.name == argument.label?.text }) { callers[field.id, default: []].append(locate(argument, converter)) }
      }
    }
    for key in fields.keys.sorted() {
      let field = fields[key]!, owner = owners[field.owner]!
      let reads = Reads(field)
      for member in owner.members { reads.walk(member.decl) }
      guard !reads.shadows.contains(field.name) else { unknown.append(key + ": shadowed member references; no simple relay claim"); continue }
      guard reads.references.count == 1, let reference = reads.references.first else { continue }
      let converter = trees.first { $0.1.location(for: AbsolutePosition(utf8Offset: 0)).file == field.declaration.file }!.1
      if let call = reference.parent?.as(FunctionCallExprSyntax.self), call.calledExpression.id == reference.id {
        terminals[key] = locate(reference, converter); continue
      }
      guard let argument = reference.parent?.as(LabeledExprSyntax.self),
        let list = argument.parent?.as(LabeledExprListSyntax.self), let call = list.parent?.as(FunctionCallExprSyntax.self),
        let callee = call.calledExpression.as(DeclReferenceExprSyntax.self), let child = owners[callee.baseName.text], child.eligible,
        !owner.names.contains(child.name), !reads.shadows.contains(child.name),
        let target = child.fields.first(where: { $0.name == argument.label?.text && $0.signature == field.signature }) else { continue }
      edges[key] = Pass(field: key, declaration: field.declaration, argument: locate(argument, converter), destination: target.id)
    }
    let destinations = Set(edges.values.map(\.destination))
    for start in edges.keys.sorted() where !destinations.contains(start) {
      var key = start, visited = Set<String>(), passes: [Pass] = []
      while let edge = edges[key], visited.insert(key).inserted { passes.append(edge); key = edge.destination }
      guard let invocation = terminals[key], let terminal = fields[key] else { continue }
      let incoming = (callers[start] ?? []).sorted { ($0.file, $0.line) < ($1.file, $1.line) }
      paths.append(Path(start: start, signature: fields[start]!.signature, passes: passes, terminal: key,
        terminalDeclaration: terminal.declaration, invocation: invocation, callers: incoming))
    }
  }
}
func compare(_ before: Inventory, _ after: Inventory) -> Report {
  let old = Dictionary(grouping: before.paths, by: \.key)
  var changes: [Change] = []
  for path in after.paths where path.passes.count >= 2 {
    if let previous = old[path.key], previous.count == 1, path.passes.count > previous[0].passes.count {
      changes.append(Change(kind: "expanded-written-relay", before: previous[0], after: path))
    }
  }
  for path in before.paths where path.passes.count >= 2 {
    let root = before.fields[path.start]!
    if let owner = after.owners[root.owner], owner.eligible, !owner.names.contains(root.name) {
      changes.append(Change(kind: "removed-written-root-field", before: path, after: nil))
    }
  }
  return Report(beforeSHA256: before.hash, afterSHA256: after.hash, beforeFiles: before.files, afterFiles: after.files,
    changes: changes.sorted { ($0.before.start, $0.kind) < ($1.before.start, $1.kind) },
    unknown: before.unknown.map { "before: " + $0 } + after.unknown.map { "after: " + $0 }, limits: [
      "Only supplied source inventories: unique plain structs, no explicit/custom init, generic/attributed/extended/conditional owner; const explicit function fields with written return Void",
      "Edges match written struct name, argument label and type tokens; real callee, generated init, type identity, effects and responsibility remain unresolved",
      "Existing complete paths only: expanded to at least two intermediates, or original root field no longer declared; unrelated/unsupported paths omitted, zero is not approval",
      "Source references are not runtime executions; content composition requires stable item contracts, ownership, identity, updates and snapshot substitution"])
}
func render(_ report: Report) -> String {
  let encoder = JSONEncoder(); encoder.outputFormatting = [.withoutEscapingSlashes]
  func quote(_ s: String) -> String { String(decoding: try! encoder.encode(s), as: UTF8.self) }
  func at(_ s: Site) -> String { quote(s.file) + ":" + String(s.line) }
  var lines = ["Callback relay — written field/argument candidates", "Changes: \(report.changes.count); unknown: \(report.unknown.count)"]
  for change in report.changes {
    let path = change.after ?? change.before
    if let after = change.after {
      lines.append("├─ \(quote(path.start)): intermediates \(change.before.passes.count) → \(after.passes.count)")
      lines.append("│  Cost: another container now declares/passes this callback; review leaf action additions against these interfaces")
    } else { lines.append("├─ \(quote(path.start)): original root field no longer declared; runtime dependencies may have moved") }
    for pass in path.passes { lines.append("│  \(quote(pass.field)) @ \(at(pass.declaration)) → \(quote(pass.destination)) @ \(at(pass.argument))") }
    lines.append("│  Terminal call notation: \(quote(path.terminal)) @ \(at(path.invocation)); supplied root arguments: " + path.callers.map(at).joined(separator: ", "))
    if change.after != nil {
      if let comparison = change.comparison {
        lines.append("│  Compare: " + comparison.alternative)
        lines.append("│  Benefit: " + comparison.benefit)
        lines.append("│  Conditions: " + comparison.conditions.joined(separator: "; "))
      }
    }
  }
  for unknown in report.unknown { lines.append("│  Unknown: " + quote(unknown)) }
  lines.append("└─ Limits: " + report.limits.map(quote).joined(separator: "; "))
  return lines.joined(separator: "\n") + "\n"
}
do {
  let args = Array(CommandLine.arguments.dropFirst())
  guard args.count == 2 || (args.count == 3 && args[2] == "--text") else { try fail("usage: callback-probe BEFORE_DIRECTORY AFTER_DIRECTORY [--text]") }
  let result = compare(try Inventory(args[0]), try Inventory(args[1]))
  if args.count == 3 { print(render(result), terminator: "") }
  else {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
    print(String(decoding: try encoder.encode(result), as: UTF8.self))
  }
} catch {
  FileHandle.standardError.write(Data(("callback-probe: \(error)\n").utf8)); exit(2)
}
