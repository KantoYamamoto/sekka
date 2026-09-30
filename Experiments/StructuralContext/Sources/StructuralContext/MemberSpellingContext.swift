public struct MemberSpellingEntry: Codable, Sendable {
  public let beforeCaller: SourceSite?
  public let afterCaller: SourceSite
  public let callerEvidence: String
  public let call: InventoryWrittenMemberCall
  public let eligibleOccurrences: Int
  public let matchingIndexedDeclarations: Int
}

struct MemberSpellingMatch {
  let before: InventoryFunction
  let after: InventoryFunction
  let entry: MemberSpellingEntry
}
struct MemberSpellingResult {
  var matches: [MemberSpellingMatch] = []
  var skipped: [String: Int] = [:]
}

enum MemberSpellingContext {
  static func find(old: SourceInventory, new: SourceInventory, oldFiles: [String: String], newFiles: [String: String]) -> MemberSpellingResult {
    let oldKeys = Dictionary(grouping: old.functions, by: \.correspondenceID)
    let newKeys = Dictionary(grouping: new.functions, by: \.correspondenceID)
    let selectors = Dictionary(grouping: new.functions, by: \.selector)
    let oldTexts = Dictionary(grouping: old.functions, by: { $0.site.file }).mapValues { Set($0.map(\.declarationTokens)) }
    var result = MemberSpellingResult()
    func skip(_ reason: String) { result.skipped["spelling:" + reason, default: 0] += 1 }
    for caller in new.functions {
      guard oldFiles[caller.site.file] != newFiles[caller.site.file],
        !oldTexts[caller.site.file, default: []].contains(caller.declarationTokens) else { continue }
      let previous = oldKeys[caller.correspondenceID, default: []]
      let paired = previous.count == 1 && newKeys[caller.correspondenceID, default: []].count == 1
        && old.hasUnambiguousDeclarationContext(previous[0]) && new.hasUnambiguousDeclarationContext(caller)
        && previous[0].lexicalScopeHeaders == caller.lexicalScopeHeaders
      let oldCalls = paired ? Set(previous[0].writtenMemberCalls.map(\.tokens)) : []
      // Eligibility precedes grouping: the old occurrence must not become the displayed first site.
      let eligible = caller.writtenMemberCalls.filter { !paired || !oldCalls.contains($0.tokens) }
      let groups = Dictionary(grouping: eligible, by: { inventoryKey([$0.selector, $0.receiverSpelling]) })
      for group in groups.values.sorted(by: { $0[0].site.line == $1[0].site.line ? $0[0].tokens < $1[0].tokens : $0[0].site.line < $1[0].site.line }) {
        let call = group[0], candidates = selectors[call.selector, default: []]
        guard candidates.count == 1 else { skip(candidates.isEmpty ? "no-exact-label-declaration" : "multiple-exact-label-declarations"); continue }
        let target = candidates[0]
        guard target.bodyTokens != nil else { skip("declaration-without-body"); continue }
        let before = oldKeys[target.correspondenceID, default: []]
        guard before.count == 1, newKeys[target.correspondenceID, default: []].count == 1,
          old.hasUnambiguousDeclarationContext(before[0]), new.hasUnambiguousDeclarationContext(target) else {
          skip("target-correspondence-unknown"); continue
        }
        guard before[0].lexicalScopeHeaders == target.lexicalScopeHeaders else { skip("target-scope-header-changed"); continue }
        guard before[0].declarationTokens == target.declarationTokens else { skip("target-declaration-changed"); continue }
        result.matches.append(MemberSpellingMatch(before: before[0], after: target,
          entry: MemberSpellingEntry(beforeCaller: paired ? previous[0].site : nil, afterCaller: caller.site,
            callerEvidence: paired ? "call-text-absent-from-paired-old-body" : "no-unique-old-indexed-correspondence",
            call: call, eligibleOccurrences: group.count, matchingIndexedDeclarations: candidates.count)))
      }
    }
    return result
  }
}
