struct WrittenCallAnchor {
  let after: InventoryFunction
  let before: InventoryFunction?
  let eligible: [InventoryWrittenCall]
  var callerEvidence: String { before == nil ? "no-unique-old-indexed-correspondence" : "call-text-absent-from-paired-old-body" }
}

/// Shared syntax correspondence and eligibility; never resolves calls or receiver types.
struct WrittenCallSearch {
  let old: SourceInventory
  let new: SourceInventory
  let beforeByKey: [String: [InventoryFunction]]
  let afterByKey: [String: [InventoryFunction]]
  init(old: SourceInventory, new: SourceInventory) {
    self.old = old; self.new = new
    beforeByKey = Dictionary(grouping: old.functions, by: \.correspondenceID)
    afterByKey = Dictionary(grouping: new.functions, by: \.correspondenceID)
  }
  func anchors(oldFiles: [String: String], newFiles: [String: String]) -> [WrittenCallAnchor] {
    let oldTexts = Dictionary(grouping: old.functions, by: { $0.site.file }).mapValues { Set($0.map(\.declarationTokens)) }
    return new.functions.compactMap { caller in
      guard oldFiles[caller.site.file] != newFiles[caller.site.file],
        !oldTexts[caller.site.file, default: []].contains(caller.declarationTokens) else { return nil }
      let previous = beforeByKey[caller.correspondenceID, default: []]
      let paired = previous.count == 1 && afterByKey[caller.correspondenceID, default: []].count == 1
        && old.hasUnambiguousDeclarationContext(previous[0]) && new.hasUnambiguousDeclarationContext(caller)
        && previous[0].lexicalScopeHeaders == caller.lexicalScopeHeaders
      let oldCalls = paired ? Set(previous[0].writtenCalls.map(\.tokens)) : []
      return WrittenCallAnchor(after: caller, before: paired ? previous[0] : nil,
        eligible: caller.writtenCalls.filter { !paired || !oldCalls.contains($0.tokens) })
    }
  }
  func stable(_ target: InventoryFunction) -> (before: InventoryFunction?, reason: String?) {
    guard target.bodyTokens != nil else { return (nil, "declaration-without-body") }
    let before = beforeByKey[target.correspondenceID, default: []]
    guard before.count == 1, afterByKey[target.correspondenceID, default: []].count == 1,
      old.hasUnambiguousDeclarationContext(before[0]), new.hasUnambiguousDeclarationContext(target) else {
      return (nil, "target-correspondence-unknown")
    }
    guard before[0].lexicalScopeHeaders == target.lexicalScopeHeaders else { return (nil, "target-scope-header-changed") }
    guard before[0].declarationTokens == target.declarationTokens else { return (nil, "target-declaration-changed") }
    return (before[0], nil)
  }
}
