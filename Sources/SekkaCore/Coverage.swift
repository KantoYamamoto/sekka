import Foundation

func sameTokens(_ before: [String]?, _ after: [String]?) -> Bool {
  guard let before, let after else { return before == nil && after == nil }
  // Swift String equality normalizes Unicode. Here we need exact token spelling.
  return before.count == after.count
    && zip(before, after).allSatisfy { $0.utf8.elementsEqual($1.utf8) }
}

func changedElements(_ before: [String], _ after: [String]) -> (removed: [String], added: [String])
{
  var removed = before
  var added: [String] = []
  for item in after {
    if let index = removed.firstIndex(of: item) {
      removed.remove(at: index)
    } else {
      added.append(item)
    }
  }
  return (removed, added)
}

enum MemberMatching {
  /// Only used to summarize declarations, never to claim body equivalence.
  /// A name must be unique on both sides. Other signature changes remain explicit in the summary.
  static func parameterPairs(_ before: TypeRecord, _ after: TypeRecord) -> [(Member, Member)] {
    let old = Dictionary(
      grouping: before.members.filter { $0.callableName != nil }, by: { $0.callableName! })
    let new = Dictionary(
      grouping: after.members.filter { $0.callableName != nil }, by: { $0.callableName! })
    return old.keys.sorted().compactMap { name in
      guard let a = old[name], a.count == 1, let b = new[name], b.count == 1,
        a[0].parameters != b[0].parameters
      else { return nil }
      return (a[0], b[0])
    }
  }

  static func parameterChanges(_ before: TypeRecord, _ after: TypeRecord) -> [ParameterChange] {
    parameterPairs(before, after).map { a, b in
      let delta = changedElements(a.parameters ?? [], b.parameters ?? [])
      return ParameterChange(
        member: b.callableName!, beforeSignature: a.signature,
        afterSignature: b.signature,
        beforeHeader: a.signatureWithoutParameters!, afterHeader: b.signatureWithoutParameters!,
        removed: delta.removed, added: delta.added,
        beforeOrder: a.parameters ?? [], afterOrder: b.parameters ?? [])
    }
  }
}

enum CoverageBuilder {
  static func build(_ before: Snapshot, _ after: Snapshot, findings: [Finding])
    -> ComparisonCoverage
  {
    var result = ComparisonCoverage()
    let findingCounts = Dictionary(grouping: findings, by: { $0.location.file }).mapValues(\.count)
    let paths = Set(before.sourceByPath.keys).union(after.sourceByPath.keys).sorted()
    for path in paths {
      let a = before.sourceByPath[path]
      let b = after.sourceByPath[path]
      if let a, let b, a.utf8.elementsEqual(b.utf8) { continue }
      result.changedFiles.append(
        ChangedFile(
          file: path,
          change: a == nil ? "added" : b == nil ? "deleted" : "modified",
          syntaxChanged: !sameTokens(before.tokensByPath[path], after.tokensByPath[path]),
          observationCount: findingCounts[path, default: 0]))
    }
    let changedPaths = Set(result.changedFiles.map(\.file))
    let oldTypes = Dictionary(uniqueKeysWithValues: before.types.map { ($0.id, $0) })
    let newTypes = Dictionary(uniqueKeysWithValues: after.types.map { ($0.id, $0) })
    func family(_ type: TypeRecord) -> String { "\(type.location.file)::\(type.kind):\(type.name)" }
    let oldFamilies = Dictionary(grouping: before.types, by: family)
    let newFamilies = Dictionary(grouping: after.types, by: family)
    for id in Set(oldTypes.keys).union(newTypes.keys).sorted() {
      let old = oldTypes[id]
      let new = newTypes[id]
      let type = new ?? old!
      guard changedPaths.contains(type.location.file) else { continue }
      func record(_ a: Member?, _ b: Member?, status: String, reason: String, name: String? = nil) {
        result.bodyComparisons.append(
          BodyComparison(
            typeID: id, type: type.name,
            member: name ?? b?.key ?? a!.key, beforeLocation: a?.location,
            afterLocation: b?.location,
            status: status, reason: reason))
      }
      let ambiguousType =
        oldFamilies[family(type), default: []].count > 1
        || newFamilies[family(type), default: []].count > 1
      guard let old, let new, !ambiguousType else {
        let reason =
          ambiguousType ? "ambiguous-type-identity" : old == nil ? "type-added" : "type-removed"
        for member in old?.members ?? [] where member.body != nil {
          record(member, nil, status: "not-compared", reason: reason)
        }
        for member in new?.members ?? [] where member.body != nil {
          record(nil, member, status: "not-compared", reason: reason)
        }
        continue
      }
      var consumedOld: Set<String> = []
      var consumedNew: Set<String> = []
      for (a, b) in MemberMatching.parameterPairs(old, new) where a.body != nil || b.body != nil {
        record(
          a, b, status: "not-compared", reason: "parameter-clause-changed",
          name: b.callableName! + " (parameters changed)")
        consumedOld.insert(a.key)
        consumedNew.insert(b.key)
      }
      let oldMembers = Dictionary(
        grouping: old.members.filter { !consumedOld.contains($0.key) }, by: \.key)
      let newMembers = Dictionary(
        grouping: new.members.filter { !consumedNew.contains($0.key) }, by: \.key)
      for key in Set(oldMembers.keys).union(newMembers.keys).sorted() {
        let a = oldMembers[key] ?? []
        let b = newMembers[key] ?? []
        if a.count == 1, b.count == 1 {
          let previous = a[0]
          let current = b[0]
          if previous.body != nil && current.body != nil {
            result.comparedBodyCount += 1
            if sameTokens(previous.bodyTokens, current.bodyTokens) {
              result.unchangedBodyCount += 1
            } else {
              let x = previous.body!
              let y = current.body!
              let metricsChanged =
                x.controlFlowSites != y.controlFlowSites || x.closures != y.closures
                || x.explicitSelfAssignments != y.explicitSelfAssignments
              record(
                previous, current,
                status: metricsChanged ? "changed-metrics" : "changed-syntax-only",
                reason: metricsChanged ? "tracked-counts-changed" : "tracked-counts-unchanged")
            }
          } else if previous.body != nil || current.body != nil {
            record(
              previous, current, status: "not-compared",
              reason: previous.body == nil ? "body-added" : "body-removed")
          }
        } else {
          let reason =
            a.count > 1 || b.count > 1 ? "ambiguous-member-identity" : "no-exact-member-match"
          for member in a where member.body != nil {
            record(member, nil, status: "not-compared", reason: reason)
          }
          for member in b where member.body != nil {
            record(nil, member, status: "not-compared", reason: reason)
          }
        }
      }
    }
    result.skippedBodyCount = result.bodyComparisons.filter { $0.status == "not-compared" }.count
    return result
  }
}
