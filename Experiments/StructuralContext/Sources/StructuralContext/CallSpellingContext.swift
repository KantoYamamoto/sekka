public struct MemberSpellingEntry: Codable, Sendable {
  public let sourceSide: SnapshotSide
  public let beforeCaller: SourceSite?
  public let afterCaller: SourceSite
  public let callerEvidence: String
  public let call: InventoryWrittenCall
  public let eligibleOccurrences: Int
  public let matchingIndexedDeclarations: Int
}

public struct SelectorDecreaseEntry: Codable, Sendable {
  public let selector: String
  public let beforeOccurrences: [WrittenCallOccurrence]
  public let afterOccurrences: [WrittenCallOccurrence]
  public let matchingBeforeDeclarations: Int
  public let matchingAfterDeclarations: Int
}

public enum CallSpellingEntry: Codable, Sendable {
  case introduced(evidence: MemberSpellingEntry)
  case decreased(evidence: SelectorDecreaseEntry)
}

struct CallSpellingMatch {
  let before: InventoryFunction
  let after: InventoryFunction
  let entry: CallSpellingEntry
}
struct CallSpellingResult {
  var matches: [CallSpellingMatch] = []
  var skipped: [String: Int] = [:]
}

enum CallSpellingContext {
  static func find(search: WrittenCallSearch, oldFiles: [String: String], newFiles: [String: String]) -> CallSpellingResult {
    let selectors = search.afterBySelector
    var result = CallSpellingResult()
    func skip(_ reason: String) { result.skipped["spelling:" + reason, default: 0] += 1 }
    for anchor in search.introducedAnchors(oldFiles: oldFiles, newFiles: newFiles) {
      let caller = anchor.caller
      let eligible = anchor.eligible.filter { $0.form == .member }
      let groups = Dictionary(grouping: eligible, by: { inventoryKey([$0.selector, $0.receiverSpelling ?? "", inventoryKey($0.writtenConditions.map(\.groupingKey))]) })
      for group in groups.values.sorted(by: { $0[0].site.line == $1[0].site.line ? $0[0].tokens < $1[0].tokens : $0[0].site.line < $1[0].site.line }) {
        let call = group[0], candidates = selectors[call.selector, default: []]
        guard candidates.count == 1 else { skip(candidates.isEmpty ? "no-exact-label-declaration" : "multiple-exact-label-declarations"); continue }
        let target = candidates[0]
        let stable = search.stable(target)
        guard let before = stable.before else { skip(stable.reason!); continue }
        result.matches.append(CallSpellingMatch(before: before, after: target,
          entry: .introduced(evidence: MemberSpellingEntry(sourceSide: anchor.side, beforeCaller: anchor.counterpart?.site, afterCaller: caller.site,
            callerEvidence: anchor.callerEvidence,
            call: call, eligibleOccurrences: group.count, matchingIndexedDeclarations: candidates.count))))
      }
    }
    for decrease in search.decreases() {
      let target = search.retainedSelector(decrease.selector)
      guard let before = target.before, let after = target.after else {
        result.skipped["decrease:" + target.reason!, default: 0] += 1; continue
      }
      result.matches.append(CallSpellingMatch(before: before, after: after,
        entry: .decreased(evidence: SelectorDecreaseEntry(selector: decrease.selector,
          beforeOccurrences: decrease.before.map { search.occurrence($0, side: .before) },
          afterOccurrences: decrease.after.map { search.occurrence($0, side: .after) },
          matchingBeforeDeclarations: 1, matchingAfterDeclarations: 1))))
    }
    return result
  }
}
