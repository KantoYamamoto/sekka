import Foundation
import SwiftParser
import SwiftSyntax

// Token normalization ignores formatting/comments, but preserves literal/operator spelling.
func normalized(_ node: some SyntaxProtocol) -> String {
  node.tokens(viewMode: .sourceAccurate).map(\.text).joined(separator: " ")
}

public enum Analyzer {
  public static func analyze(_ files: [(path: String, source: String)]) throws -> Snapshot {
    var result = Snapshot()
    result.files = files.count
    for file in files.sorted(by: { $0.path < $1.path }) {
      let tree = Array(file.source.utf8).withUnsafeBufferPointer {
        Parser.parse(source: $0, swiftVersion: .v6)
      }
      guard !tree.hasError else {
        throw PatchworkError.message(
          "Cannot parse \(file.path). Analysis stopped; no partial clean result was produced.")
      }
      let visitor = DeclarationVisitor(file: file.path, tree: tree)
      visitor.walk(tree)
      result.types += visitor.records
      result.notices += visitor.notices
    }
    result.types.sort { $0.id < $1.id }
    return result
  }
}

private final class DeclarationVisitor: SyntaxVisitor {
  let file: String
  let converter: SourceLocationConverter
  var records: [TypeRecord] = []
  var notices: [Notice] = []
  var stack: [Int] = []
  var occurrences: [String: Int] = [:]

  init(file: String, tree: SourceFileSyntax) {
    self.file = file
    converter = SourceLocationConverter(fileName: file, tree: tree)
    super.init(viewMode: .sourceAccurate)
  }

  func location(_ node: some SyntaxProtocol) -> Location {
    Location(
      file: file, line: converter.location(for: node.positionAfterSkippingLeadingTrivia).line)
  }

  func enter(
    _ node: some DeclGroupSyntax, name: String, kind: String, inheritance: InheritanceClauseSyntax?
  ) {
    let parent = stack.last.map { records[$0].name + "." } ?? ""
    let fullName = parent + name
    let base = "\(file)::\(kind):\(fullName)"
    let ordinal = occurrences[base, default: 0]
    occurrences[base] = ordinal + 1
    let id = base + "#\(ordinal)"
    let header = node.tokens(viewMode: .sourceAccurate).prefix {
      $0.position < node.memberBlock.leftBrace.position
    }.map(\.text).joined(separator: " ")
    records.append(
      TypeRecord(id: id, name: fullName, kind: kind, location: location(node), header: header))
    stack.append(records.count - 1)
    if let inheritance {
      for item in inheritance.inheritedTypes {
        reference(item.type, role: "inheritance-clause", member: fullName)
      }
    }
    if ordinal > 0 {
      notices.append(
        Notice(
          location: location(node),
          message:
            "Repeated declaration identity: \(fullName). Matched by source order; conditional branches are not evaluated."
        ))
    }
  }

  func reference(_ type: TypeSyntax, role: String, member: String) {
    guard let index = stack.last else { return }
    records[index].references.append(
      Reference(spelling: normalized(type), role: role, member: member, line: location(type).line))
  }

  func member(
    _ node: some SyntaxProtocol, key: String, kind: String, signature: String,
    body: BodyMetrics? = nil, forwarding: String? = nil
  ) {
    guard let index = stack.last else { return }
    records[index].members.append(
      Member(
        key: key, kind: kind, signature: signature, location: location(node), body: body,
        forwardingCall: forwarding))
  }

  override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
    enter(node, name: node.name.text, kind: "class", inheritance: node.inheritanceClause)
    return .visitChildren
  }
  override func visitPost(_ node: ClassDeclSyntax) { stack.removeLast() }
  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
    enter(node, name: node.name.text, kind: "struct", inheritance: node.inheritanceClause)
    return .visitChildren
  }
  override func visitPost(_ node: StructDeclSyntax) { stack.removeLast() }
  override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
    enter(node, name: node.name.text, kind: "actor", inheritance: node.inheritanceClause)
    return .visitChildren
  }
  override func visitPost(_ node: ActorDeclSyntax) { stack.removeLast() }
  override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
    enter(node, name: node.name.text, kind: "enum", inheritance: node.inheritanceClause)
    return .visitChildren
  }
  override func visitPost(_ node: EnumDeclSyntax) { stack.removeLast() }
  override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
    enter(node, name: node.name.text, kind: "protocol", inheritance: node.inheritanceClause)
    return .visitChildren
  }
  override func visitPost(_ node: ProtocolDeclSyntax) { stack.removeLast() }
  override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
    let name =
      normalized(node.extendedType) + (node.genericWhereClause.map { " " + normalized($0) } ?? "")
    enter(node, name: name, kind: "extension", inheritance: node.inheritanceClause)
    return .visitChildren
  }
  override func visitPost(_ node: ExtensionDeclSyntax) { stack.removeLast() }

  override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
    guard !stack.isEmpty else { return .skipChildren }
    for binding in node.bindings {
      let name = normalized(binding.pattern)
      let key = "property \(name)"
      var signature =
        normalized(node.attributes) + " " + normalized(node.modifiers) + " "
        + node.bindingSpecifier.text + " " + name
      if let annotation = binding.typeAnnotation {
        signature += " : " + normalized(annotation.type)
        reference(annotation.type, role: "property-type", member: key)
      }
      // Accessor changes matter, while literal initializer values are intentionally not compared.
      if let accessor = binding.accessorBlock {
        switch accessor.accessors {
        case .getter: signature += " { get }"
        case .accessors(let list):
          signature +=
            " { "
            + list.map {
              ($0.modifier.map(normalized) ?? "") + " " + normalized($0.accessorSpecifier)
            }.joined(separator: " ; ") + " }"
        }
      }
      member(
        binding, key: key, kind: "property",
        signature: signature.trimmingCharacters(in: .whitespaces),
        body: binding.accessorBlock.map(metrics))
    }
    return .skipChildren
  }

  override func visit(_ node: EnumCaseDeclSyntax) -> SyntaxVisitorContinueKind {
    for element in node.elements {
      let key = "case \(element.name.text)"
      member(element, key: key, kind: "enum-case", signature: normalized(element))
      if let parameters = element.parameterClause {
        for parameter in parameters.parameters {
          reference(parameter.type, role: "case-payload", member: key)
        }
      }
    }
    return .skipChildren
  }

  override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
    let key = "func \(node.name.text)" + normalized(node.signature.parameterClause)
    var signatureNode = node
    signatureNode.body = nil
    member(
      node, key: key, kind: "function", signature: normalized(signatureNode),
      body: node.body.map(metrics),
      forwarding: forwarding(node.body, parameters: node.signature.parameterClause.parameters))
    parameters(node.signature.parameterClause.parameters, member: key)
    if let output = node.signature.returnClause {
      reference(output.type, role: "return-type", member: key)
    }
    return .skipChildren
  }

  override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
    let key = "init" + normalized(node.signature.parameterClause)
    var signatureNode = node
    signatureNode.body = nil
    member(
      node, key: key, kind: "initializer", signature: normalized(signatureNode),
      body: node.body.map(metrics),
      forwarding: forwarding(node.body, parameters: node.signature.parameterClause.parameters))
    parameters(node.signature.parameterClause.parameters, member: key)
    return .skipChildren
  }

  func parameters(_ parameters: FunctionParameterListSyntax, member: String) {
    for parameter in parameters {
      reference(parameter.type, role: "parameter-type", member: member)
    }
  }

  override func visit(_ node: IfConfigDeclSyntax) -> SyntaxVisitorContinueKind {
    notices.append(
      Notice(
        location: location(node),
        message: "All #if branches are included, regardless of build configuration."))
    return .visitChildren
  }

  override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
    member(node, key: "typealias \(node.name.text)", kind: "typealias", signature: normalized(node))
    reference(
      node.initializer.value, role: "typealias-value", member: "typealias \(node.name.text)")
    return .skipChildren
  }
}

private func metrics(_ node: some SyntaxProtocol) -> BodyMetrics {
  let visitor = MetricsVisitor(viewMode: .sourceAccurate)
  visitor.walk(node)
  visitor.value.tokens = Array(node.tokens(viewMode: .sourceAccurate)).count
  return visitor.value
}

private final class MetricsVisitor: SyntaxVisitor {
  var value = BodyMetrics()
  override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind {
    value.controlFlowSites += 1
    return .visitChildren
  }
  override func visit(_ node: GuardStmtSyntax) -> SyntaxVisitorContinueKind {
    value.controlFlowSites += 1
    return .visitChildren
  }
  override func visit(_ node: SwitchExprSyntax) -> SyntaxVisitorContinueKind {
    value.controlFlowSites += 1
    return .visitChildren
  }
  override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
    value.controlFlowSites += 1
    return .visitChildren
  }
  override func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind {
    value.controlFlowSites += 1
    return .visitChildren
  }
  override func visit(_ node: RepeatStmtSyntax) -> SyntaxVisitorContinueKind {
    value.controlFlowSites += 1
    return .visitChildren
  }
  override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind {
    value.controlFlowSites += 1
    return .visitChildren
  }
  override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
    value.closures += 1
    return .visitChildren
  }
  override func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
    let elements = Array(node.elements)
    if elements.count >= 3, elements[1].is(AssignmentExprSyntax.self),
      let lhs = elements[0].as(MemberAccessExprSyntax.self),
      let base = lhs.base?.as(DeclReferenceExprSyntax.self), base.baseName.text == "self"
    {
      value.explicitSelfAssignments += 1
    }
    return .visitChildren
  }
}

private func forwarding(_ body: CodeBlockSyntax?, parameters: FunctionParameterListSyntax)
  -> String?
{
  guard let body, body.statements.count == 1, let statement = body.statements.first,
    !parameters.isEmpty
  else { return nil }
  var expression: ExprSyntax?
  if let returned = statement.item.as(ReturnStmtSyntax.self) {
    expression = returned.expression
  } else {
    expression = statement.item.as(ExprSyntax.self)
  }
  while let current = expression {
    if let attempt = current.as(TryExprSyntax.self) {
      expression = attempt.expression
    } else if let awaited = current.as(AwaitExprSyntax.self) {
      expression = awaited.expression
    } else {
      break
    }
  }
  guard let call = expression?.as(FunctionCallExprSyntax.self), call.trailingClosure == nil,
    call.additionalTrailingClosures.isEmpty, call.arguments.count == parameters.count,
    isSimpleCallee(call.calledExpression)
  else { return nil }
  let names = parameters.map { ($0.secondName ?? $0.firstName).text }.sorted()
  let passed = call.arguments.compactMap {
    $0.expression.as(DeclReferenceExprSyntax.self)?.baseName.text
  }.sorted()
  guard names == passed, !names.contains("_") else { return nil }
  return normalized(call)
}

private func isSimpleCallee(_ expression: ExprSyntax) -> Bool {
  if expression.is(DeclReferenceExprSyntax.self) { return true }
  if let member = expression.as(MemberAccessExprSyntax.self), let base = member.base {
    return isSimpleCallee(base)
  }
  return false
}
