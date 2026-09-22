import Foundation

public struct ContextEntry: Codable, Sendable {
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
public struct UnchangedTarget: Codable, Sendable {
  public let before: SourceSite
  public let after: SourceSite
  public let fileUnchanged: Bool
  public let entries: [ContextEntry]
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
  public let unpairedBefore: Int
  public let unpairedAfter: Int
  public let contexts: [UnchangedTarget]
  public let omittedTargets: Int
  public let skipped: [SearchOmission]
}

public enum UnchangedContext {
  public static func compare(before: [(String, String)], after: [(String, String)]) throws -> ContextReport {
    let old = try SourceInventory(files: before), new = try SourceInventory(files: after)
    let oldIDs = Dictionary(grouping: old.functions, by: \.id), newIDs = Dictionary(grouping: new.functions, by: \.id)
    let oldFiles = Dictionary(uniqueKeysWithValues: before), newFiles = Dictionary(uniqueKeysWithValues: after)
    var skips: [String: Int] = [:], changed = 0, unpairedBefore = 0, unpairedAfter = 0
    var targets: [String: (InventoryFunction, InventoryFunction, [ContextEntry])] = [:]
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
        let entry = ContextEntry(beforeCaller: previous.site, afterCaller: current.site,
          beforeExistingCall: oldCall.site, afterExistingCall: call.site, newOrChangedCall: added.site,
          beforeReceiver: beforeType, afterReceiver: afterType, writtenType: be.property.typeSpelling ?? "",
          sharedArgumentSpellings: shared)
        let key = be.target.id
        if targets[key] == nil { targets[key] = (ae.target, be.target, []) }
        targets[key]!.2.append(entry)
      }
      if candidateCount == 0 { skip("no-new-or-changed-direct-call"); }
    }
    let keys = targets.keys.sorted()
    let contexts = keys.prefix(8).map { key -> UnchangedTarget in
      let (a, b, entries) = targets[key]!
      return UnchangedTarget(before: a.site, after: b.site,
        fileUnchanged: oldFiles[a.site.file] == newFiles[b.site.file],
        entries: Array(entries.prefix(8)), omittedEntries: max(0, entries.count - 8))
    }
    return ContextReport(scope: "experiment: unchanged declared member candidates reached from adjacent direct calls sharing identifier arguments",
      limitations: [
        "Written type and selector candidates, not resolved callees, dependencies or shared responsibility. Adjacency and identical argument spelling do not prove related behavior or equal values.",
        "Only direct call statements in uniquely paired indexed member functions are searched. A newOrChangedCall has no token-identical statement in the old body; it can be an edit to an existing call, not necessarily an insertion. Added/removed/renamed or ambiguous functions, nested control blocks, try/await wrappers and complex argument expressions are not covered.",
        "Receiver annotation, owner/type headers and target declaration must match across snapshots. Same ID alone is not unchanged evidence. Supported lookup scopes and explicit rejection reasons come from SourceInventory.",
        "Unchanged declaration does not mean absent from diff context lines. File equality is explicit; hunk visibility is not evaluated. No design verdict or automatic integration advice.",
        "At most 8 targets and 8 entries per target; omissions are counted. Skips count rejected new/changed statements or changed functions without eligible new/changed direct calls, not unique files or review coverage. Zero results is not approval.",
      ], beforeFileCount: before.count, afterFileCount: after.count, changedFunctions: changed,
      unpairedBefore: unpairedBefore, unpairedAfter: unpairedAfter, contexts: contexts,
      omittedTargets: max(0, keys.count - 8), skipped: skips.keys.sorted().map { SearchOmission(reason: $0, count: skips[$0]!) })
  }
}
