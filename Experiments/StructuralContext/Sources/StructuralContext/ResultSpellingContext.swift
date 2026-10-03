public struct ResultSpellingEntry: Codable, Sendable {
  public let beforeCaller: SourceSite?
  public let afterCaller: SourceSite
  public let callerEvidence: String
  public let anchorReturn: InventoryTypeName
  public let targetReturn: InventoryTypeName
  public let matchingNominal: SourceSite
  public let anchorCall: InventoryWrittenCall
  public let targetCall: InventoryWrittenCall
  public let eligibleOccurrences: Int
  public let targetOccurrences: Int
}
struct ResultSpellingMatch {
  let before: InventoryFunction
  let after: InventoryFunction
  let entry: ResultSpellingEntry
}
struct ResultSpellingResult {
  var matches: [ResultSpellingMatch] = []
  var skipped: [String: Int] = [:]
}
enum ResultSpellingContext {
  static func find(old: SourceInventory, new: SourceInventory, oldFiles: [String: String], newFiles: [String: String]) -> ResultSpellingResult {
    let search = WrittenCallSearch(old: old, new: new)
    let declarations = Dictionary(grouping: new.declarations, by: \.name)
    let scopesByID = Dictionary(grouping: new.scopes, by: \.id)
    let typesByOwner = Dictionary(grouping: new.types, by: { $0.site.declaration })
    let typesByName = Dictionary(grouping: new.types, by: \.name)
    let scopesByOwner = Dictionary(grouping: new.scopes, by: \.writtenOwner)
    let globalValues = new.scopes.filter { $0.kind == "file" }.flatMap { new.directValueNames[$0.id, default: []] }
    var result = ResultSpellingResult()
    func skip(_ reason: String) { result.skipped["result:" + reason, default: 0] += 1 }
    func references(_ function: InventoryFunction) -> (names: [String: InventoryTypeName], rejected: [String: String]) {
      var names: [String: InventoryTypeName] = [:]
      var rejected: [String: String] = [:]
      let scopes = function.correspondenceScopes.flatMap { scopesByID[$0, default: []] }
      // Only a written owner-name comparison; a conservative exclusion, not extension type resolution.
      let lexicalTypes = scopes.flatMap { scope -> [InventoryType] in
        if scope.kind == "nominal" { return typesByOwner[scope.writtenOwner, default: []] }
        if scope.kind == "extension", scope.writtenOwner.hasPrefix("extension ") {
          return typesByName[String(scope.writtenOwner.dropFirst("extension ".count)), default: []]
        }
        return []
      }
      let bound = Set(function.boundTypeNames + lexicalTypes.flatMap(\.boundTypeNames))
      let extensionScopes = lexicalTypes.flatMap { scopesByOwner["extension " + $0.name, default: []] }
        + scopes.filter { $0.kind == "extension" }.flatMap { scopesByOwner[$0.writtenOwner, default: []] }
      let values = Set(function.localNames + function.parameterNames + globalValues
        + (scopes + extensionScopes).flatMap { new.directValueNames[$0.id, default: []] })
      for reference in function.returnTypeNames {
        if reference.name != reference.written { rejected[reference.name] = "qualified-return-name"; continue }
        if bound.contains(reference.name) { rejected[reference.name] = "bound-return-name"; continue }
        if values.contains(reference.name) { rejected[reference.name] = "value-binding"; continue }
        if names[reference.name] == nil { names[reference.name] = reference }
      }
      return (names, rejected)
    }
    let targetReferences = new.functions.map { (function: $0, names: references($0)) }
    func groups(_ calls: [InventoryWrittenCall]) -> [[InventoryWrittenCall]] {
      Dictionary(grouping: calls, by: { inventoryKey([$0.selector, inventoryKey($0.writtenConditions.map(\.groupingKey))]) })
        .values.sorted { $0[0].site.line == $1[0].site.line ? $0[0].tokens < $1[0].tokens : $0[0].site.line < $1[0].site.line }
    }
    for anchor in search.anchors(oldFiles: oldFiles, newFiles: newFiles) {
      let references = references(anchor.after)
      for group in groups(anchor.eligible.filter { $0.form == .unqualified }) {
        let call = group[0], name = String(call.selector.prefix { $0 != "(" })
        guard let reference = references.names[name] else {
          if let reason = references.rejected[name] { skip(reason) }
          continue
        }
        let candidates = declarations[name, default: []]
        guard candidates.count == 1, candidates[0].kind != "typealias" else { skip(candidates.isEmpty ? "no-indexed-nominal" : "nominal-name-unknown"); continue }
        for (target, targetNames) in targetReferences {
          guard target.correspondenceID != anchor.after.correspondenceID else { continue }
          let targetGroups = groups(target.writtenCalls.filter { $0.form == .unqualified && $0.selector == call.selector })
          guard !targetGroups.isEmpty else { continue }
          guard let targetReference = targetNames.names[name] else {
            if let reason = targetNames.rejected[name] { skip("target:" + reason) }
            continue
          }
          let stable = search.stable(target)
          guard let before = stable.before else { skip(stable.reason!); continue }
          for targetGroup in targetGroups {
            result.matches.append(ResultSpellingMatch(before: before, after: target,
              entry: ResultSpellingEntry(beforeCaller: anchor.before?.site, afterCaller: anchor.after.site,
                callerEvidence: anchor.callerEvidence, anchorReturn: reference, targetReturn: targetReference,
                matchingNominal: candidates[0].site, anchorCall: call, targetCall: targetGroup[0],
                eligibleOccurrences: group.count, targetOccurrences: targetGroup.count)))
          }
        }
      }
    }
    return result
  }
}
