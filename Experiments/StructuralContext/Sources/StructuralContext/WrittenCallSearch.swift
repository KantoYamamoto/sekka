struct WrittenCallAnchor {
  let side: SnapshotSide
  let caller: InventoryFunction
  let counterpart: InventoryFunction?
  let eligible: [InventoryWrittenCall]
  var callerEvidence: String { counterpart == nil ? "no-unique-old-indexed-correspondence" : "call-text-absent-from-paired-old-body" }
}

public enum SnapshotSide: String, Codable, Sendable { case before, after }

public struct WrittenCallOccurrence: Codable, Sendable {
  public let side: SnapshotSide
  public let caller: SourceSite
  public let counterpartCaller: SourceSite?
  public let correspondence: String
  public let call: InventoryWrittenCall
}

struct IndexedCallUse {
  let caller: InventoryFunction
  let call: InventoryWrittenCall
}

struct WrittenSelectorDecrease {
  let selector: String
  let before: [IndexedCallUse]
  let after: [IndexedCallUse]
}

/// Shared syntax correspondence and eligibility; never resolves calls or receiver types.
struct WrittenCallSearch {
  let old: SourceInventory
  let new: SourceInventory
  let beforeByKey: [String: [InventoryFunction]]
  let afterByKey: [String: [InventoryFunction]]
  let beforeBySelector: [String: [InventoryFunction]]
  let afterBySelector: [String: [InventoryFunction]]
  let beforeUses: [String: [IndexedCallUse]]
  let afterUses: [String: [IndexedCallUse]]
  init(old: SourceInventory, new: SourceInventory) {
    self.old = old; self.new = new
    beforeByKey = Dictionary(grouping: old.functions, by: \.correspondenceID)
    afterByKey = Dictionary(grouping: new.functions, by: \.correspondenceID)
    beforeBySelector = Dictionary(grouping: old.functions, by: \.selector)
    afterBySelector = Dictionary(grouping: new.functions, by: \.selector)
    func uses(_ functions: [InventoryFunction]) -> [String: [IndexedCallUse]] {
      Dictionary(grouping: functions.flatMap { caller in
        caller.writtenCalls.map { IndexedCallUse(caller: caller, call: $0) }
      }, by: { $0.call.selector })
    }
    beforeUses = uses(old.functions); afterUses = uses(new.functions)
  }
  func introducedAnchors(oldFiles: [String: String], newFiles: [String: String]) -> [WrittenCallAnchor] {
    let oldTexts = Dictionary(grouping: old.functions, by: { $0.site.file }).mapValues { Set($0.map(\.declarationTokens)) }
    return new.functions.compactMap { caller in
      guard oldFiles[caller.site.file] != newFiles[caller.site.file],
        !oldTexts[caller.site.file, default: []].contains(caller.declarationTokens) else { return nil }
      let previous = counterpart(caller, side: .after).function
      let oldCalls = Set(previous?.writtenCalls.map(\.tokens) ?? [])
      return WrittenCallAnchor(side: .after, caller: caller, counterpart: previous,
        eligible: caller.writtenCalls.filter { previous == nil || !oldCalls.contains($0.tokens) })
    }
  }
  func decreases() -> [WrittenSelectorDecrease] {
    beforeUses.keys.sorted().compactMap { selector in
      let before = beforeUses[selector]!, after = afterUses[selector, default: []]
      guard before.count > after.count else { return nil }
      return WrittenSelectorDecrease(selector: selector, before: before, after: after)
    }
  }
  func occurrence(_ use: IndexedCallUse, side: SnapshotSide) -> WrittenCallOccurrence {
    let paired = counterpart(use.caller, side: side)
    let state: String
    if let opposite = paired.function {
      state = opposite.declarationTokens == use.caller.declarationTokens ? "paired-token-identical" : "paired-declaration-changed"
    } else { state = paired.reason! }
    return WrittenCallOccurrence(side: side, caller: use.caller.site,
      counterpartCaller: paired.function?.site, correspondence: state, call: use.call)
  }
  func retainedSelector(_ selector: String) -> (before: InventoryFunction?, after: InventoryFunction?, reason: String?) {
    let before = beforeBySelector[selector, default: []], after = afterBySelector[selector, default: []]
    guard before.count == 1, after.count == 1 else { return (nil, nil, "same-selector-declaration-not-unique") }
    guard before[0].correspondenceID == after[0].correspondenceID else { return (nil, nil, "target-correspondence-changed") }
    let retained = stable(after[0])
    guard let old = retained.before else { return (nil, nil, retained.reason) }
    return (old, after[0], nil)
  }
  func stable(_ target: InventoryFunction) -> (before: InventoryFunction?, reason: String?) {
    guard target.bodyTokens != nil else { return (nil, "declaration-without-body") }
    let paired = counterpart(target, side: .after)
    guard let before = paired.function else { return (nil, paired.reason) }
    guard before.declarationTokens == target.declarationTokens else { return (nil, "target-declaration-changed") }
    return (before, nil)
  }
  private func counterpart(_ target: InventoryFunction, side: SnapshotSide) -> (function: InventoryFunction?, reason: String?) {
    let own = side == .before ? beforeByKey : afterByKey
    let opposite = side == .before ? afterByKey : beforeByKey
    let ownInventory = side == .before ? old : new
    let oppositeInventory = side == .before ? new : old
    let matches = opposite[target.correspondenceID, default: []]
    guard own[target.correspondenceID, default: []].count == 1, matches.count == 1,
      ownInventory.hasUnambiguousDeclarationContext(target), oppositeInventory.hasUnambiguousDeclarationContext(matches[0]) else {
      return (nil, "target-correspondence-unknown")
    }
    guard matches[0].lexicalScopeHeaders == target.lexicalScopeHeaders else { return (nil, "target-scope-header-changed") }
    return (matches[0], nil)
  }
}
