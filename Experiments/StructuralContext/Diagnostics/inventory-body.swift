// Append to the existing context-probe source reader in an ignored package copy.
// Diagnostics only: includes source-derived tokens. Keep output outside public Git.
import SwiftParser
import SwiftSyntax

struct DiagnosticPosition: Encodable {
  let file: String
  let line: Int
  let endLine: Int
}
final class ReturnNameReader: SyntaxVisitor {
  var names: Set<String> = []
  init() { super.init(viewMode: .sourceAccurate) }
  override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
    names.insert(node.name.text); return .visitChildren
  }
}
struct DiagnosticCall: Encodable {
  let site: DiagnosticPosition
  let caller: DiagnosticPosition?
  let form: String
  let callerReturnNames: [String]
  let callerBodyOwned: Bool
  let selector: String?
  let trailingClosure: Bool
  let tokens: String
}
final class CallDiagnosticReader: SyntaxVisitor {
  let file: String
  let converter: SourceLocationConverter
  var calls: [DiagnosticCall] = []
  init(file: String, tree: SourceFileSyntax) {
    self.file = file; converter = SourceLocationConverter(fileName: file, tree: tree)
    super.init(viewMode: .sourceAccurate)
  }
  func position(_ node: some SyntaxProtocol) -> DiagnosticPosition {
    DiagnosticPosition(file: file, line: converter.location(for: node.positionAfterSkippingLeadingTrivia).line,
      endLine: converter.location(for: node.endPositionBeforeTrailingTrivia).line)
  }
  override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
    var parent = node.parent, caller: DiagnosticPosition?
    var returnNames: [String] = []
    var ancestors: [Syntax] = [], crossesLocalType = false, bodyOwned = false
    while let next = parent {
      if let function = next.as(FunctionDeclSyntax.self) {
        caller = position(function)
        bodyOwned = !crossesLocalType && function.body.map { body in ancestors.contains { $0.id == body.id } } == true
        if let type = function.signature.returnClause?.type {
          let reader = ReturnNameReader(); reader.walk(type); returnNames = reader.names.sorted()
        }
        break
      }
      if next.is(StructDeclSyntax.self) || next.is(ClassDeclSyntax.self) || next.is(ActorDeclSyntax.self)
        || next.is(EnumDeclSyntax.self) || next.is(ProtocolDeclSyntax.self) { crossesLocalType = true }
      ancestors.append(next); parent = next.parent
    }
    let name: String?, form: String
    if let member = node.calledExpression.as(MemberAccessExprSyntax.self), member.declName.argumentNames == nil {
      name = member.declName.baseName.text; form = "member"
    } else if let reference = node.calledExpression.as(DeclReferenceExprSyntax.self), reference.argumentNames == nil {
      name = reference.baseName.text; form = "unqualified"
    } else { name = nil; form = "other" }
    calls.append(DiagnosticCall(site: position(node), caller: caller, form: form, callerReturnNames: returnNames, callerBodyOwned: bodyOwned,
      selector: name.map { $0 + "(" + node.arguments.map { ($0.label?.text ?? "_") + ":" }.joined() + ")" },
      trailingClosure: node.trailingClosure != nil || !node.additionalTrailingClosures.isEmpty,
      tokens: node.tokens(viewMode: .sourceAccurate).map(\.text).joined(separator: " ")))
    return .visitChildren
  }
}
struct IndexedFunction: Encodable {
  let declaration: InventoryFunction
  let unambiguousDeclarationContext: Bool
}
struct IndexedSnapshot: Encodable {
  let functions: [IndexedFunction]
  let properties: [InventoryProperty]
  let declarations: [InventoryDeclaration]
  let scopes: [InventoryScope]
  let calls: [DiagnosticCall]
  init(_ files: [(String, String)]) throws {
    let inventory = try SourceInventory(files: files)
    functions = inventory.functions.map {
      IndexedFunction(declaration: $0, unambiguousDeclarationContext: inventory.hasUnambiguousDeclarationContext($0))
    }
    properties = inventory.properties; declarations = inventory.declarations; scopes = inventory.scopes
    calls = files.sorted(by: { $0.0 < $1.0 }).flatMap { file, source in
      let tree = Array(source.utf8).withUnsafeBufferPointer { Parser.parse(source: $0, swiftVersion: .v6) }
      let reader = CallDiagnosticReader(file: file, tree: tree); reader.walk(tree); return reader.calls
    }
  }
}
struct InventoryDiagnostic: Encodable {
  let meaning = "Diagnostic index, not selected contexts, resolved dependencies, active branches or design verdicts. Source-derived tokens must remain private."
  let before: IndexedSnapshot
  let after: IndexedSnapshot
}
do {
  let arguments = Array(CommandLine.arguments.dropFirst())
  guard arguments.count == 2 else {
    throw NSError(domain: "Usage: inventory diagnostic BEFORE_DIR AFTER_DIR", code: 2)
  }
  let diagnostic = try InventoryDiagnostic(before: IndexedSnapshot(sources(at: arguments[0])),
    after: IndexedSnapshot(sources(at: arguments[1])))
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
  let data = try encoder.encode(diagnostic)
  FileHandle.standardOutput.write(data); FileHandle.standardOutput.write(Data([10]))
} catch {
  FileHandle.standardError.write(Data("\(inputErrorMessage(error))\n".utf8)); exit(2)
}
