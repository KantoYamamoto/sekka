import Foundation
import CryptoKit

// Swift.String equality normalizes Unicode. Written syntax uses literal UTF-8 keys.
func bytes(_ value: String) -> Data { Data(value.utf8) }
func key<T: Encodable>(_ value: T) -> Data {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
  // Only fixed, finite string/integer/array records are encoded here.
  return try! encoder.encode(value)
}
func digest(_ value: Data) -> String { SHA256.hash(data: value).map { String(format: "%02x", $0) }.joined() }
func precedes(_ a: RegionPosition, _ b: RegionPosition) -> Bool {
  bytes(a.file) == bytes(b.file) ? a.offset < b.offset : bytes(a.file).lexicographicallyPrecedes(bytes(b.file))
}

public struct CallShape: Encodable, Sendable {
  public let form: String
  public let calledExpression: String
  public let selector: String?
  public let trailingClosures: Int
  public let trailingClosureLabels: [String]
  init(_ call: RegionCall) {
    form = call.form; calledExpression = call.calledExpression; selector = call.selector
    trailingClosures = call.trailingClosures; trailingClosureLabels = call.trailingClosureLabels
  }
}
public struct BranchShape: Encodable, Sendable {
  public let label: String
  public let calls: [CallShape]
}
func shape(_ s: RegionSwitch) -> [BranchShape] {
  s.branches.map { BranchShape(label: $0.label, calls: $0.calls.map(CallShape.init)) }
}
public struct RegionReference: Encodable, Sendable {
  public let site: RegionPosition
  public let kind: String
  public let selector: String?
  init(_ r: RegionFact) { site = r.site; kind = r.kind; selector = r.selector }
}
public struct SwitchReference: Encodable, Sendable {
  public let site: RegionPosition
  public let owner: RegionReference
  public let conditions: [[String]]
  init(_ s: RegionSwitch) { site = s.site; owner = RegionReference(s.owner!); conditions = s.conditions }
}
public struct RelationMember: Encodable, Sendable {
  public let ownerState: String = "changed"
  public let before: SwitchReference
  public let after: SwitchReference
}
public struct WrittenUser: Encodable, Sendable {
  public let side: String
  public let site: RegionPosition
  public let selector: String
  public let calledExpression: String
  public let owner: RegionReference
  public let ownerState: String
  public let conditions: [[String]]
}
public struct CommonCall: Encodable, Sendable {
  public let spelling: CallShape
  public let afterSites: [RegionPosition]
  public let sameBasenameDeclarations: [RegionReference]
  public let match: String = "name-only; parameter-binding-and-callee-unresolved"
}
public struct WrittenRelation: Encodable, Sendable {
  public let id: String
  public let meaning: String = "same-written-switch-shape-transition"
  public let argumentSpellingsDiffer: Bool
  public let enclosingConditionsDiffer: Bool
  public let members: [RelationMember]
  public let users: [WrittenUser]
  public let introducedCommonCallSpellings: [CommonCall]
  public let beforeShape: [BranchShape]?
  public let afterShape: [BranchShape]?
}
public struct UnknownSwitch: Encodable, Sendable {
  public let reason: String
  public let before: [RegionPosition]
  public let after: [RegionPosition]
}
public struct InputScope: Encodable, Sendable {
  public let files: Int
  public let switches: Int
  public let sha256: String
}
public struct RelationReport: Encodable, Sendable {
  public let schema: String = "sekka-written-relations/1"
  public let before: InputScope
  public let after: InputScope
  public let transitionCount: Int
  public let relationships: [WrittenRelation]
  public let unknown: [UnknownSwitch]
  public let omittedShapeDetails: Int
  public let limitations: [String] = [
    "Swift files supplied to this directory experiment only; non-Swift files are not analyzed",
    "Exact lexical owner/header, subject and enclosing-condition correspondence; additions, deletions and ambiguity remain unknown",
    "Equal case-label and call spelling transitions are not equivalent behavior, control flow or responsibility",
    "Call arguments, receiver types, callee, active conditions, execution order, macros, purpose and performance remain unresolved",
    "Same-selector users and same-basename declarations are written matches, not resolved dependencies",
    "Zero relationships is not evidence of sound design; ordinary diff and surrounding code remain necessary",
  ]
}

private struct SwitchIdentity: Encodable {
  let owner: [String]
  let expression: String
  let conditions: [[String]]
}
private struct Transition { let before: RegionSwitch; let after: RegionSwitch }
private struct TransitionShape: Encodable { let before: [BranchShape]; let after: [BranchShape] }
private struct CallArguments: Encodable { let arguments: [String]; let trailing: [String] }
private func arguments(_ s: RegionSwitch) -> [[CallArguments]] {
  s.branches.map { $0.calls.map { CallArguments(arguments: $0.argumentTokens, trailing: $0.trailingClosureArguments) } }
}
private func grouped<T>(_ items: [T], _ identity: (T) -> Data) -> [Data: [T]] {
  Dictionary(grouping: items, by: identity)
}
private func inputDigest(_ files: [(String, String)]) -> String {
  // Encode pairs rather than a String-keyed dictionary: distinct Unicode paths stay distinct.
  digest(key(files.sorted { bytes($0.0).lexicographicallyPrecedes(bytes($1.0)) }.map { [$0.0, $0.1] }))
}

public enum ContextRelations {
  public static func compare(before filesBefore: [(String, String)], after filesAfter: [(String, String)],
                             allEvidence: Bool = false) throws -> RelationReport {
    let before = try RegionSnapshot(filesBefore), after = try RegionSnapshot(filesAfter)
    let oldRegions = grouped(before.regions) { key($0.key) }
    let newRegions = grouped(after.regions) { key($0.key) }
    func identity(_ s: RegionSwitch) -> Data {
      guard let owner = s.owner else { return Data() }
      return key(SwitchIdentity(owner: owner.key, expression: s.expression, conditions: s.conditions))
    }
    let oldSwitches = grouped(before.switches, identity), newSwitches = grouped(after.switches, identity)
    var unknown: [UnknownSwitch] = [], transitions: [Transition] = []
    for id in Set(oldSwitches.keys).union(newSwitches.keys).sorted(by: { $0.lexicographicallyPrecedes($1) }) {
      let old = oldSwitches[id] ?? [], new = newSwitches[id] ?? []
      let reason: String?
      if id.isEmpty { reason = "no-executable-owner" }
      else if old.contains(where: { oldRegions[key($0.owner!.key)]?.count != 1 })
           || new.contains(where: { newRegions[key($0.owner!.key)]?.count != 1 }) { reason = "ambiguous-owner" }
      else if old.count != 1 || new.count != 1 { reason = "added-deleted-or-ambiguous-switch" }
      else if old[0].containsConditionalCases || new[0].containsConditionalCases { reason = "conditional-case-list-not-expanded" }
      else { reason = nil }
      if let reason {
        unknown.append(UnknownSwitch(reason: reason, before: old.map(\.site).sorted(by: precedes), after: new.map(\.site).sorted(by: precedes)))
      } else if bytes(old[0].tokens) != bytes(new[0].tokens) {
        transitions.append(Transition(before: old[0], after: new[0]))
      }
    }
    let candidates = transitions.filter { key(shape($0.before)) != key(shape($0.after)) && $0.after.branches.count >= 2 }
    let groups = grouped(candidates) { key(TransitionShape(before: shape($0.before), after: shape($0.after))) }
      .filter { $0.value.count >= 2 }
      .map { (id: $0.key, members: $0.value.sorted { precedes($0.after.site, $1.after.site) }) }
      .sorted { precedes($0.members[0].after.site, $1.members[0].after.site) }
    var relationships: [WrittenRelation] = []
    for (index, group) in groups.enumerated() {
      let members = group.members
      let selectors = Set(members.compactMap { $0.after.owner?.selector }.map(bytes))
      var users: [WrittenUser] = []
      for (side, snapshot) in [("before", before), ("after", after)] {
        for call in snapshot.calls {
          guard let selector = call.selector, selectors.contains(bytes(selector)), let owner = call.owner else { continue }
          let id = key(owner.key), old = oldRegions[id] ?? [], new = newRegions[id] ?? []
          let state: String
          if old.count == 1 && new.count == 1 {
            state = bytes(old[0].tokens!) == bytes(new[0].tokens!) ? "token-identical" : "changed"
          } else { state = "unpaired-or-ambiguous" }
          users.append(WrittenUser(side: side, site: call.site, selector: selector, calledExpression: call.calledExpression,
                                   owner: RegionReference(owner), ownerState: state, conditions: call.conditions))
        }
      }
      // Changed shapes already align case/call spellings. Keep all sites of newly common spellings,
      // and include name-only declaration matches as counter-evidence to a missing abstraction claim.
      let oldCalls = Set(members[0].before.branches.flatMap(\.calls).map { key(CallShape($0)) })
      let newCalls = grouped(members.flatMap { $0.after.branches.flatMap(\.calls) }) { key(CallShape($0)) }
      let common = newCalls.keys.filter { !oldCalls.contains($0) }.sorted { $0.lexicographicallyPrecedes($1) }.map { id in
        let calls = newCalls[id]!, first = calls[0]
        let name = first.selector.map { bytes(String($0.prefix { $0 != "(" })) }
        let declarations = after.regions.filter { r in
          guard let selector = r.selector, let name else { return false }
          return bytes(String(selector.prefix { $0 != "(" })) == name
        }.sorted { precedes($0.site, $1.site) }.map(RegionReference.init)
        return CommonCall(spelling: CallShape(first), afterSites: calls.map(\.site).sorted(by: precedes), sameBasenameDeclarations: declarations)
      }
      relationships.append(WrittenRelation(id: digest(group.id),
        argumentSpellingsDiffer: Set(members.map { key([arguments($0.before), arguments($0.after)]) }).count > 1,
        enclosingConditionsDiffer: Set(members.map { key($0.after.conditions) }).count > 1,
        members: members.map { RelationMember(before: SwitchReference($0.before), after: SwitchReference($0.after)) },
        users: users, introducedCommonCallSpellings: common,
        beforeShape: allEvidence || index < 8 ? shape(members[0].before) : nil,
        afterShape: allEvidence || index < 8 ? shape(members[0].after) : nil))
    }
    return RelationReport(before: InputScope(files: before.fileCount, switches: before.switches.count, sha256: inputDigest(filesBefore)),
      after: InputScope(files: after.fileCount, switches: after.switches.count, sha256: inputDigest(filesAfter)),
      transitionCount: transitions.count, relationships: relationships, unknown: unknown,
      omittedShapeDetails: allEvidence ? 0 : max(0, relationships.count - 8))
  }
}
