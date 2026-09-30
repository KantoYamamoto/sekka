import SwiftSyntax

public struct InventoryWrittenMemberCall: Codable, Sendable {
  public let site: SourceSite
  public let selector: String
  public let receiverSpelling: String
  public let tokens: String
}

/// Expressions written inside a body, including closures; these are not resolved calls.
final class WrittenMemberCalls: SyntaxVisitor {
  let site: (FunctionCallExprSyntax) -> SourceSite
  var calls: [InventoryWrittenMemberCall] = []
  init(site: @escaping (FunctionCallExprSyntax) -> SourceSite) { self.site = site; super.init(viewMode: .sourceAccurate) }
  override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
    if let member = node.calledExpression.as(MemberAccessExprSyntax.self), let base = member.base,
      member.declName.argumentNames == nil, node.trailingClosure == nil, node.additionalTrailingClosures.isEmpty {
      calls.append(InventoryWrittenMemberCall(site: site(node),
        selector: member.declName.baseName.text + "(" + node.arguments.map { ($0.label?.text ?? "_") + ":" }.joined() + ")",
        receiverSpelling: base.tokens(viewMode: .sourceAccurate).map(\.text).joined(separator: " "),
        tokens: node.tokens(viewMode: .sourceAccurate).map(\.text).joined(separator: " ")))
    }
    return .visitChildren
  }
  override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
}
