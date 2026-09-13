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

public struct CallOverlap: Codable, Sendable {
  public let site: SourceSite
  public let spellings: [String]
}

public struct SharedCalls: Codable, Sendable {
  public let before: CallOverlap
  public let after: [CallOverlap]
}

public struct CallUse: Codable, Sendable {
  public let site: SourceSite
  public let expression: String
}

public struct SameSelectorCalls: Codable, Sendable {
  public let selector: String
  public let declarationCandidates: [SourceSite]
  public let omittedDeclarationCandidates: Int
  public let before: [CallUse]
  public let after: [CallUse]
  public let omittedBefore: Int
  public let omittedAfter: Int
}

public struct ChangeContext: Codable, Sendable {
  public let before: [SourceSite]
  public let after: SourceSite
  public let sharedCalls: [SharedCalls]
  public let omittedNeighbors: Int
  public let sameSelector: String?
}

public struct ContextReport: Codable, Sendable {
  public let scope: String
  public let limitations: [String]
  public let beforeFileCount: Int
  public let afterFileCount: Int
  public let changedDeclarations: Int
  public let contexts: [ChangeContext]
  public let selectorGroups: [SameSelectorCalls]
  public let withoutContext: [SourceSite]
  public let omittedWithoutContext: Int
  public let ambiguous: [SourceSite]
}

public enum ContextError: Error { case malformed(String) }

public enum DeclarationContext {
  public static func compare(before: [(String, String)], after: [(String, String)]) throws -> ContextReport {
    let old = try collect(before), new = try collect(after)
    let oldIDs = Dictionary(grouping: old, by: \.id), newIDs = Dictionary(grouping: new, by: \.id)
    var contexts: [ChangeContext] = [], without: [SourceSite] = [], ambiguous: [SourceSite] = []
    var groups: [String: SameSelectorCalls] = [:]
    var changed = 0
    for anchor in new {
      let previous = oldIDs[anchor.id, default: []]
      if previous.map(\.tokens).sorted() == newIDs[anchor.id]!.map(\.tokens).sorted() { continue }
      guard newIDs[anchor.id]!.count == 1, previous.count <= 1 else {
        ambiguous.append(anchor.site); continue
      }
      guard previous.first?.tokens != anchor.tokens else { continue }
      changed += 1
      let keys = Set(anchor.calls.compactMap(\.spelling))
      let neighbors = old.filter { candidate in
        guard candidate.id != anchor.id else { return false }
        return !previous.contains { $0.site.file == candidate.site.file && $0.range.lowerBound <= candidate.range.lowerBound && $0.range.upperBound >= candidate.range.upperBound }
      }.compactMap { candidate -> SharedCalls? in
        let shared = keys.intersection(candidate.calls.compactMap(\.spelling)).sorted()
        guard shared.count >= 2 else { return nil }
        return SharedCalls(before: CallOverlap(site: candidate.site, spellings: shared),
          after: newIDs[candidate.id, default: []].map {
            CallOverlap(site: $0.site, spellings: keys.intersection($0.calls.compactMap(\.spelling)).sorted())
          })
      }.sorted {
        if $0.before.spellings.count != $1.before.spellings.count { return $0.before.spellings.count > $1.before.spellings.count }
        return order($0.before.site, $1.before.site)
      }
      var incoming: SameSelectorCalls?
      if let selector = anchor.selector {
        func uses(_ declarations: [Declaration]) -> [CallUse] {
          declarations.flatMap { declaration in
            declaration.calls.filter { $0.selector == selector }.map {
              CallUse(site: $0.site, expression: $0.expression)
            }
          }.sorted { order($0.site, $1.site) }
        }
        let beforeUses = uses(old), afterUses = uses(new)
        if !beforeUses.isEmpty || !afterUses.isEmpty {
          incoming = SameSelectorCalls(selector: selector,
            declarationCandidates: Array(new.filter { $0.selector == selector }.prefix(3)).map(\.site),
            omittedDeclarationCandidates: max(0, new.filter { $0.selector == selector }.count - 3),
            before: Array(beforeUses.prefix(8)), after: Array(afterUses.prefix(8)),
            omittedBefore: max(0, beforeUses.count - 8), omittedAfter: max(0, afterUses.count - 8))
        }
      }
      if let incoming { groups[incoming.selector] = incoming }
      if neighbors.isEmpty && incoming == nil { without.append(anchor.site); continue }
      contexts.append(ChangeContext(before: previous.map(\.site), after: anchor.site,
        sharedCalls: Array(neighbors.prefix(3)), omittedNeighbors: max(0, neighbors.count - 3), sameSelector: incoming?.selector))
    }
    return ContextReport(scope: "experiment: changed declarations and written call selectors in supplied Swift files",
      limitations: [
        "Call selectors are written names and argument labels, not resolved callees, types or runtime paths.",
        "Receivers, overloads, local shadowing, default arguments and trailing closure labels can change meaning or prevent matches.",
        "Each overlap compares the anchor AFTER with the neighbor on the stated side. Shared written call expressions/labels do not establish duplicated behavior or a reason to merge implementations. Common APIs may produce noise. Implicit-base member calls are excluded from shared-spelling retrieval.",
        "Only functions and type/file-level property bindings are indexed; variable modifiers and containing-type changes are not comparison anchors. Nested function bodies are indexed separately; macros and other declarations are not call sites.",
        "Conditional branches are read together, not evaluated. External declarations and inferred relationships are unknown.",
        "Before/after correspondence is unique file, lexical owner and signature spelling, not semantic identity. Ambiguous declarations are listed separately.",
        "At most 3 neighbors, 3 same-selector declarations, 8 uses per side and 8 context-free declarations are shown; omitted counts are explicit. No context is not a structural verdict.",
      ], beforeFileCount: before.count, afterFileCount: after.count, changedDeclarations: changed,
      contexts: contexts, selectorGroups: groups.keys.sorted().map { groups[$0]! }, withoutContext: Array(without.prefix(8)), omittedWithoutContext: max(0, without.count - 8), ambiguous: ambiguous)
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

private struct Call {
  let selector: String
  let expression: String
  let spelling: String?
  let site: SourceSite
}

private struct Declaration {
  let id: String
  let selector: String?
  let site: SourceSite
  let tokens: String
  let range: Range<Int>
  let calls: [Call]
}

private final class Calls: SyntaxVisitor {
  let site: (Syntax) -> SourceSite
  var calls: [Call] = []
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
  override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
    var expression = node.calledExpression
    if let generic = expression.as(GenericSpecializationExprSyntax.self) { expression = generic.expression }
    let name = expression.as(DeclReferenceExprSyntax.self)?.baseName.text
      ?? expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text
    if let name {
      var labels = node.arguments.map { ($0.label?.text ?? "_") + ":" }
      if node.trailingClosure != nil { labels.append("_:") }
      labels += node.additionalTrailingClosures.map { $0.label.text + ":" }
      calls.append(Call(selector: name + "(" + labels.joined() + ")",
        expression: spelling(node.calledExpression),
        spelling: expression.as(MemberAccessExprSyntax.self).map { $0.base == nil } == true ? nil
          : spelling(node.calledExpression) + "(" + labels.joined() + ")", site: site(Syntax(node))))
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

  func add(_ syntax: Syntax, name: String, identity: String? = nil, key: String?, body: Syntax?) {
    let display = [owner(syntax), name].filter { !$0.isEmpty }.joined(separator: ".")
    func site(_ node: Syntax) -> SourceSite {
      SourceSite(file: file, line: converter.location(for: node.positionAfterSkippingLeadingTrivia).line,
        endLine: converter.location(for: node.endPositionBeforeTrailingTrivia).line, declaration: display,
        signature: key == nil ? nil : identity)
    }
    let visitor = Calls(site: site)
    if let body { visitor.walk(body) }
    declarations.append(Declaration(id: file + ":" + owner(syntax, identity: true) + ":" + (identity ?? name), selector: key, site: site(syntax),
      tokens: spelling(syntax), range: syntax.positionAfterSkippingLeadingTrivia.utf8Offset..<syntax.endPositionBeforeTrailingTrivia.utf8Offset, calls: visitor.calls))
  }

  override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
    let key = selector(node)
    add(Syntax(node), name: key, identity: signature(node), key: key, body: node.body.map(Syntax.init))
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
      add(Syntax(binding), name: name, key: nil,
        body: Syntax(binding))
    }
    return .visitChildren
  }
}
