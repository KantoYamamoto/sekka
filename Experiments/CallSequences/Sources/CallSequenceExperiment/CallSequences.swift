import Foundation
import SwiftParser
import SwiftSyntax

public struct CallPair: Codable, Hashable, Sendable {
  public let first: String
  public let second: String
}

public struct Site: Codable, Equatable, Sendable {
  public let file: String
  public let function: String
  public let declarationLine: Int
  public let declarationColumn: Int
  public let line: Int
  public let endLine: Int
}

public struct Expansion: Codable, Sendable {
  public let spelling: CallPair
  public let before: [Site]
  public let after: [Site]
}

public struct Report: Encodable, Sendable {
  public let scope = "experiment: exact adjacent call spelling in named functions"
  public let limitations = [
    "Sites are lexical function declarations, not runtime executions or resolved dependencies.",
    "Equal spellings may refer to different objects, overloads, argument values or responsibilities.",
    "Only direct adjacent call statements with simple callees are included. Returns, assignments, try/await wrappers and trailing closures are excluded.",
    "Closures, local functions and conditional-compilation contents are excluded. Ordinary branch bodies are included without evaluating their conditions.",
    "Each pair counts once per function, using its first source location. Only growth to at least two functions is reported.",
    "No report does not mean no duplication or no structural concern. Existing facade selection is not implemented.",
  ]
  public let beforeFileCount: Int
  public let afterFileCount: Int
  public let expansions: [Expansion]
}

public enum ExperimentError: Error, CustomStringConvertible {
  case parse(String)
  public var description: String {
    switch self {
    case .parse(let file): "Cannot parse \(file); no partial report produced."
    }
  }
}

public enum CallSequences {
  public static func compare(before: [(String, String)], after: [(String, String)]) throws -> Report {
    let old = try collect(before)
    let new = try collect(after)
    let expansions = new.keys.sorted {
      ($0.first, $0.second) < ($1.first, $1.second)
    }.compactMap { pair -> Expansion? in
      let previous = old[pair, default: []]
      let current = new[pair, default: []]
      guard current.count >= 2, current.count > previous.count else { return nil }
      return Expansion(spelling: pair, before: previous, after: current)
    }
    return Report(beforeFileCount: before.count, afterFileCount: after.count, expansions: expansions)
  }

  private static func collect(_ files: [(String, String)]) throws -> [CallPair: [Site]] {
    var result: [CallPair: [Site]] = [:]
    for (file, source) in files.sorted(by: { $0.0 < $1.0 }) {
      let tree = Array(source.utf8).withUnsafeBufferPointer { Parser.parse(source: $0, swiftVersion: .v6) }
      guard !tree.hasError else { throw ExperimentError.parse(file) }
      let visitor = PairVisitor(file: file, tree: tree)
      visitor.walk(tree)
      for (pair, sites) in visitor.sites {
        result[pair, default: []] += sites
      }
    }
    for key in result.keys {
      result[key]?.sort { ($0.file, $0.line, $0.declarationColumn) < ($1.file, $1.line, $1.declarationColumn) }
    }
    return result
  }
}

private func spelling(_ node: some SyntaxProtocol) -> String {
  node.tokens(viewMode: .sourceAccurate).map(\.text).joined(separator: " ")
}

private final class PairVisitor: SyntaxVisitor {
  let file: String
  let converter: SourceLocationConverter
  // Keep the earliest source occurrence, independent of visitor nesting order.
  var placements: [CallPair: [Int: (offset: Int, site: Site)]] = [:]
  var sites: [CallPair: [Site]] {
    placements.mapValues { $0.values.map(\.site) }
  }

  init(file: String, tree: SourceFileSyntax) {
    self.file = file
    converter = SourceLocationConverter(fileName: file, tree: tree)
    super.init(viewMode: .sourceAccurate)
  }

  override func visit(_ node: CodeBlockItemListSyntax) -> SyntaxVisitorContinueKind {
    var functions: [FunctionDeclSyntax] = []
    var ancestor = node.parent
    while let current = ancestor {
      if current.is(ClosureExprSyntax.self) || current.is(IfConfigDeclSyntax.self)
        || current.is(InitializerDeclSyntax.self) || current.is(DeinitializerDeclSyntax.self)
        || current.is(AccessorDeclSyntax.self) || current.is(VariableDeclSyntax.self)
        || current.is(SubscriptDeclSyntax.self) {
        return .visitChildren
      }
      if let function = current.as(FunctionDeclSyntax.self) { functions.append(function) }
      ancestor = current.parent
    }
    guard functions.count == 1, let function = functions.first else { return .visitChildren }
    let statements = Array(node)
    guard statements.count >= 2 else { return .visitChildren }
    for index in 0..<(statements.count - 1) {
      guard let first = directCall(statements[index]),
        let second = directCall(statements[index + 1]) else { continue }
      let pair = CallPair(first: spelling(first), second: spelling(second))
      let offset = function.positionAfterSkippingLeadingTrivia.utf8Offset
      let callOffset = first.positionAfterSkippingLeadingTrivia.utf8Offset
      if let existing = placements[pair]?[offset], existing.offset <= callOffset { continue }
      let declaration = converter.location(for: function.positionAfterSkippingLeadingTrivia)
      placements[pair, default: [:]][offset] = (callOffset, Site(
        file: file, function: function.name.text,
        declarationLine: declaration.line, declarationColumn: declaration.column,
        line: converter.location(for: first.positionAfterSkippingLeadingTrivia).line,
        endLine: converter.location(for: second.endPositionBeforeTrailingTrivia).line))
    }
    return .visitChildren
  }

  private func directCall(_ statement: CodeBlockItemSyntax) -> FunctionCallExprSyntax? {
    guard let expression = statement.item.as(ExprSyntax.self),
      let call = expression.as(FunctionCallExprSyntax.self),
      call.trailingClosure == nil, call.additionalTrailingClosures.isEmpty,
      simple(call.calledExpression) else { return nil }
    return call
  }

  private func simple(_ expression: ExprSyntax) -> Bool {
    if expression.is(DeclReferenceExprSyntax.self) { return true }
    if let member = expression.as(MemberAccessExprSyntax.self), let base = member.base {
      return simple(base)
    }
    return false
  }
}
