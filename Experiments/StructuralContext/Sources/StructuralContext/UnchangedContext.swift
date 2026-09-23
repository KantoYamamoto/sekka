import Foundation

public struct CallEntry: Codable, Sendable {
  public let beforeCaller: SourceSite
  public let afterCaller: SourceSite
  public let beforeExistingCall: SourceSite
  public let afterExistingCall: SourceSite
  public let newOrChangedCall: SourceSite
  public let beforeReceiver: SourceSite
  public let afterReceiver: SourceSite
  public let writtenType: String
  public let sharedArgumentSpellings: [String]
}
public struct TypeEntry: Codable, Sendable {
  public let beforeStatus: String
  public let beforeProperty: SourceSite?
  public let afterProperty: SourceSite
  public let beforeType: String?
  public let afterType: String
  public let reference: InventoryTypeName
  public let matchingDeclarations: Int
}
public enum ContextEvidence: Codable, Sendable {
  case existingCall(evidence: CallEntry)
  case changedType(evidence: TypeEntry)
  public var call: CallEntry? {
    if case let .existingCall(evidence) = self { return evidence }; return nil
  }
  public var typeChange: TypeEntry? {
    if case let .changedType(evidence) = self { return evidence }; return nil
  }
}
public struct UnchangedTarget: Codable, Sendable {
  public let before: SourceSite
  public let after: SourceSite
  public let fileUnchanged: Bool
  public let kind: String
  public let entries: [ContextEvidence]
  public let omittedEntries: Int
}
public struct SearchOmission: Codable, Sendable {
  public let reason: String
  public let count: Int
}
public struct ContextReport: Codable, Sendable {
  public let scope: String
  public let limitations: [String]
  public let beforeFileCount: Int
  public let afterFileCount: Int
  public let changedFunctions: Int
  public let changedTypeAnnotations: Int
  public let unpairedBefore: Int
  public let unpairedAfter: Int
  public let contexts: [UnchangedTarget]
  public let omittedTargets: Int
  public let skipped: [SearchOmission]
}

private struct TargetAccumulator {
  let before: SourceSite
  let after: SourceSite
  let kind: String
  var entries: [ContextEvidence]
}
public enum UnchangedContext {
  public static func compare(before: [(String, String)], after: [(String, String)]) throws -> ContextReport {
    let old = try SourceInventory(files: before), new = try SourceInventory(files: after)
    let oldIDs = Dictionary(grouping: old.functions, by: \.id), newIDs = Dictionary(grouping: new.functions, by: \.id)
    let oldFiles = Dictionary(uniqueKeysWithValues: before), newFiles = Dictionary(uniqueKeysWithValues: after)
    var skips: [String: Int] = [:], changed = 0, unpairedBefore = 0, unpairedAfter = 0
    var targets: [String: TargetAccumulator] = [:]
    func add(_ key: String, before: SourceSite, after: SourceSite, kind: String, entry: ContextEvidence) {
      if targets[key] == nil { targets[key] = TargetAccumulator(before: before, after: after, kind: kind, entries: []) }
      targets[key]!.entries.append(entry)
    }
    func skip(_ reason: String) { skips[reason, default: 0] += 1 }
    for id in Set(oldIDs.keys).union(newIDs.keys).sorted() {
      let os = oldIDs[id, default: []], ns = newIDs[id, default: []]
      guard os.count == 1, ns.count == 1 else {
        unpairedBefore += os.count; unpairedAfter += ns.count; continue
      }
      let previous = os[0], current = ns[0]
      guard previous.declarationTokens != current.declarationTokens else { continue }
      changed += 1
      guard previous.unsupported.isEmpty, current.unsupported.isEmpty else { skip("unsupported-caller-scope"); continue }
      let oldTokens = Dictionary(previous.statements.map { ($0.tokens, 1) }, uniquingKeysWith: +)
      let newTokens = Dictionary(current.statements.map { ($0.tokens, 1) }, uniquingKeysWith: +)
      var candidateCount = 0
      for (offset, statement) in current.statements.enumerated() {
        guard let added = statement.call, oldTokens[statement.tokens] == nil else { continue }
        candidateCount += 1
        guard newTokens[statement.tokens] == 1 else { skip("repeated-new-or-changed-statement"); continue }
        guard offset > 0 else { skip("no-preceding-statement"); continue }
        let preceding = current.statements[offset - 1]
        guard let call = preceding.call, let receiver = call.receiver else { skip("no-preceding-member-call"); continue }
        guard oldTokens[preceding.tokens] == 1, newTokens[preceding.tokens] == 1,
          let oldCall = previous.statements.first(where: { $0.tokens == preceding.tokens })?.call else {
          skip("existing-call-not-unique-or-changed"); continue
        }
        let shared = Set(call.identifierArguments).intersection(added.identifierArguments).sorted()
        guard !shared.isEmpty else { skip("no-shared-identifier-argument"); continue }
        let a = old.memberCandidate(callerID: id, receiver: receiver, selector: call.selector, explicitSelf: call.explicitSelf)
        let b = new.memberCandidate(callerID: id, receiver: receiver, selector: call.selector, explicitSelf: call.explicitSelf)
        guard let ae = a.evidence else { skip("before:" + a.reason); continue }
        guard let be = b.evidence else { skip("after:" + b.reason); continue }
        let ao = old.types.filter { $0.id == previous.ownerID }, bo = new.types.filter { $0.id == current.ownerID }
        guard ao.count == 1, bo.count == 1, ao[0].headerTokens == bo[0].headerTokens,
          ae.property.declarationTokens == be.property.declarationTokens,
          ae.targetType.id == be.targetType.id, ae.targetType.headerTokens == be.targetType.headerTokens,
          ae.target.id == be.target.id else { skip("candidate-path-changed"); continue }
        guard ae.target.declarationTokens == be.target.declarationTokens else { skip("target-declaration-changed"); continue }
        guard let beforeType = ae.property.typeSite, let afterType = be.property.typeSite else { skip("missing-type-site"); continue }
        let entry = CallEntry(beforeCaller: previous.site, afterCaller: current.site,
          beforeExistingCall: oldCall.site, afterExistingCall: call.site, newOrChangedCall: added.site,
          beforeReceiver: beforeType, afterReceiver: afterType, writtenType: be.property.typeSpelling ?? "",
          sharedArgumentSpellings: shared)
        add("function:" + be.target.id, before: ae.target.site, after: be.target.site,
          kind: "function", entry: .existingCall(evidence: entry))
      }
      if candidateCount == 0 { skip("no-new-or-changed-direct-call"); }
    }
    // Names in annotations are declaration-search keys, not inferred dependencies.
    func propertyID(_ property: InventoryProperty) -> String { property.ownerID + ":" + property.name }
    func declarationID(_ declaration: InventoryDeclaration) -> String { declaration.kind + ":" + declaration.id }
    let oldProperties = Dictionary(grouping: old.properties, by: propertyID)
    let newProperties = Dictionary(grouping: new.properties, by: propertyID)
    let oldDeclarations = Dictionary(grouping: old.declarations, by: declarationID)
    let newDeclarations = Dictionary(grouping: new.declarations, by: declarationID)
    let names = Dictionary(grouping: new.declarations, by: \.name)
    var changedAnnotations = 0
    for key in newProperties.keys.sorted() {
      let previous = oldProperties[key, default: []], current = newProperties[key, default: []]
      // Unchanged annotation multisets cannot introduce a new written type name.
      // Do not repeat unrelated ambiguous declarations as changed-query omissions.
      if previous.map({ $0.typeSpelling ?? "" }).sorted() == current.map({ $0.typeSpelling ?? "" }).sorted() { continue }
      guard current.count == 1, previous.count <= 1 else { skip("type:property-correspondence-ambiguous"); continue }
      let property = current[0], oldProperty = previous.first
      guard let spelling = property.typeSpelling, spelling != oldProperty?.typeSpelling else { continue }
      changedAnnotations += 1
      let owners = new.types.filter { $0.id == property.ownerID }
      guard owners.count == 1 else { skip("type:owner-correspondence-ambiguous"); continue }
      let previousNames = Set(oldProperty?.typeNames.map(\.written) ?? [])
      let introduced = Dictionary(grouping: property.typeNames.filter { !previousNames.contains($0.written) }, by: \.written)
      for reason in property.typeNameUnknowns { skip("type:" + reason) }
      if introduced.isEmpty && property.typeNameUnknowns.isEmpty { skip("type:no-new-written-name") }
      for written in introduced.keys.sorted() {
        let reference = introduced[written]![0]
        let rootName = written.split(separator: ".").first.map(String.init) ?? written
        guard !owners[0].boundTypeNames.contains(rootName) else { skip("type:bound-type-reference"); continue }
        let candidates = names[reference.name, default: []]
        if candidates.isEmpty { skip("type:no-matching-declaration") }
        for candidateKey in Set(candidates.map(declarationID)).sorted() {
          let os = oldDeclarations[candidateKey, default: []], ns = newDeclarations[candidateKey, default: []]
          guard os.count == 1, ns.count == 1 else {
            skip(os.isEmpty ? "type:no-before-declaration" : "type:declaration-correspondence-ambiguous"); continue
          }
          guard os[0].declarationTokens == ns[0].declarationTokens else { skip("type:declaration-changed"); continue }
          let entry = TypeEntry(beforeStatus: oldProperty == nil ? "no-indexed-counterpart" : "indexed-counterpart", beforeProperty: oldProperty?.site, afterProperty: property.site,
            beforeType: oldProperty?.typeSpelling, afterType: spelling, reference: reference,
            matchingDeclarations: candidates.count)
          add("declaration:" + candidateKey, before: os[0].site, after: ns[0].site,
            kind: ns[0].kind, entry: .changedType(evidence: entry))
        }
      }
    }
    let keys = targets.keys.sorted {
      let a = targets[$0]!, b = targets[$1]!
      if a.after.file != b.after.file { return a.after.file < b.after.file }
      if a.after.line != b.after.line { return a.after.line < b.after.line }
      return $0 < $1
    }
    let contexts = keys.prefix(8).map { key -> UnchangedTarget in
      let target = targets[key]!
      return UnchangedTarget(before: target.before, after: target.after,
        fileUnchanged: oldFiles[target.before.file] == newFiles[target.after.file], kind: target.kind,
        entries: Array(target.entries.prefix(8)), omittedEntries: max(0, target.entries.count - 8))
    }
    return ContextReport(scope: "experiment: unchanged declaration candidates reached by written annotation names or adjacent direct calls",
      limitations: [
        "Type entries search new written names in property annotations by terminal name, including generic arguments. Qualified owners/modules and aliases are not resolved. Known lexical generic/associated type parameters and Self references are excluded; placeholder and unsupported qualified types are reported separately. Nominal/alias declarations and properties inside extensions or local functions are not indexed.",
        "Type candidates are paired uniquely by file, lexical owner, name and kind. A missing indexed property counterpart does not prove that no declaration existed outside the indexed scope. Other inherited or shadowing type bindings are not resolved. The candidate declaration tokens are unchanged, not the entire type including extensions, alias expansion, macros or active conditional branches. Each property's repeated qualified name uses its first written position.",
        "Written type and selector candidates, not resolved callees, dependencies or shared responsibility. Adjacency and identical argument spelling do not prove related behavior or equal values.",
        "Call entries: only direct call statements in uniquely paired indexed member functions are searched. A newOrChangedCall has no token-identical statement in the old body; it can be an edit to an existing call, not necessarily an insertion. Added/removed/renamed or ambiguous functions, nested control blocks, try/await wrappers and complex argument expressions are not covered.",
        "Call entries: receiver annotation, owner/type headers and target declaration must match across snapshots. Same ID alone is not unchanged evidence. Supported lookup scopes and explicit rejection reasons come from SourceInventory.",
        "Unchanged declaration does not mean absent from diff context lines. File equality is explicit; hunk visibility is not evaluated. No design verdict or automatic integration advice.",
        "At most 8 targets and 8 entries per target; omissions are counted. Skips count rejected call queries/functions, type correspondence groups or declaration-search attempts; they are not unique files or review coverage. Zero results is not approval.",
      ], beforeFileCount: before.count, afterFileCount: after.count, changedFunctions: changed, changedTypeAnnotations: changedAnnotations,
      unpairedBefore: unpairedBefore, unpairedAfter: unpairedAfter, contexts: contexts,
      omittedTargets: max(0, keys.count - 8), skipped: skips.keys.sorted().map { SearchOmission(reason: $0, count: skips[$0]!) })
  }
}
