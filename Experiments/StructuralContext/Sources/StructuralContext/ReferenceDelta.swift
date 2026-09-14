import Foundation
import SwiftParser
import SwiftSyntax

public struct SourceSite: Codable, Equatable, Sendable {
  public let file: String
  public let line: Int
  public let endLine: Int
  public let declaration: String
  public let signature: String?
}

public struct ReferenceCount: Codable, Sendable {
  public let spelling: String
  public let beforeCount: Int
  public let afterCount: Int
}

public struct ReferenceLocation: Codable, Sendable {
  public let declaration: SourceSite
  public let count: Int
  public let sites: [SourceSite]
  public let omittedSites: Int
}

public struct ReferenceChange: Codable, Sendable {
  public let before: ReferenceLocation
  public let after: ReferenceLocation
  public let increasedReferences: [ReferenceCount]
  public let omittedIncreasedReferences: Int
  public let bodyChanged: Bool
}

public struct ReferenceContext: Codable, Sendable {
  public let spelling: String
  public let reductions: [ReferenceChange]
  public let omittedReductions: Int
  public let retained: [ReferenceChange]
  public let omittedRetained: Int
}

public struct ContextReport: Codable, Sendable {
  public let scope: String
  public let limitations: [String]
  public let beforeFileCount: Int
  public let afterFileCount: Int
  public let changedDeclarations: Int
  public let contexts: [ReferenceContext]
  public let omittedContexts: Int
  public let unpairedBefore: Int
  public let unpairedAfter: Int
  public let ambiguousKeys: Int
}

public enum ContextError: Error { case malformed(String) }

public enum ReferenceDelta {
  public static func compare(before: [(String, String)], after: [(String, String)]) throws -> ContextReport {
    let old = try collect(before), new = try collect(after)
    let oldIDs = Dictionary(grouping: old, by: \.id), newIDs = Dictionary(grouping: new, by: \.id)
    let ids = Set(oldIDs.keys).union(newIDs.keys).sorted()
    var pairs: [(Declaration, Declaration)] = []
    var unpairedBefore = 0, unpairedAfter = 0, ambiguous = 0
    for id in ids {
      let a = oldIDs[id, default: []], b = newIDs[id, default: []]
      if a.count > 1 || b.count > 1 { ambiguous += 1 }
      if a.count == 1 && b.count == 1 { pairs.append((a[0], b[0])) }
      else { unpairedBefore += a.count; unpairedAfter += b.count }
    }
    func counts(_ d: Declaration) -> [String: Int] {
      Dictionary(d.references.map { ($0.expression, 1) }, uniquingKeysWith: +)
    }
    func location(_ d: Declaration, _ key: String) -> ReferenceLocation {
      let sites = d.references.filter { $0.expression == key }.map(\.site)
      return ReferenceLocation(declaration: d.site, count: sites.count,
        sites: Array(sites.prefix(4)), omittedSites: max(0, sites.count - 4))
    }
    func change(_ a: Declaration, _ b: Declaration, _ key: String, increases: Bool) -> ReferenceChange {
      let ac = counts(a), bc = counts(b)
      let added = increases ? bc.keys.sorted().filter { bc[$0]! > ac[$0, default: 0] }.map {
        ReferenceCount(spelling: $0, beforeCount: ac[$0, default: 0], afterCount: bc[$0]!)
      } : []
      return ReferenceChange(before: location(a, key), after: location(b, key),
        increasedReferences: Array(added.prefix(6)), omittedIncreasedReferences: max(0, added.count - 6),
        bodyChanged: a.tokens != b.tokens)
    }
    var reductions: [String: [ReferenceChange]] = [:]
    for (a, b) in pairs where a.tokens != b.tokens {
      let ac = counts(a), bc = counts(b)
      for key in Set(a.references.filter(\.qualified).map(\.expression)).sorted() where ac[key]! > bc[key, default: 0] {
        reductions[key, default: []].append(change(a, b, key, increases: true))
      }
    }
    var contexts: [ReferenceContext] = []
    for key in reductions.keys.sorted() {
      // A retained site must already exist in the corresponding old declaration.
      // Reduced declarations are kept in the reduction side, never called unchanged.
      let retained = pairs.filter { a, b in
        let ac = counts(a)[key, default: 0], bc = counts(b)[key, default: 0]
        return ac > 0 && bc >= ac
      }.map { change($0.0, $0.1, key, increases: false) }
      guard !retained.isEmpty else { continue }
      let reduced = reductions[key]!
      contexts.append(ReferenceContext(spelling: key, reductions: Array(reduced.prefix(8)),
        omittedReductions: max(0, reduced.count - 8), retained: Array(retained.prefix(8)),
        omittedRetained: max(0, retained.count - 8)))
    }
    return ContextReport(scope: "experiment: reduced qualified written references and retention in uniquely paired declarations",
      limitations: [
        "References are written identifier/member chains and calls, not resolved symbols, dependencies or runtime paths. Different receivers and implicit-base members are not unified.",
        "Counts compare uniquely paired file/lexical-owner/signature declarations. Retained means present in both versions, not an unchanged statement or behavior. Newly added, removed, renamed and ambiguous declarations are outside these pairs.",
        "Increased references are context in the same declaration, not inferred replacements. Retention is not a migration defect or a reason to integrate implementations.",
        "Functions and type/file-level identifier property bindings are indexed. Initializers, subscripts, operators, macros, dynamic receiver chains and type references are not fully indexed. Nested declarations have their own scope.",
        "Conditional bodies are read together, not evaluated. External requirements and symbol identity remain unknown. Zero contexts does not establish consistency.",
        "Output limits: 12 references, 8 declarations per side, 4 occurrence sites per declaration, 6 increased references per reduction; omissions are counted.",
      ], beforeFileCount: before.count, afterFileCount: after.count,
      changedDeclarations: pairs.filter { $0.0.tokens != $0.1.tokens }.count,
      contexts: Array(contexts.prefix(12)), omittedContexts: max(0, contexts.count - 12),
      unpairedBefore: unpairedBefore, unpairedAfter: unpairedAfter, ambiguousKeys: ambiguous)
  }

  private static func collect(_ files: [(String, String)]) throws -> [Declaration] {
    var declarations: [Declaration] = []
    for (file, source) in files.sorted(by: { $0.0 < $1.0 }) {
      let tree = Array(source.utf8).withUnsafeBufferPointer { Parser.parse(source: $0, swiftVersion: .v6) }
      guard !tree.hasError else { throw ContextError.malformed(file) }
      let collector = DeclarationCollector(file: file, tree: tree)
      collector.walk(tree)
      declarations += collector.declarations
    }
    return declarations.sorted { order($0.site, $1.site) }
  }
}

private func order(_ lhs: SourceSite, _ rhs: SourceSite) -> Bool {
  (lhs.file, lhs.line, lhs.endLine, lhs.declaration) < (rhs.file, rhs.line, rhs.endLine, rhs.declaration)
}

private func spelling(_ node: some SyntaxProtocol) -> String {
  node.tokens(viewMode: .sourceAccurate).map(\.text).joined(separator: " ")
}

private func selector(_ function: FunctionDeclSyntax) -> String {
  function.name.text + "(" + function.signature.parameterClause.parameters.map { $0.firstName.text + ":" }.joined() + ")"
}

private func signature(_ function: FunctionDeclSyntax) -> String {
  function.name.text + (function.genericParameterClause.map(spelling) ?? "") + "(" + function.signature.parameterClause.parameters.map {
    $0.firstName.text + ":" + spelling($0.modifiers) + spelling($0.type) + ($0.ellipsis == nil ? "" : "...")
  }.joined(separator: ",") + ")" + (function.signature.effectSpecifiers.map(spelling) ?? "")
    + (function.signature.returnClause.map(spelling) ?? "") + (function.genericWhereClause.map(spelling) ?? "")
}

private struct Reference {
  let expression: String
  let qualified: Bool
  let site: SourceSite
}

private struct Declaration {
  let id: String
  let site: SourceSite
  let tokens: String
  let references: [Reference]
}

private final class References: SyntaxVisitor {
  let site: (Syntax) -> SourceSite
  var references: [Reference] = []
  init(site: @escaping (Syntax) -> SourceSite) { self.site = site; super.init(viewMode: .sourceAccurate) }
  override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ node: IfConfigDeclSyntax) -> SyntaxVisitorContinueKind {
    for clause in node.clauses { if let elements = clause.elements { walk(elements) } }
    return .skipChildren
  }
  func chain(_ expression: ExprSyntax) -> String? {
    if let name = expression.as(DeclReferenceExprSyntax.self) { return name.baseName.text + (name.argumentNames.map(spelling) ?? "") }
    if let member = expression.as(MemberAccessExprSyntax.self), let base = member.base,
      let prefix = chain(base) { return prefix + "." + member.declName.baseName.text + (member.declName.argumentNames.map(spelling) ?? "") }
    if let generic = expression.as(GenericSpecializationExprSyntax.self), let base = chain(generic.expression) {
      return base + spelling(generic.genericArgumentClause)
    }
    return nil
  }
  override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
    // The outer expression owns a member chain; don't count each prefix again.
    if let parent = node.parent?.as(MemberAccessExprSyntax.self), parent.base?.id == node.id { return .visitChildren }
    if let parent = node.parent?.as(GenericSpecializationExprSyntax.self), parent.expression.id == node.id { return .visitChildren }
    if let parent = node.parent?.as(FunctionCallExprSyntax.self), parent.calledExpression.id == node.id { return .visitChildren }
    if let expression = chain(ExprSyntax(node)), node.base != nil {
      references.append(Reference(expression: expression, qualified: true, site: site(Syntax(node))))
    }
    return .visitChildren
  }
  override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
    var expression = node.calledExpression
    if let generic = expression.as(GenericSpecializationExprSyntax.self) { expression = generic.expression }
    let name = expression.as(DeclReferenceExprSyntax.self)?.baseName.text
      ?? expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text
    if name != nil {
      var labels = node.arguments.map { ($0.label?.text ?? "_") + ":" }
      if node.trailingClosure != nil { labels.append("_:") }
      labels += node.additionalTrailingClosures.map { $0.label.text + ":" }
      if let base = chain(node.calledExpression) {
        let reference = base + "(" + labels.joined() + ")"
        references.append(Reference(expression: reference, qualified: expression.is(MemberAccessExprSyntax.self), site: site(Syntax(node))))
      }
    }
    return .visitChildren
  }
}

private final class DeclarationCollector: SyntaxVisitor {
  let file: String
  let converter: SourceLocationConverter
  var declarations: [Declaration] = []
  init(file: String, tree: SourceFileSyntax) {
    self.file = file; converter = SourceLocationConverter(fileName: file, tree: tree)
    super.init(viewMode: .sourceAccurate)
  }

  func owner(_ syntax: some SyntaxProtocol, identity: Bool = false) -> String {
    var names: [String] = [], parent = syntax.parent
    while let node = parent {
      if let x = node.as(ClassDeclSyntax.self) { names.append(x.name.text) }
      else if let x = node.as(StructDeclSyntax.self) { names.append(x.name.text) }
      else if let x = node.as(EnumDeclSyntax.self) { names.append(x.name.text) }
      else if let x = node.as(ActorDeclSyntax.self) { names.append(x.name.text) }
      else if let x = node.as(ProtocolDeclSyntax.self) { names.append(x.name.text) }
      else if let x = node.as(ExtensionDeclSyntax.self) { names.append(spelling(x.extendedType)) }
      else if let x = node.as(FunctionDeclSyntax.self) { names.append(identity ? signature(x) : selector(x)) }
      else if let x = node.as(InitializerDeclSyntax.self) {
        names.append(identity ? "init" + spelling(x.signature) : "init")
      }
      else if node.is(DeinitializerDeclSyntax.self) { names.append("deinit") }
      else if let x = node.as(PatternBindingSyntax.self) { names.append(spelling(x.pattern)) }
      else if let x = node.as(AccessorDeclSyntax.self) { names.append(x.accessorSpecifier.text) }
      else if node.is(ClosureExprSyntax.self) { names.append("<closure>") }
      parent = node.parent
    }
    return names.reversed().joined(separator: ".")
  }

  func add(_ syntax: Syntax, name: String, identity: String? = nil, body: Syntax?) {
    let display = [owner(syntax), name].filter { !$0.isEmpty }.joined(separator: ".")
    func site(_ node: Syntax) -> SourceSite {
      SourceSite(file: file, line: converter.location(for: node.positionAfterSkippingLeadingTrivia).line,
        endLine: converter.location(for: node.endPositionBeforeTrailingTrivia).line, declaration: display,
        signature: identity)
    }
    let visitor = References(site: site)
    if let body { visitor.walk(body) }
    declarations.append(Declaration(id: file + ":" + owner(syntax, identity: true) + ":" + (identity ?? name), site: site(syntax),
      tokens: spelling(syntax), references: visitor.references))
  }

  override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
    let key = selector(node)
    add(Syntax(node), name: key, identity: signature(node), body: node.body.map(Syntax.init))
    return .visitChildren
  }

  override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
    var parent = node.parent
    var inPropertyScope = false
    while let ancestor = parent {
      if ancestor.is(MemberBlockSyntax.self) || ancestor.is(SourceFileSyntax.self) {
        inPropertyScope = true; break
      }
      if ancestor.is(CodeBlockSyntax.self) || ancestor.is(AccessorBlockSyntax.self)
        || ancestor.is(ClosureExprSyntax.self) { break }
      parent = ancestor.parent
    }
    guard inPropertyScope else { return .visitChildren }
    for binding in node.bindings {
      guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { continue }
      add(Syntax(binding), name: name,
        body: Syntax(binding))
    }
    return .visitChildren
  }
}
