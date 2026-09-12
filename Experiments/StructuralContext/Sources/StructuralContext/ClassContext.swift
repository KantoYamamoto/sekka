import Foundation
import SwiftParser
import SwiftSyntax

public struct Location: Codable, Equatable, Sendable {
  public let file: String
  public let line: Int
  public let endLine: Int
}

public enum BodyState: String, Codable, Sendable {
  case empty, statements, unavailable
}

public struct Method: Codable, Sendable {
  public let selector: String
  public let spelling: String
  public let location: Location
  public let body: BodyState
  public let overrideWritten: Bool
}

public struct TypeSite: Codable, Sendable {
  public let name: String
  public let location: Location
}

public struct MethodSet: Codable, Sendable {
  public let exactSpelling: [Method]
  public let otherSpellings: [Method]
}

public struct MemberHistory: Codable, Sendable {
  public let typeName: String
  public let before: MethodSet
  public let after: MethodSet
}

public struct Slot: Codable, Sendable {
  public let spelling: String
  public let parent: MemberHistory
  public let peers: [MemberHistory]
  public let added: MemberHistory
}

public struct Family: Codable, Sendable {
  public let addedType: TypeSite
  public let parentCandidate: TypeSite
  public let slots: [Slot]
}

public struct ContextReport: Codable, Sendable {
  public let scope: String
  public let limitations: [String]
  public let beforeFileCount: Int
  public let afterFileCount: Int
  public let families: [Family]
  public let skipped: [String]
}

public enum ContextError: Error {
  case malformed(String)
}

public enum ClassContext {
  public static func compare(before: [(String, String)], after: [(String, String)]) throws -> ContextReport {
    let old = try collect(before), new = try collect(after)
    let usable = new.classes.filter { name, declarations in
      declarations.count == 1 && !new.blocked.contains(name)
    }.mapValues { $0[0] }
    var families: [Family] = []
    for name in usable.keys.sorted() where !old.names.contains(name) {
      let added = usable[name]!
      for parentName in added.parents.sorted() {
        guard let parent = usable[parentName], old.classes[parentName]?.count == 1,
          !old.blocked.contains(parentName) else { continue }
        let peers = usable.values.filter {
          $0.site.name != name && old.classes[$0.site.name]?.count == 1
            && !old.blocked.contains($0.site.name) && $0.parents.contains(parentName)
        }.sorted { $0.site.name < $1.site.name }
        var slots: [Slot] = []
        for key in parent.methods.keys.sorted() {
          guard let methods = parent.methods[key], methods.count == 1, methods[0].body == .empty else { continue }
          let implementations = peers.compactMap { peer -> MemberHistory? in
            guard let matches = peer.methods[key], matches.count == 1,
              matches[0].overrideWritten, matches[0].body == .statements else { return nil }
            return history(peer, before: old.classes[peer.site.name]?.first, anchor: methods[0])
          }
          guard !implementations.isEmpty else { continue }
          slots.append(Slot(spelling: key,
            parent: history(parent, before: old.classes[parentName]?.first, anchor: methods[0]),
            peers: implementations, added: history(added, before: nil, anchor: methods[0])))
        }
        if !slots.isEmpty {
          families.append(Family(addedType: added.site, parentCandidate: parent.site, slots: slots))
        }
      }
    }
    let relevantNames = new.classNames.union(new.classes.values.flatMap { $0.flatMap(\.parents) })
    return ContextReport(
      scope: "experiment: new class names and existing declaration spellings in supplied files",
      limitations: [
        "Candidates share written inheritance names; these are not resolved types or runtime dispatch paths.",
        "Empty body means no statements. An intentional hook is not a defect; no placement is recommended.",
        "Empty exactSpelling means no matching declaration in that side's supplied input, not missing behavior.",
        "otherSpellings shares the name and argument labels but not the complete signature spelling; equivalence is unknown.",
        "Only unambiguous top-level nongeneric classes and simple extensions are joined. Conditional or constrained declarations are skipped.",
        "External code, macros, aliases and inferred types are not resolved. Exact type spellings may miss equivalent signatures.",
        "Before and after are declaration sets for the same written class name and selector, not paired methods or proof of a code move.",
        "No family does not establish that the change fits the existing structure.",
      ], beforeFileCount: before.count, afterFileCount: after.count,
      families: families, skipped: [("before", old.reasons), ("after", new.reasons)].flatMap { side, reasons in
        reasons.filter { reason in relevantNames.contains { reason.hasPrefix($0 + ":") } }
          .map { "\(side): \($0)" }
      }.sorted())
  }

  private static func history(_ after: ClassInfo, before: ClassInfo?, anchor: Method) -> MemberHistory {
    func matching(_ info: ClassInfo?) -> MethodSet {
      let methods = info?.methods.values.flatMap { $0 } ?? []
      let candidates = methods.filter { $0.selector == anchor.selector }.sorted {
        ($0.spelling, $0.location.file, $0.location.line) < ($1.spelling, $1.location.file, $1.location.line)
      }
      return MethodSet(exactSpelling: candidates.filter { $0.spelling == anchor.spelling },
        otherSpellings: candidates.filter { $0.spelling != anchor.spelling })
    }
    return MemberHistory(typeName: after.site.name, before: matching(before), after: matching(after))
  }

  private static func collect(_ files: [(String, String)]) throws -> Index {
    var index = Index()
    for (file, source) in files.sorted(by: { $0.0 < $1.0 }) {
      let tree = Array(source.utf8).withUnsafeBufferPointer { Parser.parse(source: $0, swiftVersion: .v6) }
      guard !tree.hasError else { throw ContextError.malformed(file) }
      let visitor = Collector(file: file, tree: tree)
      visitor.walk(tree)
      index.names.formUnion(visitor.index.names)
      index.classNames.formUnion(visitor.index.classNames)
      index.blocked.formUnion(visitor.index.blocked)
      index.reasons.formUnion(visitor.index.reasons)
      for (name, items) in visitor.index.classes { index.classes[name, default: []] += items }
      for (name, items) in visitor.index.extensions { index.extensions[name, default: []] += items }
    }
    for name in index.classes.keys.sorted() {
      if index.classes[name]!.count != 1 {
        index.blocked.insert(name); index.reasons.insert("\(name): multiple class declarations")
      }
      guard index.classes[name]!.count == 1 else { continue }
      for method in index.extensions[name, default: []] {
        index.classes[name]![0].methods[method.spelling, default: []].append(method)
      }
    }
    return index
  }
}

private struct ClassInfo {
  let site: TypeSite
  let parents: Set<String>
  var methods: [String: [Method]]
}

private struct Index {
  var names: Set<String> = []
  var classNames: Set<String> = []
  var blocked: Set<String> = []
  var reasons: Set<String> = []
  var classes: [String: [ClassInfo]] = [:]
  var extensions: [String: [Method]] = [:]
}

private func spelling(_ syntax: some SyntaxProtocol) -> String {
  syntax.tokens(viewMode: .sourceAccurate).map(\.text).joined(separator: " ")
}

private final class Collector: SyntaxVisitor {
  let file: String
  let converter: SourceLocationConverter
  var index = Index()

  init(file: String, tree: SourceFileSyntax) {
    self.file = file
    converter = SourceLocationConverter(fileName: file, tree: tree)
    super.init(viewMode: .sourceAccurate)
  }

  func location(_ node: some SyntaxProtocol) -> Location {
    Location(file: file, line: converter.location(for: node.positionAfterSkippingLeadingTrivia).line,
      endLine: converter.location(for: node.endPositionBeforeTrailingTrivia).line)
  }

  func supported(_ node: some SyntaxProtocol) -> Bool {
    node.parent?.parent?.parent?.is(SourceFileSyntax.self) == true
  }

  func block(_ name: String, _ reason: String) {
    index.names.insert(name); index.blocked.insert(name)
    index.reasons.insert("\(name): \(reason) (\(file))")
  }

  func methods(_ block: MemberBlockSyntax) -> [Method] {
    block.members.compactMap { member in
      guard let method = member.decl.as(FunctionDeclSyntax.self),
        !method.modifiers.contains(where: { ["static", "class"].contains($0.name.text) }) else { return nil }
      let parameters = method.signature.parameterClause.parameters.map {
        spelling($0.modifiers) + $0.firstName.text + ": " + spelling($0.type)
          + ($0.ellipsis == nil ? "" : " ...")
      }.joined(separator: ", ")
      let key = method.name.text + (method.genericParameterClause.map(spelling) ?? "")
        + "(" + parameters + ")"
        + (method.signature.effectSpecifiers.map(spelling) ?? "")
        + (method.signature.returnClause.map(spelling) ?? "")
        + (method.genericWhereClause.map(spelling) ?? "")
      let selector = method.name.text + "(" + method.signature.parameterClause.parameters.map {
        $0.firstName.text + ":"
      }.joined() + ")"
      return Method(selector: selector, spelling: key, location: location(method),
        body: method.body.map { $0.statements.isEmpty ? .empty : .statements } ?? .unavailable,
        overrideWritten: method.modifiers.contains { $0.name.text == "override" })
    }
  }

  override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
    let name = node.name.text
    index.names.insert(name)
    index.classNames.insert(name)
    guard supported(node), node.genericParameterClause == nil,
      !node.memberBlock.members.contains(where: { $0.decl.is(IfConfigDeclSyntax.self) }) else {
      block(name, "nested, conditional or generic class"); return .visitChildren
    }
    let parents = Set((node.inheritanceClause?.inheritedTypes ?? []).compactMap {
      $0.type.as(IdentifierTypeSyntax.self).flatMap { $0.genericArgumentClause == nil ? $0.name.text : nil }
    })
    index.classes[name, default: []].append(ClassInfo(site: TypeSite(name: name, location: location(node)),
      parents: parents, methods: Dictionary(grouping: methods(node.memberBlock), by: \.spelling)))
    return .visitChildren
  }

  override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
    let name = node.extendedType.as(IdentifierTypeSyntax.self)?.name.text
      ?? Array(node.extendedType.tokens(viewMode: .sourceAccurate)).last?.text ?? "<unknown>"
    guard let identifier = node.extendedType.as(IdentifierTypeSyntax.self),
      identifier.genericArgumentClause == nil, supported(node), node.genericWhereClause == nil,
      !node.memberBlock.members.contains(where: { $0.decl.is(IfConfigDeclSyntax.self) }) else {
      block(name, "unsupported extension"); return .visitChildren
    }
    index.extensions[name, default: []] += methods(node.memberBlock)
    return .visitChildren
  }

  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
    block(node.name.text, "non-class declaration"); return .visitChildren
  }
  override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
    block(node.name.text, "non-class declaration"); return .visitChildren
  }
  override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
    block(node.name.text, "non-class declaration"); return .visitChildren
  }
  override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
    block(node.name.text, "non-class declaration"); return .visitChildren
  }
  override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
    block(node.name.text, "typealias"); return .visitChildren
  }
}
