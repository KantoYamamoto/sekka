import SwiftSyntax

public struct WrittenConditionClause: Codable, Equatable, Sendable {
  public let keyword: String
  public let condition: String?
  public let site: SourceSite
}

public struct WrittenConditionalBranch: Codable, Equatable, Sendable {
  public let selected: WrittenConditionClause
  public let preceding: [WrittenConditionClause]
  // Source positions locate evidence, but do not define a written condition pattern.
  var groupingKey: String {
    inventoryKey((preceding + [selected]).map { WrittenConditionalContext.key(keyword: $0.keyword, condition: $0.condition) })
  }
}

/// Written lexical branches, never a compiler-configuration evaluation.
enum WrittenConditionalContext {
  static func clauses(_ syntax: some SyntaxProtocol) -> [IfConfigClauseSyntax] {
    var result: [IfConfigClauseSyntax] = [], parent = syntax.parent
    while let node = parent {
      if let clause = node.as(IfConfigClauseSyntax.self) { result.append(clause) }
      parent = node.parent
    }
    return result.reversed()
  }
  static func prefix(_ clause: IfConfigClauseSyntax) -> [IfConfigClauseSyntax] {
    guard let list = clause.parent?.as(IfConfigClauseListSyntax.self) else { return [] }
    var result: [IfConfigClauseSyntax] = []
    for item in list {
      result.append(item)
      if item.id == clause.id { break }
    }
    return result
  }
  static func key(keyword: String, condition: String?) -> String { inventoryKey([keyword, condition ?? ""]) }
  static func conditionPrefix(_ clause: IfConfigClauseSyntax) -> [String] {
    prefix(clause).map { key(keyword: $0.poundKeyword.text, condition: $0.condition.map(inventoryTokens)) }
  }
  static func path(_ syntax: some SyntaxProtocol, file: String, converter: SourceLocationConverter) -> [WrittenConditionalBranch] {
    func written(_ clause: IfConfigClauseSyntax) -> WrittenConditionClause {
      let condition = clause.condition.map(inventoryTokens)
      let label = clause.poundKeyword.text + (condition.map { " " + $0 } ?? "")
      return WrittenConditionClause(keyword: clause.poundKeyword.text, condition: condition,
        site: SourceSite(file: file, line: converter.location(for: clause.poundKeyword.positionAfterSkippingLeadingTrivia).line,
          endLine: converter.location(for: clause.condition?.endPositionBeforeTrailingTrivia ?? clause.poundKeyword.endPositionBeforeTrailingTrivia).line,
          declaration: label, signature: nil))
    }
    return clauses(syntax).map { clause in
      WrittenConditionalBranch(selected: written(clause), preceding: prefix(clause).dropLast().map(written))
    }
  }
}
