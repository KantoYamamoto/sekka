import SwiftSyntax

public enum WrittenCallForm: String, Codable, Sendable { case member, unqualified }

public struct InventoryWrittenCall: Codable, Sendable {
  public let site: SourceSite
  public let selector: String
  public let form: WrittenCallForm
  public let receiverSpelling: String?
  public let tokens: String
  public let writtenConditions: [WrittenConditionalBranch]
}

/// Expressions written inside a body, including closures; these are not resolved calls.
final class WrittenCalls: SyntaxVisitor {
  let site: (FunctionCallExprSyntax) -> SourceSite
  let conditions: (FunctionCallExprSyntax) -> [WrittenConditionalBranch]
  var calls: [InventoryWrittenCall] = []
  init(site: @escaping (FunctionCallExprSyntax) -> SourceSite, conditions: @escaping (FunctionCallExprSyntax) -> [WrittenConditionalBranch]) {
    self.site = site; self.conditions = conditions; super.init(viewMode: .sourceAccurate)
  }
  override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
    guard node.trailingClosure == nil, node.additionalTrailingClosures.isEmpty else { return .visitChildren }
    let name: String, form: WrittenCallForm, receiver: String?
    if let member = node.calledExpression.as(MemberAccessExprSyntax.self), let base = member.base,
      member.declName.argumentNames == nil {
      name = member.declName.baseName.text; form = .member; receiver = inventoryTokens(base)
    } else if let reference = node.calledExpression.as(DeclReferenceExprSyntax.self), reference.argumentNames == nil {
      name = reference.baseName.text; form = .unqualified; receiver = nil
    } else { return .visitChildren }
    calls.append(InventoryWrittenCall(site: site(node),
      selector: name + "(" + node.arguments.map { ($0.label?.text ?? "_") + ":" }.joined() + ")",
      form: form, receiverSpelling: receiver, tokens: inventoryTokens(node), writtenConditions: conditions(node)))
    return .visitChildren
  }
  override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
}
