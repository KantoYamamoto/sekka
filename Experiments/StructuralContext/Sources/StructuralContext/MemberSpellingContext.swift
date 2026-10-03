public struct MemberSpellingEntry: Codable, Sendable {
  public let beforeCaller: SourceSite?
  public let afterCaller: SourceSite
  public let callerEvidence: String
  public let call: InventoryWrittenCall
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
    let search = WrittenCallSearch(old: old, new: new)
    let selectors = Dictionary(grouping: new.functions, by: \.selector)
    var result = MemberSpellingResult()
    func skip(_ reason: String) { result.skipped["spelling:" + reason, default: 0] += 1 }
    for anchor in search.anchors(oldFiles: oldFiles, newFiles: newFiles) {
      let caller = anchor.after
      let eligible = anchor.eligible.filter { $0.form == .member }
      let groups = Dictionary(grouping: eligible, by: { inventoryKey([$0.selector, $0.receiverSpelling ?? "", inventoryKey($0.writtenConditions.map(\.groupingKey))]) })
      for group in groups.values.sorted(by: { $0[0].site.line == $1[0].site.line ? $0[0].tokens < $1[0].tokens : $0[0].site.line < $1[0].site.line }) {
        let call = group[0], candidates = selectors[call.selector, default: []]
        guard candidates.count == 1 else { skip(candidates.isEmpty ? "no-exact-label-declaration" : "multiple-exact-label-declarations"); continue }
        let target = candidates[0]
        let stable = search.stable(target)
        guard let before = stable.before else { skip(stable.reason!); continue }
        result.matches.append(MemberSpellingMatch(before: before, after: target,
          entry: MemberSpellingEntry(beforeCaller: anchor.before?.site, afterCaller: caller.site,
            callerEvidence: anchor.callerEvidence,
            call: call, eligibleOccurrences: group.count, matchingIndexedDeclarations: candidates.count)))
      }
    }
    return result
  }
}
