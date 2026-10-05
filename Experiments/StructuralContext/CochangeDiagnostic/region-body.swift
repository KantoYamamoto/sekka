// Diagnostic entry in an ignored copy of our own package, never a target build.
// Output contains source-derived tokens and must remain outside public Git.
import SwiftParser
import SwiftSyntax

struct RegionPosition: Codable {
  let file: String
  let line: Int
  let endLine: Int
  let offset: Int
}
func regionTokens(_ node: some SyntaxProtocol) -> String {
  node.tokens(viewMode: .sourceAccurate).map(\.text).joined(separator: " ")
}
struct RegionFact: Encodable {
  let key: [String]
  let kind: String
  let selector: String?
  let site: RegionPosition
  let tokens: String?
}
struct RegionCall: Encodable {
  let site: RegionPosition
  let owner: RegionFact?
  let form: String
  let selector: String?
  let calledExpression: String
  let argumentTokens: [String]
  let trailingClosures: Int
  let conditions: [[String]]
}
struct RegionBranch: Encodable {
  let label: String
  let site: RegionPosition
  let calls: [RegionCall]
}
struct RegionSwitch: Encodable {
  let site: RegionPosition
  let owner: RegionFact?
  let expression: String
  let tokens: String
  let branches: [RegionBranch]
  let conditions: [[String]]
  let containsConditionalCases: Bool
}
final class RegionReader: SyntaxVisitor {
  let file: String
  let converter: SourceLocationConverter
  var regions: [RegionFact] = []
  var calls: [RegionCall] = []
  var switches: [RegionSwitch] = []
  init(file: String, tree: SourceFileSyntax) {
    self.file = file
    converter = SourceLocationConverter(fileName: file, tree: tree)
    super.init(viewMode: .sourceAccurate)
  }
  func position(_ node: some SyntaxProtocol) -> RegionPosition {
    RegionPosition(file: file,
      line: converter.location(for: node.positionAfterSkippingLeadingTrivia).line,
      endLine: converter.location(for: node.endPositionBeforeTrailingTrivia).line,
      offset: node.positionAfterSkippingLeadingTrivia.utf8Offset)
  }
  func header(_ node: some SyntaxProtocol, until: AbsolutePosition?) -> String {
    node.tokens(viewMode: .sourceAccurate).prefix { until == nil || $0.positionAfterSkippingLeadingTrivia < until! }
      .map(\.text).joined(separator: " ")
  }
  func frame(_ node: Syntax) -> String? {
    if let n = node.as(FunctionDeclSyntax.self) { return "function:" + header(n, until: n.body?.leftBrace.position) }
    if let n = node.as(InitializerDeclSyntax.self) { return "initializer:" + header(n, until: n.body?.leftBrace.position) }
    if let n = node.as(DeinitializerDeclSyntax.self) { return "deinitializer:" + header(n, until: n.body?.leftBrace.position) }
    if let n = node.as(AccessorDeclSyntax.self) { return "accessor:" + header(n, until: n.body?.leftBrace.position) }
    if let n = node.as(PatternBindingSyntax.self) {
      return "binding:" + header(n, until: n.initializer?.positionAfterSkippingLeadingTrivia ?? n.accessorBlock?.positionAfterSkippingLeadingTrivia)
    }
    if let n = node.as(StructDeclSyntax.self) { return "struct:" + header(n, until: n.memberBlock.leftBrace.position) }
    if let n = node.as(ClassDeclSyntax.self) { return "class:" + header(n, until: n.memberBlock.leftBrace.position) }
    if let n = node.as(EnumDeclSyntax.self) { return "enum:" + header(n, until: n.memberBlock.leftBrace.position) }
    if let n = node.as(ActorDeclSyntax.self) { return "actor:" + header(n, until: n.memberBlock.leftBrace.position) }
    if let n = node.as(ProtocolDeclSyntax.self) { return "protocol:" + header(n, until: n.memberBlock.leftBrace.position) }
    if let n = node.as(ExtensionDeclSyntax.self) { return "extension:" + header(n, until: n.memberBlock.leftBrace.position) }
    return nil
  }
  // Lexical conditions, not active branches or control-flow dominance.
  func conditions(_ node: some SyntaxProtocol) -> [[String]] {
    var result: [[String]] = [], parent = node.parent
    while let n = parent {
      if let clause = n.as(IfConfigClauseSyntax.self), let list = clause.parent?.as(IfConfigClauseListSyntax.self) {
        var prefix: [String] = []
        for c in list {
          prefix.append(c.poundKeyword.text + " " + (c.condition.map(regionTokens) ?? ""))
          if c.id == clause.id { break }
        }
        result.append(["conditional-compilation"] + prefix)
      }
      if let body = n.as(CodeBlockSyntax.self), let enclosing = body.parent?.as(IfExprSyntax.self) {
        result.append(["if", regionTokens(enclosing.conditions), body.id == enclosing.body.id ? "then" : "else"])
      }
      if let c = n.as(ClosureExprSyntax.self) { result.append(["closure", c.signature.map(regionTokens) ?? "implicit"]) }
      if let c = n.as(SwitchCaseSyntax.self) { result.append(["enclosing-case", regionTokens(c.label)]) }
      parent = n.parent
    }
    return result.reversed()
  }
  func fact(_ node: Syntax, kind: String, selector: String? = nil, captureTokens: Bool = true) -> RegionFact {
    var headers: [String] = [], parent: Syntax? = node
    while let n = parent {
      if let s = frame(n) { headers.append(s) }
      // Binding specifier/modifiers are context too, including computed property headers.
      if let v = n.as(VariableDeclSyntax.self) {
        headers.append("variable:" + regionTokens(v.attributes) + ":" + regionTokens(v.modifiers) + ":" + v.bindingSpecifier.text)
      }
      parent = n.parent
    }
    let key = [file] + headers.reversed() + conditions(node).filter { $0.first == "conditional-compilation" }.map { $0.joined(separator: "|") }
    return RegionFact(key: key, kind: kind, selector: selector, site: position(node), tokens: captureTokens ? regionTokens(node) : nil)
  }
  func owner(_ node: some SyntaxProtocol) -> RegionFact? {
    var ancestors: Set<SyntaxIdentifier> = [Syntax(node).id], parent = node.parent
    while let n = parent {
      if let f = n.as(FunctionDeclSyntax.self) {
        guard let body = f.body, ancestors.contains(body.id) else { return nil }
        return fact(n, kind: "function", selector: f.name.text + "(" + f.signature.parameterClause.parameters.map { $0.firstName.text + ":" }.joined() + ")", captureTokens: false)
      }
      if let f = n.as(InitializerDeclSyntax.self) {
        guard let body = f.body, ancestors.contains(body.id) else { return nil }
        return fact(n, kind: "initializer", captureTokens: false)
      }
      if let f = n.as(DeinitializerDeclSyntax.self) {
        guard let body = f.body, ancestors.contains(body.id) else { return nil }
        return fact(n, kind: "deinitializer", captureTokens: false)
      }
      if let f = n.as(AccessorDeclSyntax.self) {
        guard let body = f.body, ancestors.contains(body.id) else { return nil }
        return fact(n, kind: "accessor", captureTokens: false)
      }
      if let f = n.as(PatternBindingSyntax.self) {
        if let value = f.initializer?.value, ancestors.contains(value.id) { return fact(n, kind: "binding-initializer", captureTokens: false) }
        if let block = f.accessorBlock, ancestors.contains(block.id) { return fact(n, kind: "property-body", captureTokens: false) }
        return nil
      }
      // A local type starts a separate declaration context; do not assign its header calls to an outer body.
      if n.is(StructDeclSyntax.self) || n.is(ClassDeclSyntax.self) || n.is(EnumDeclSyntax.self)
        || n.is(ActorDeclSyntax.self) || n.is(ProtocolDeclSyntax.self) { return nil }
      ancestors.insert(n.id); parent = n.parent
    }
    return nil
  }
  func call(_ n: FunctionCallExprSyntax) -> RegionCall {
    let name: String?, form: String
    if let m = n.calledExpression.as(MemberAccessExprSyntax.self), m.declName.argumentNames == nil {
      name = m.declName.baseName.text; form = "member"
    } else if let r = n.calledExpression.as(DeclReferenceExprSyntax.self), r.argumentNames == nil {
      name = r.baseName.text; form = "unqualified"
    } else { name = nil; form = "other" }
    return RegionCall(site: position(n), owner: owner(n), form: form,
      selector: name.map { $0 + "(" + n.arguments.map { ($0.label?.text ?? "_") + ":" }.joined() + ")" },
      calledExpression: regionTokens(n.calledExpression), argumentTokens: n.arguments.map { regionTokens($0.expression) },
      trailingClosures: (n.trailingClosure == nil ? 0 : 1) + n.additionalTrailingClosures.count,
      conditions: conditions(n))
  }
  override func visit(_ n: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind { calls.append(call(n)); return .visitChildren }
  override func visit(_ n: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
    regions.append(fact(Syntax(n), kind: "function", selector: n.name.text + "(" + n.signature.parameterClause.parameters.map { $0.firstName.text + ":" }.joined() + ")")); return .visitChildren
  }
  override func visit(_ n: InitializerDeclSyntax) -> SyntaxVisitorContinueKind { regions.append(fact(Syntax(n), kind: "initializer")); return .visitChildren }
  override func visit(_ n: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind { regions.append(fact(Syntax(n), kind: "deinitializer")); return .visitChildren }
  override func visit(_ n: AccessorDeclSyntax) -> SyntaxVisitorContinueKind { regions.append(fact(Syntax(n), kind: "accessor")); return .visitChildren }
  override func visit(_ n: PatternBindingSyntax) -> SyntaxVisitorContinueKind {
    if n.initializer != nil || n.accessorBlock != nil {
      regions.append(fact(Syntax(n), kind: n.initializer != nil ? "binding-initializer" : "property-body"))
    }
    return .visitChildren
  }
  override func visit(_ n: SwitchExprSyntax) -> SyntaxVisitorContinueKind {
    var branches: [RegionBranch] = [], conditional = false
    for item in n.cases {
      guard let c = item.as(SwitchCaseSyntax.self) else { conditional = true; continue }
      let reader = BranchCalls(parent: self); reader.walk(c.statements)
      branches.append(RegionBranch(label: regionTokens(c.label), site: position(c), calls: reader.calls))
    }
    switches.append(RegionSwitch(site: position(n), owner: owner(n), expression: regionTokens(n.subject), tokens: regionTokens(n),
      branches: branches, conditions: conditions(n), containsConditionalCases: conditional))
    return .visitChildren
  }
}
final class BranchCalls: SyntaxVisitor {
  let parentReader: RegionReader
  var calls: [RegionCall] = []
  init(parent: RegionReader) { parentReader = parent; super.init(viewMode: .sourceAccurate) }
  override func visit(_ n: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind { calls.append(parentReader.call(n)); return .visitChildren }
  override func visit(_ n: FunctionDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ n: InitializerDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ n: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ n: AccessorDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ n: StructDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ n: ClassDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ n: EnumDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ n: ActorDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ n: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
  override func visit(_ n: SwitchExprSyntax) -> SyntaxVisitorContinueKind { .skipChildren }
}
struct OldIndexedFunction: Encodable {
  let site: SourceSite
  let selector: String
  let declarationTokens: String
  let correspondenceID: String
  let lexicalScopeHeaders: [String]
}
struct RegionSnapshot: Encodable {
  let regions: [RegionFact]
  let calls: [RegionCall]
  let switches: [RegionSwitch]
  let indexedFunctions: [OldIndexedFunction]
  init(_ files: [(String, String)]) throws {
    // Validate all sources before any output; retain old inventory for boundary diagnosis.
    let inventory = try SourceInventory(files: files)
    indexedFunctions = inventory.functions.map {
      OldIndexedFunction(site: $0.site, selector: $0.selector, declarationTokens: $0.declarationTokens,
        correspondenceID: $0.correspondenceID, lexicalScopeHeaders: $0.lexicalScopeHeaders)
    }
    var rs: [RegionFact] = [], cs: [RegionCall] = [], ss: [RegionSwitch] = []
    for (file, source) in files.sorted(by: { $0.0 < $1.0 }) {
      let tree = Array(source.utf8).withUnsafeBufferPointer { Parser.parse(source: $0, swiftVersion: .v6) }
      guard !tree.hasError else { throw ContextError.malformed(file) }
      let reader = RegionReader(file: file, tree: tree); reader.walk(tree)
      rs += reader.regions; cs += reader.calls; ss += reader.switches
    }
    regions = rs; calls = cs; switches = ss
  }
}
struct RegionDiagnostic: Encodable {
  let meaning = "Written syntax regions and call spellings only. No equivalence, active branches, resolved dependency or design verdict. Keep source-derived output private."
  let before: RegionSnapshot
  let after: RegionSnapshot
}
do {
  let args = Array(CommandLine.arguments.dropFirst())
  guard args.count == 2 else { throw NSError(domain: "Usage: region diagnostic BEFORE_DIR AFTER_DIR", code: 2) }
  let result = try RegionDiagnostic(before: RegionSnapshot(sources(at: args[0])), after: RegionSnapshot(sources(at: args[1])))
  let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
  FileHandle.standardOutput.write(try encoder.encode(result)); FileHandle.standardOutput.write(Data([10]))
} catch {
  FileHandle.standardError.write(Data("\(inputErrorMessage(error))\n".utf8)); exit(2)
}
