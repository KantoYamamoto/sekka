import Foundation
import SwiftSyntax

public struct Site: Encodable { let file: String; let line: Int }
struct API {
  let owner: String; let label: String; let spelling: String; let elements: [[String]]
  let shell: [String]; let declaration: Site; let labels: Set<String>; let required: Set<String>
  var id: String { owner + ".init(" + label + ":)" }
}
struct Use {
  let key: [String]; let site: Site; let owner: String; let expression: ExprSyntax
}
public struct Adaptation: Encodable {
  let owner: String; let before: Site; let after: Site
  let discardedSlots: [Int]
  let bodyComparison = "same-tokens-after-parameter-reference-normalization"
}
public struct Comparison: Encodable {
  let question = "Must adding callback context change the arity of existing clients that discard it?"
  let alternatives = [
    "Keep the positional callback: simplest for an isolated addition",
    "One event payload: stable callback arity for future metadata added to the same event type; initial caller migration and producer/initializer changes still remain",
    "Keep the existing callback and add a context-specific entry/adapter: preserves old callers but adds entry/notification contracts"]
  let conditions = ["Confirm future metadata evolution before paying migration cost", "Preserve event acquisition time, coordinate/context meaning, ownership and Sendable requirements", "Neither token equality nor ignored slots proves a defect or behavioral equivalence"]
}
public struct Change: Encodable {
  let api: String; let beforeType: String; let afterType: String
  let beforeDeclaration: Site; let afterDeclaration: Site; let adaptations: [Adaptation]
  let comparison = Comparison()
}
public struct Unknown: Encodable { let api: String; let site: Site?; let reason: String }
public struct Report: Encodable {
  let beforeSHA256: String; let afterSHA256: String; let beforeFiles: [String]; let afterFiles: [String]
  public let changes: [Change]; public let unknown: [Unknown]; public let limits: [String]
}
func tokens(_ n: some SyntaxProtocol) -> [String] { n.tokens(viewMode: .sourceAccurate).map(\.text) }
func site(_ n: some SyntaxProtocol, _ source: ParsedSource) -> Site {
  Site(file: source.path, line: source.converter.location(for: n.positionAfterSkippingLeadingTrivia).line)
}
func functionType(_ type: TypeSyntax) -> FunctionTypeSyntax? {
  if let function = type.as(FunctionTypeSyntax.self) { return function }
  if let attributed = type.as(AttributedTypeSyntax.self) { return functionType(attributed.baseType) }
  return nil
}
func nominalName(_ n: Syntax) -> String? {
  if let d = n.as(StructDeclSyntax.self) { return d.name.text }
  if let d = n.as(ClassDeclSyntax.self) { return d.name.text }
  if let d = n.as(EnumDeclSyntax.self) { return d.name.text }
  if let d = n.as(ActorDeclSyntax.self) { return d.name.text }
  if let d = n.as(ProtocolDeclSyntax.self) { return d.name.text }
  return nil
}
/// Conservative inventory-wide ambiguity guard; it does not resolve Swift names.
final class Reader: SyntaxVisitor {
  var declarations: [StructDeclSyntax] = []; var calls: [FunctionCallExprSyntax] = []
  var bindings = Set<String>(); var extensions = Set<String>()
  override func visit(_ n: StructDeclSyntax) -> SyntaxVisitorContinueKind { declarations.append(n); return .visitChildren }
  override func visit(_ n: ClassDeclSyntax) -> SyntaxVisitorContinueKind { bindings.insert(n.name.text); return .visitChildren }
  override func visit(_ n: EnumDeclSyntax) -> SyntaxVisitorContinueKind { bindings.insert(n.name.text); return .visitChildren }
  override func visit(_ n: ActorDeclSyntax) -> SyntaxVisitorContinueKind { bindings.insert(n.name.text); return .visitChildren }
  override func visit(_ n: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind { bindings.insert(n.name.text); return .visitChildren }
  override func visit(_ n: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind { bindings.insert(n.name.text); return .visitChildren }
  override func visit(_ n: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind { extensions.insert(n.extendedType.trimmedDescription); return .visitChildren }
  override func visit(_ n: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind { calls.append(n); return .visitChildren }
  override func visit(_ n: IdentifierPatternSyntax) -> SyntaxVisitorContinueKind { bindings.insert(n.identifier.text); return .visitChildren }
  override func visit(_ n: FunctionParameterSyntax) -> SyntaxVisitorContinueKind { bindings.insert((n.secondName ?? n.firstName).text); return .visitChildren }
  override func visit(_ n: ClosureParameterSyntax) -> SyntaxVisitorContinueKind { bindings.insert((n.secondName ?? n.firstName).text); return .visitChildren }
  override func visit(_ n: ClosureShorthandParameterSyntax) -> SyntaxVisitorContinueKind { bindings.insert(n.name.text); return .visitChildren }
  override func visit(_ n: ClosureCaptureSyntax) -> SyntaxVisitorContinueKind { bindings.insert(n.name.text); return .visitChildren }
  override func visit(_ n: GenericParameterSyntax) -> SyntaxVisitorContinueKind { bindings.insert(n.name.text); return .visitChildren }
  override func visit(_ n: FunctionDeclSyntax) -> SyntaxVisitorContinueKind { bindings.insert(n.name.text); return .visitChildren }
  override func visit(_ n: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
    if let p = n.parameters { bindings.insert(p.name.text) }
    else if ["set", "willSet"].contains(n.accessorSpecifier.text) { bindings.insert("newValue") }
    else if n.accessorSpecifier.text == "didSet" { bindings.insert("oldValue") }
    return .visitChildren
  }
}
func ancestry(_ node: some SyntaxProtocol) -> [Syntax] {
  var list: [Syntax] = [], next = Syntax(node).parent
  while let n = next { list.append(n); next = n.parent }
  return list
}
func lexicalOwner(_ call: FunctionCallExprSyntax) -> [String]? {
  let parents = ancestry(call)
  guard !parents.contains(where: { $0.is(IfConfigDeclSyntax.self) || $0.is(MacroExpansionExprSyntax.self) || $0.is(MacroExpansionDeclSyntax.self) }) else { return nil }
  var result: [String] = []
  for p in parents.reversed() {
    if let name = nominalName(p) { result.append("type:" + name) }
    if let d = p.as(ExtensionDeclSyntax.self) { result.append("extension:" + d.extendedType.trimmedDescription) }
    if let d = p.as(FunctionDeclSyntax.self) { result.append("func:" + d.name.text); result += tokens(d.signature) }
    if let d = p.as(PatternBindingSyntax.self) { result.append("binding:"); result += tokens(d.pattern) }
    if let d = p.as(InitializerDeclSyntax.self) { result.append("init:"); result += tokens(d.signature) }
    if let d = p.as(AccessorDeclSyntax.self) { result.append("accessor:" + d.accessorSpecifier.text) }
  }
  return result.isEmpty ? nil : result
}
struct Index {
  var apis: [String: API] = [:]; var uses: [String: [Use]] = [:]; var unknown: [Unknown] = []
  init(_ input: SourceInventory) {
    let readers = input.sources.map { source -> Reader in let r = Reader(viewMode: .sourceAccurate); r.walk(source.tree); return r }
    let definitions = readers.flatMap(\.declarations)
    let counts = Dictionary(grouping: definitions, by: { $0.name.text }).mapValues(\.count)
    let bindings = readers.reduce(into: Set<String>()) { $0.formUnion($1.bindings) }
    let extensions = readers.reduce(into: Set<String>()) { $0.formUnion($1.extensions) }
    for (source, reader) in zip(input.sources, readers) {
      for decl in reader.declarations {
        let owner = decl.name.text
        let inits = decl.memberBlock.members.compactMap { $0.decl.as(InitializerDeclSyntax.self) }
        guard inits.count == 1 else { continue }
        let initializer = inits[0]
        let params = initializer.signature.parameterClause.parameters
        let labels = Set(params.map { $0.firstName.text })
        let required = Set(params.filter { $0.defaultValue == nil }.map { $0.firstName.text })
        for param in params {
          guard let function = functionType(param.type), function.returnClause.type.trimmedDescription == "Void", param.firstName.text != "_" else { continue }
          let id = owner + ".init(" + param.firstName.text + ":)"
          guard counts[owner] == 1, !bindings.contains(owner), !extensions.contains(owner), decl.attributes.isEmpty,
            !ancestry(decl).contains(where: { nominalName($0) != nil || $0.is(IfConfigDeclSyntax.self) || $0.is(ExtensionDeclSyntax.self) || $0.is(FunctionDeclSyntax.self) || $0.is(ClosureExprSyntax.self) }),
            !decl.memberBlock.members.contains(where: { $0.decl.is(IfConfigDeclSyntax.self) || $0.decl.is(MacroExpansionDeclSyntax.self) }),
            labels.count == params.count, !labels.contains("_") else {
            unknown.append(Unknown(api: id, site: site(param, source), reason: "ambiguous or unsupported written constructor")); continue
          }
          let lower = function.parameters.position.utf8Offset, upper = function.parameters.endPosition.utf8Offset
          let shell = param.type.tokens(viewMode: .sourceAccurate).filter { $0.position.utf8Offset < lower || $0.position.utf8Offset >= upper }.map(\.text)
          apis[id] = API(owner: owner, label: param.firstName.text, spelling: param.type.trimmedDescription,
            elements: function.parameters.map { tokens($0.with(\.trailingComma, nil)) }, shell: shell,
            declaration: site(param, source), labels: labels, required: required)
        }
      }
    }
    for (source, reader) in zip(input.sources, readers) {
      for call in reader.calls {
        // Macro-generated examples are outside this comparison, not repeated per-call notices.
        if ancestry(call).contains(where: { $0.is(MacroExpansionExprSyntax.self) || $0.is(MacroExpansionDeclSyntax.self) }) { continue }
        guard let callee = call.calledExpression.as(DeclReferenceExprSyntax.self) else { continue }
        for api in apis.values.sorted(by: { $0.id < $1.id }) where api.owner == callee.baseName.text {
          guard let arg = call.arguments.first(where: { $0.label?.text == api.label }) else { continue }
          guard let owner = lexicalOwner(call), call.trailingClosure == nil, call.additionalTrailingClosures.isEmpty,
            call.arguments.allSatisfy({ $0.label != nil }),
            Set(call.arguments.compactMap { $0.label?.text }).count == call.arguments.count,
            api.required.isSubset(of: Set(call.arguments.compactMap { $0.label?.text })),
            Set(call.arguments.compactMap { $0.label?.text }).isSubset(of: api.labels) else {
            unknown.append(Unknown(api: api.id, site: site(arg, source), reason: "unsupported call scope/labels/trailing closure")); continue
          }
          // Keep each argument boundary; never pair by an ordinal or line-number guess.
          var key = [source.path] + owner
          for other in call.arguments where other.id != arg.id { key += ["argument:"] + tokens(other.with(\.trailingComma, nil)) }
          uses[api.id, default: []].append(Use(key: key, site: site(arg, source), owner: owner.joined(separator: " / "), expression: arg.expression))
        }
      }
    }
  }
}
/// Normalize parameter *expression references*, preserving labels, member names and literal text.
/// Any competing binding or nested closure makes this narrow comparison unsupported.
final class BodyReferences: SyntaxVisitor {
  var references: [DeclReferenceExprSyntax] = []; var bindings = Set<String>(); var unsupported = false
  override func visit(_ n: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
    if let p = n.parent?.as(MemberAccessExprSyntax.self), p.declName.id == n.id { return .skipChildren }
    references.append(n); return .visitChildren
  }
  override func visit(_ n: IdentifierPatternSyntax) -> SyntaxVisitorContinueKind { bindings.insert(n.identifier.text); return .visitChildren }
  override func visit(_ n: ClosureExprSyntax) -> SyntaxVisitorContinueKind { unsupported = true; return .skipChildren }
  override func visit(_ n: FunctionDeclSyntax) -> SyntaxVisitorContinueKind { unsupported = true; return .skipChildren }
  override func visit(_ n: StructDeclSyntax) -> SyntaxVisitorContinueKind { unsupported = true; return .skipChildren }
  override func visit(_ n: ClassDeclSyntax) -> SyntaxVisitorContinueKind { unsupported = true; return .skipChildren }
  override func visit(_ n: EnumDeclSyntax) -> SyntaxVisitorContinueKind { unsupported = true; return .skipChildren }
  override func visit(_ n: ActorDeclSyntax) -> SyntaxVisitorContinueKind { unsupported = true; return .skipChildren }
  override func visit(_ n: CatchClauseSyntax) -> SyntaxVisitorContinueKind { unsupported = true; return .skipChildren }
  override func visit(_ n: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind { unsupported = true; return .skipChildren }
  override func visit(_ n: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind { unsupported = true; return .skipChildren }
  override func visit(_ n: IfConfigDeclSyntax) -> SyntaxVisitorContinueKind { unsupported = true; return .skipChildren }
  override func visit(_ n: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind { unsupported = true; return .skipChildren }
}
struct Body {
  let normalized: [String]; let referencedSlots: Set<Int>; let parameters: [String]
  init?(_ closure: ClosureExprSyntax, arity: Int, explicitRequired: Bool) {
    let parameters: [String]
    if let signature = closure.signature {
      guard signature.capture == nil, signature.attributes.isEmpty, signature.returnClause == nil, signature.effectSpecifiers == nil,
        let clause = signature.parameterClause, let list = clause.as(ClosureShorthandParameterListSyntax.self), list.count == arity else { return nil }
      parameters = list.map { $0.name.text }
    } else {
      guard !explicitRequired else { return nil }
      parameters = (0..<arity).map { "$" + String($0) }
    }
    guard Set(parameters.filter { $0 != "_" }).count == parameters.filter({ $0 != "_" }).count else { return nil }
    let visitor = BodyReferences(viewMode: .sourceAccurate); visitor.walk(closure.statements)
    guard !visitor.unsupported, visitor.bindings.isDisjoint(with: Set(parameters)),
      !visitor.references.contains(where: { $0.argumentNames != nil && parameters.contains($0.baseName.text) }) else { return nil }
    let slots = Dictionary(uniqueKeysWithValues: parameters.enumerated().filter { $0.element != "_" }.map { ($0.element, $0.offset) })
    var substitutions: [Int: Int] = [:], used = Set<Int>()
    for reference in visitor.references {
      if let slot = slots[reference.baseName.text] { substitutions[reference.baseName.position.utf8Offset] = slot; used.insert(slot) }
    }
    normalized = closure.statements.tokens(viewMode: .sourceAccurate).map { token in
      substitutions[token.position.utf8Offset].map { "parameter-slot:\($0)" } ?? "literal-token:" + token.text
    }
    self.parameters = parameters
    referencedSlots = used
  }
}
public func compare(_ before: SourceInventory, _ after: SourceInventory) -> Report {
  let old = Index(before), new = Index(after)
  var unknown = old.unknown.map { Unknown(api: $0.api, site: $0.site, reason: "before: " + $0.reason) } + new.unknown.map { Unknown(api: $0.api, site: $0.site, reason: "after: " + $0.reason) }
  var changes: [Change] = []
  var comparedAPIs = Set<String>()
  for id in new.apis.keys.sorted() {
    guard let a = old.apis[id], let b = new.apis[id], !a.elements.isEmpty, b.elements.count > a.elements.count,
      b.elements.prefix(a.elements.count).elementsEqual(a.elements), a.shell == b.shell else { continue }
    comparedAPIs.insert(id)
    let prior = Dictionary(grouping: old.uses[id] ?? [], by: \.key)
    let current = Dictionary(grouping: new.uses[id] ?? [], by: \.key)
    var adaptations: [Adaptation] = []
    for use in new.uses[id] ?? [] {
      guard let pair = prior[use.key], pair.count == 1, current[use.key]?.count == 1 else {
        unknown.append(Unknown(api: id, site: use.site, reason: "no unique before/after call pair by lexical owner and other argument tokens")); continue
      }
      guard let oldClosure = pair[0].expression.as(ClosureExprSyntax.self), let closure = use.expression.as(ClosureExprSyntax.self) else {
        unknown.append(Unknown(api: id, site: use.site, reason: "body comparison requires closures on both sides; direct references are not compared")); continue
      }
      guard let oldBody = Body(oldClosure, arity: a.elements.count, explicitRequired: false),
        let body = Body(closure, arity: b.elements.count, explicitRequired: true) else {
        unknown.append(Unknown(api: id, site: use.site, reason: "unsupported closure bindings/signature/body")); continue
      }
      let added = Array(a.elements.count..<b.elements.count)
      guard added.allSatisfy({ body.parameters[$0] == "_" }), !oldBody.referencedSlots.isEmpty,
        body.normalized == oldBody.normalized else { continue }
      adaptations.append(Adaptation(owner: use.owner, before: pair[0].site, after: use.site, discardedSlots: added))
    }
    if !adaptations.isEmpty {
      changes.append(Change(api: id, beforeType: a.spelling, afterType: b.spelling,
        beforeDeclaration: a.declaration, afterDeclaration: b.declaration, adaptations: adaptations))
    }
  }
  return Report(beforeSHA256: before.hash, afterSHA256: after.hash, beforeFiles: before.files, afterFiles: after.files,
    changes: changes, unknown: unknown.filter { comparedAPIs.contains($0.api) }, limits: [
      "Supplied inventory only; unique written struct name and one explicit initializer; direct named calls and trailing parameter additions only",
      "Pairs use file/lexical owner/non-callback argument tokens, not runtime identity; callee, generic specialization, type identity and overload resolution remain unknown",
      "Only pre-existing closures using old parameters; appended slots must be explicit underscores and normalized body tokens identical; direct references, nested closures, shadows, macros and ambiguous pairs are excluded",
      "Unknown entries cover eligible widened APIs only; other APIs and macro-generated examples are outside the reported comparison",
      "Syntax does not prove behavior, causal change cost, a defect or future requirements; zero is not design approval"])
}
public func render(_ report: Report) -> String {
  let encoder = JSONEncoder(); encoder.outputFormatting = [.withoutEscapingSlashes]
  func quote(_ s: String) -> String { String(decoding: try! encoder.encode(s), as: UTF8.self) }
  func at(_ s: Site) -> String { quote(s.file) + ":" + String(s.line) }
  var lines = ["Callback contract — adaptation of existing clients", "Changes: \(report.changes.count); unknown: \(report.unknown.count)"]
  for change in report.changes {
    lines += ["├─ \(quote(change.api)): \(quote(change.beforeType)) → \(quote(change.afterType))",
      "│  API: \(at(change.beforeDeclaration)) → \(at(change.afterDeclaration))",
      "│  \(change.adaptations.count) existing closure(s) discard added slots; old parameter-reference-normalized body tokens match"]
    for use in change.adaptations { lines.append("│  ├─ \(quote(use.owner)): \(at(use.before)) → \(at(use.after)); discarded zero-based slots \(use.discardedSlots)") }
    lines.append("│  Question: " + change.comparison.question)
    for alternative in change.comparison.alternatives { lines.append("│  Compare: " + alternative) }
    lines.append("│  Conditions: " + change.comparison.conditions.joined(separator: "; "))
  }
  for item in report.unknown { lines.append("│  Unknown \(quote(item.api))" + (item.site.map { " @ " + at($0) } ?? "") + ": " + item.reason) }
  lines.append("└─ Limits: " + report.limits.joined(separator: "; "))
  return lines.joined(separator: "\n") + "\n"
}