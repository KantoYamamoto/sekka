import Foundation
import CryptoKit
import SwiftParser
import SwiftSyntax

struct Site: Codable, Hashable { let file: String; let line: Int }
struct Parameter { let local: String; let label: String; let type: String; let site: Site }
struct Field { let name: String; let type: String; let site: Site }
struct Nominal {
  let name: String; let site: Site; let initializer: InitializerDeclSyntax
  let parameters: [Parameter]; let fields: [Field]; let members: MemberBlockItemListSyntax
  var selector: String { "init(" + parameters.map { $0.label + ":" }.joined() + ")" }
}
struct Assignment {
  let field: String; let value: ExprSyntax; let site: Site
}
struct Step: Codable {
  let owner: String; let selector: String; let parameter: String; let type: String
  let site: Site; let pass: Site; let childField: String; let child: String
}
struct Finding: Codable {
  let dependency: String; let steps: [Step]; let retainedBy: String
  let storage: Site; let writtenUses: [Site]; let alternatives: [String]
}
struct Report: Codable {
  let beforeSHA256: String; let afterSHA256: String; let findings: [Finding]
  let unknown: [String]; let limits: [String]
}
func digest(_ data: Data) -> String {
  SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
func same(_ a: String, _ b: String) -> Bool { Array(a.utf8) == Array(b.utf8) }

final class Names: SyntaxVisitor {
  var references: [DeclReferenceExprSyntax] = []
  var shadows: [String] = []
  override func visit(_ n: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
    if let m = n.parent?.as(MemberAccessExprSyntax.self), m.declName.id == n.id { return .skipChildren }
    references.append(n); return .visitChildren
  }
  override func visit(_ n: IdentifierPatternSyntax) -> SyntaxVisitorContinueKind {
    shadows.append(n.identifier.text); return .visitChildren
  }
  override func visit(_ n: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
    shadows.append((n.secondName ?? n.firstName).text); return .visitChildren
  }
  override func visit(_ n: ClosureParameterSyntax) -> SyntaxVisitorContinueKind {
    shadows.append((n.secondName ?? n.firstName).text); return .visitChildren
  }
  override func visit(_ n: ClosureShorthandParameterSyntax) -> SyntaxVisitorContinueKind {
    shadows.append(n.name.text); return .visitChildren
  }
}
struct Snapshot {
  let bytes: Data; let file: String; let tree: SourceFileSyntax
  var types: [String: Nominal] = [:]; var unknown: [String] = []
  let converter: SourceLocationConverter
  func site(_ n: some SyntaxProtocol) -> Site {
    Site(file: file, line: converter.location(for: n.positionAfterSkippingLeadingTrivia).line)
  }
  init(_ path: String) throws {
    let url = URL(fileURLWithPath: path).standardizedFileURL
    guard try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
      throw Failure.message("symlink input is outside this prototype")
    }
    let data = try Data(contentsOf: url)
    guard data.count <= 4_000_000, let source = String(data: data, encoding: .utf8), Data(source.utf8) == data else {
      throw Failure.message("input must be UTF-8 and at most 4MB")
    }
    let parsed = Array(source.utf8).withUnsafeBufferPointer {
      Parser.parse(source: $0, swiftVersion: .v6)
    }
    guard !parsed.hasError else { throw Failure.message("Swift parse failed: " + path) }
    bytes = data; file = path; tree = parsed
    converter = SourceLocationConverter(fileName: path, tree: parsed)
    var counts: [String: Int] = [:], extensions = Set<String>(), conflicting = Set<String>()
    for item in tree.statements {
      if let n = item.item.as(StructDeclSyntax.self) { counts[n.name.text, default: 0] += 1 }
      else if let n = item.item.as(ClassDeclSyntax.self) { counts[n.name.text, default: 0] += 1 }
      else if let n = item.item.as(ExtensionDeclSyntax.self) { extensions.insert(n.extendedType.trimmedDescription) }
      else if let n = item.item.as(FunctionDeclSyntax.self) { conflicting.insert(n.name.text) }
      else if let n = item.item.as(TypeAliasDeclSyntax.self) { conflicting.insert(n.name.text) }
      else if let n = item.item.as(VariableDeclSyntax.self) {
        for b in n.bindings { if let name = b.pattern.as(IdentifierPatternSyntax.self)?.identifier.text { conflicting.insert(name) } }
      }
      else if item.item.is(IfConfigDeclSyntax.self) || item.item.is(MacroExpansionDeclSyntax.self) {
        if unknown.isEmpty { unknown.append("conditional/macro declarations: entire single-file analysis skipped") }
      }
    }
    guard unknown.isEmpty else { return }
    for item in tree.statements {
      let name: String, block: MemberBlockSyntax, node: Syntax, supported: Bool
      if let n = item.item.as(StructDeclSyntax.self) {
        name = n.name.text; block = n.memberBlock; node = Syntax(n)
        supported = n.genericParameterClause == nil && n.attributes.isEmpty
      } else if let n = item.item.as(ClassDeclSyntax.self) {
        name = n.name.text; block = n.memberBlock; node = Syntax(n)
        supported = n.genericParameterClause == nil && n.inheritanceClause == nil && n.attributes.isEmpty
      } else { continue }
      guard supported, counts[name] == 1, !extensions.contains(name), !conflicting.contains(name) else {
        unknown.append(name + ": ambiguous/extended/generic/attributed owner"); continue
      }
      let initializers = block.members.compactMap { $0.decl.as(InitializerDeclSyntax.self) }
      // Implicit memberwise initialization is deliberately not inferred.
      guard initializers.count == 1, let initDecl = initializers.first, initDecl.body != nil,
        initDecl.genericParameterClause == nil, initDecl.attributes.isEmpty,
        initDecl.signature.effectSpecifiers == nil, initDecl.optionalMark == nil else {
        unknown.append(name + ": requires one explicit ordinary initializer"); continue
      }
      var params: [Parameter] = [], fields: [Field] = [], valid = true
      for p in initDecl.signature.parameterClause.parameters {
        guard let type = p.type.as(IdentifierTypeSyntax.self), type.genericArgumentClause == nil,
          p.ellipsis == nil, p.attributes.isEmpty, p.modifiers.isEmpty else { valid = false; break }
        let local = (p.secondName ?? p.firstName).text
        guard local != "_" else { valid = false; break }
        params.append(Parameter(local: local, label: p.firstName.text, type: type.name.text, site: site(p)))
      }
      for m in block.members {
        if let variable = m.decl.as(VariableDeclSyntax.self) {
          guard variable.attributes.isEmpty else { valid = false; break }
          if variable.modifiers.contains(where: { ["static", "class"].contains($0.name.text) }) { continue }
          for b in variable.bindings where b.accessorBlock == nil {
            guard let identifier = b.pattern.as(IdentifierPatternSyntax.self), let type = b.typeAnnotation?.type.as(IdentifierTypeSyntax.self),
              type.genericArgumentClause == nil, b.initializer == nil else { valid = false; break }
            fields.append(Field(name: identifier.identifier.text, type: type.name.text, site: site(b)))
          }
        }
      }
      guard valid, Set(params.map(\.local)).count == params.count,
        Set(params.map(\.label)).count == params.count, Set(fields.map(\.name)).count == fields.count else {
        unknown.append(name + ": unsupported parameter/storage shape"); continue
      }
      types[name] = Nominal(name: name, site: site(node), initializer: initDecl,
        parameters: params, fields: fields, members: block.members)
    }
  }
  func assignments(_ owner: Nominal) -> [Assignment]? {
    var result: [Assignment] = []
    for item in owner.initializer.body!.statements {
      guard let sequence = item.item.as(SequenceExprSyntax.self) else { return nil }
      let elements = Array(sequence.elements)
      guard elements.count == 3, elements[1].is(AssignmentExprSyntax.self) else { return nil }
      let field: String
      if let ref = elements[0].as(DeclReferenceExprSyntax.self) { field = ref.baseName.text }
      else if let member = elements[0].as(MemberAccessExprSyntax.self), member.base?.trimmedDescription == "self" { field = member.declName.baseName.text }
      else { return nil }
      guard owner.fields.contains(where: { same($0.name, field) }) else { return nil }
      let rhs = elements[2]
      if let ref = rhs.as(DeclReferenceExprSyntax.self) {
        guard owner.parameters.contains(where: { same($0.local, ref.baseName.text) }) else { return nil }
      } else if let call = rhs.as(FunctionCallExprSyntax.self), let callee = call.calledExpression.as(DeclReferenceExprSyntax.self) {
        let calleeName = callee.baseName.text
        let shadowed = owner.parameters.contains { same($0.local, calleeName) }
          || owner.fields.contains { same($0.name, calleeName) }
          || owner.members.contains { member in
            if let v = member.decl.as(VariableDeclSyntax.self) {
              return v.bindings.contains { same($0.pattern.trimmedDescription, calleeName) }
            }
            if let f = member.decl.as(FunctionDeclSyntax.self) { return same(f.name.text, calleeName) }
            if let n = member.decl.as(StructDeclSyntax.self) { return same(n.name.text, calleeName) }
            if let n = member.decl.as(ClassDeclSyntax.self) { return same(n.name.text, calleeName) }
            if let n = member.decl.as(EnumDeclSyntax.self) { return same(n.name.text, calleeName) }
            if let n = member.decl.as(ActorDeclSyntax.self) { return same(n.name.text, calleeName) }
            if let n = member.decl.as(ProtocolDeclSyntax.self) { return same(n.name.text, calleeName) }
            if let n = member.decl.as(TypeAliasDeclSyntax.self) { return same(n.name.text, calleeName) }
            // Conditional members and macros may introduce otherwise unseen names.
            return member.decl.is(IfConfigDeclSyntax.self) || member.decl.is(MacroExpansionDeclSyntax.self)
          }
        guard !shadowed else { return nil }
        guard let child = types[callee.baseName.text], let stored = owner.fields.first(where: { same($0.name, field) }),
          same(stored.type, child.name), call.trailingClosure == nil, call.additionalTrailingClosures.isEmpty else { return nil }
        for arg in call.arguments {
          guard let ref = arg.expression.as(DeclReferenceExprSyntax.self),
            owner.parameters.contains(where: { same($0.local, ref.baseName.text) }) else { return nil }
        }
        let labels = call.arguments.map { $0.label?.text ?? "_" }
        guard labels == child.parameters.map(\.label) else { return nil }
      } else { return nil }
      result.append(Assignment(field: field, value: rhs, site: site(rhs)))
    }
    guard Set(result.map(\.field)).count == result.count else { return nil }
    return result
  }
  func otherUses(_ owner: Nominal, name: String, property: Bool) -> [Site] {
    var found: [Site] = []
    for member in owner.members where !member.decl.is(InitializerDeclSyntax.self) {
      if member.decl.is(StructDeclSyntax.self) || member.decl.is(ClassDeclSyntax.self)
        || member.decl.is(EnumDeclSyntax.self) || member.decl.is(ActorDeclSyntax.self) { continue }
      let reader = Names(viewMode: .sourceAccurate); reader.walk(member.decl)
      let params = member.decl.as(FunctionDeclSyntax.self)?.signature.parameterClause.parameters.map { ($0.secondName ?? $0.firstName).text } ?? []
      let shadowed = (reader.shadows + params).contains(name)
      if !shadowed { found += reader.references.filter { same($0.baseName.text, name) }.map { site($0) } }
      if property {
        let explicit = SelfMembers(name: name, locate: site); explicit.walk(member.decl); found += explicit.sites
      }
    }
    return Array(Set(found)).sorted { $0.line < $1.line }
  }
}
final class SelfMembers: SyntaxVisitor {
  let name: String; let locate: (Syntax) -> Site; var sites: [Site] = []
  init(name: String, locate: @escaping (Syntax) -> Site) {
    self.name = name; self.locate = locate; super.init(viewMode: .sourceAccurate)
  }
  override func visit(_ n: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
    if n.base?.trimmedDescription == "self", same(n.declName.baseName.text, name) { sites.append(locate(Syntax(n))) }
    return .visitChildren
  }
  override func visit(_ n: StructDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ n: ClassDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ n: EnumDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ n: ActorDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
}
enum Failure: Error { case message(String) }

func compare(_ old: Snapshot, _ new: Snapshot) -> Report {
  struct Key: Hashable { let owner: String; let label: String }
  struct Edge { let step: Step; let target: Key }
  var edges: [Key: Edge] = [:], terminals: [Key: (Field, [Site])] = [:]
  var unknown = old.unknown.map { "before: " + $0 } + new.unknown.map { "after: " + $0 }
  for name in new.types.keys.sorted() {
    let owner = new.types[name]!
    guard let previous = old.types[name] else { continue }
    guard let assignments = new.assignments(owner) else {
      unknown.append(name + ": initializer has processing/lifetime/unsupported syntax; no relocation claim"); continue
    }
    for parameter in owner.parameters where !previous.parameters.contains(where: { same($0.label, parameter.label) && same($0.type, parameter.type) }) {
      // Count references in the entire initializer, not just the proposed argument.
      let reader = Names(viewMode: .sourceAccurate); reader.walk(owner.initializer.body!)
      let uses = reader.references.filter { same($0.baseName.text, parameter.local) }
      let key = Key(owner: name, label: parameter.label)
      for assignment in assignments {
        if let ref = assignment.value.as(DeclReferenceExprSyntax.self), same(ref.baseName.text, parameter.local), uses.count == 1,
          let field = owner.fields.first(where: { same($0.name, assignment.field) && same($0.type, parameter.type) }) {
          let writtenUses = new.otherUses(owner, name: field.name, property: true)
          if !writtenUses.isEmpty { terminals[key] = (field, writtenUses) }
        }
        guard uses.count == 1, let call = assignment.value.as(FunctionCallExprSyntax.self),
          let callee = call.calledExpression.as(DeclReferenceExprSyntax.self), let child = new.types[callee.baseName.text] else { continue }
        for arg in call.arguments {
          guard let ref = arg.expression.as(DeclReferenceExprSyntax.self), same(ref.baseName.text, parameter.local),
            let childParam = child.parameters.first(where: { same($0.label, arg.label?.text ?? "_") && same($0.type, parameter.type) }) else { continue }
          edges[key] = Edge(step: Step(owner: name, selector: owner.selector, parameter: parameter.local, type: parameter.type,
            site: parameter.site, pass: new.site(arg), childField: assignment.field, child: child.name),
            target: Key(owner: child.name, label: childParam.label))
        }
      }
    }
  }
  var findings: [Finding] = []
  let targets = Set(edges.values.map(\.target))
  for start in edges.keys.filter({ !targets.contains($0) }).sorted(by: { ($0.owner, $0.label) < ($1.owner, $1.label) }) {
    var key = start, visited = Set<Key>(), steps: [Step] = []
    while let edge = edges[key], visited.insert(key).inserted { steps.append(edge.step); key = edge.target }
    guard steps.count >= 2, let (field, uses) = terminals[key] else { continue }
    let alternatives = steps.reversed().map { $0.owner + "(" + $0.childField + ": " + $0.child + ")" }
    findings.append(Finding(dependency: steps[0].type, steps: steps, retainedBy: key.owner,
      storage: field.site, writtenUses: uses, alternatives: alternatives))
  }
  return Report(beforeSHA256: digest(old.bytes), afterSHA256: digest(new.bytes), findings: findings,
    unknown: unknown.sorted(), limits: [
      "Single-file, unique explicit nominal names/one ordinary initializer/direct assignments only; imports and real callees unresolved",
      "New constructor parameters only; at least two forwarding owners and a retained field with written use",
      "Written references are not proof of effects or responsibility; no lifecycle, access or API-contract judgment",
      "A relocation candidate is not a required fix; zero is not architecture approval"])
}
func render(_ report: Report) -> String {
  func quote(_ s: String) -> String {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.withoutEscapingSlashes]
    return String(data: try! encoder.encode(s), encoding: .utf8)!
  }
  func location(_ s: Site) -> String { quote(s.file) + ":" + String(s.line) }
  var lines = ["Dependency relay — written construction candidates", "Candidates: \(report.findings.count); unsupported: \(report.unknown.count)"]
  for f in report.findings {
    lines.append("├─ \(quote(f.dependency)): new arguments forward through \(f.steps.count) intermediate types")
    for s in f.steps { lines.append("│  \(quote(s.owner + "." + s.selector)) @ \(location(s.site)) → \(quote(s.child)) via \(quote(s.childField)) @ \(location(s.pass))") }
    lines.append("│  Retained by \(quote(f.retainedBy)) @ \(location(f.storage)); written uses: " + f.writtenUses.map(location).joined(separator: ", "))
    lines.append("│  Compare: construct \(quote(f.retainedBy)) at the calling site, then inject " + f.alternatives.map(quote).joined(separator: " → "))
    lines.append("│  Benefit: future leaf dependency additions need not widen these intermediate constructor APIs")
    lines.append("│  Conditions: preserve creation time, ownership, access and the API's encapsulation; introducing new constructors has a cost")
  }
  for u in report.unknown { lines.append("│  Unanalyzed: " + quote(u)) }
  lines.append("└─ Limits: " + report.limits.map(quote).joined(separator: "; "))
  return lines.joined(separator: "\n") + "\n"
}
do {
  let args = Array(CommandLine.arguments.dropFirst())
  guard args.count == 2 || (args.count == 3 && args[2] == "--text") else {
    throw Failure.message("usage: relay-probe before.swift after.swift [--text]")
  }
  let result = compare(try Snapshot(args[0]), try Snapshot(args[1]))
  if args.count == 3 { print(render(result), terminator: "") }
  else {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
    print(String(decoding: try encoder.encode(result), as: UTF8.self))
  }
} catch {
  FileHandle.standardError.write(Data(("relay-probe: \(error)\n").utf8)); exit(2)
}
