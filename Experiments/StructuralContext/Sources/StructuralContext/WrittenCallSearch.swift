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
      let previous = counterpart(caller).before
      let oldCalls = Set(previous?.writtenCalls.map(\.tokens) ?? [])
      return WrittenCallAnchor(after: caller, before: previous,
        eligible: caller.writtenCalls.filter { previous == nil || !oldCalls.contains($0.tokens) })
    }
  }
  func stable(_ target: InventoryFunction) -> (before: InventoryFunction?, reason: String?) {
    guard target.bodyTokens != nil else { return (nil, "declaration-without-body") }
    let paired = counterpart(target)
    guard let before = paired.before else { return paired }
    guard before.declarationTokens == target.declarationTokens else { return (nil, "target-declaration-changed") }
    return (before, nil)
  }
  private func counterpart(_ target: InventoryFunction) -> (before: InventoryFunction?, reason: String?) {
    let before = beforeByKey[target.correspondenceID, default: []]
    guard before.count == 1, afterByKey[target.correspondenceID, default: []].count == 1,
      old.hasUnambiguousDeclarationContext(before[0]), new.hasUnambiguousDeclarationContext(target) else {
      return (nil, "target-correspondence-unknown")
    }
    guard before[0].lexicalScopeHeaders == target.lexicalScopeHeaders else { return (nil, "target-scope-header-changed") }
    return (before[0], nil)
  }
}
