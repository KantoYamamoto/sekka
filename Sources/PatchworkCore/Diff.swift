import Foundation

public enum Differ {
  public static func compare(
    _ before: Snapshot, _ after: Snapshot, beforeLabel: String, afterLabel: String
  ) -> DiffReport {
    var findings: [Finding] = []
    let oldTypes = Dictionary(uniqueKeysWithValues: before.types.map { ($0.id, $0) })
    let newTypes = Dictionary(uniqueKeysWithValues: after.types.map { ($0.id, $0) })
    for id in Set(oldTypes.keys).union(newTypes.keys).sorted() {
      let old = oldTypes[id]
      let new = newTypes[id]
      let type = new ?? old!
      func add(
        _ rule: String, _ message: String, _ previous: [String], _ current: [String],
        at: Location? = nil
      ) {
        findings.append(
          Finding(
            rule: rule, type: type.name, location: at ?? type.location, message: message,
            before: previous, after: current))
      }
      guard let old, let new else {
        add(
          old == nil ? "type-added" : "type-removed", "\(type.kind) \(type.name)",
          old.map(summary) ?? [], new.map(summary) ?? [])
        continue
      }
      if old.header != new.header {
        add(
          "type-header-changed",
          "Declaration attributes/modifiers/constraints/inheritance syntax changed", [old.header],
          [new.header])
      }
      let oldRefs = old.referencedTypeSpellings
      let newRefs = new.referencedTypeSpellings
      if oldRefs != newRefs {
        add(
          "type-references-changed",
          "Distinct explicit type expressions: \(oldRefs.count) → \(newRefs.count) (not resolved fan-out)",
          oldRefs, newRefs)
      }
      // Include role/member changes even when the set of type expressions stays the same.
      let oldEdges = Array(Set(old.references.map { "\($0.member) [\($0.role)] → \($0.spelling)" }))
        .sorted()
      let newEdges = Array(Set(new.references.map { "\($0.member) [\($0.role)] → \($0.spelling)" }))
        .sorted()
      if oldRefs == newRefs && oldEdges != newEdges {
        add("reference-sites-changed", "Explicit type reference sites changed", oldEdges, newEdges)
      }
      let oldSignatures = old.members.map(\.signature).sorted()
      let newSignatures = new.members.map(\.signature).sorted()
      if oldSignatures != newSignatures {
        add(
          "members-changed",
          "Declared members: \(old.members.count) → \(new.members.count) (all access levels)",
          oldSignatures, newSignatures)
      }
      // Duplicate/overloaded identities are deliberately not arbitrarily paired.
      let oldMembers = Dictionary(grouping: old.members, by: \.key)
      let newMembers = Dictionary(grouping: new.members, by: \.key)
      for key in newMembers.keys.sorted() {
        guard let group = newMembers[key], group.count == 1, let member = group.first else {
          continue
        }
        let previousGroup = oldMembers[key] ?? []
        guard previousGroup.count <= 1 else { continue }
        let previous = previousGroup.first
        if let call = member.forwardingCall, call != previous?.forwardingCall {
          add(
            "direct-forwarding-shape",
            "\(key): single call passes every parameter unchanged; necessity/effects unknown",
            previous?.forwardingCall.map { [$0] } ?? [], [call], at: member.location)
        }
        if let current = member.body, let prior = previous?.body,
          current.controlFlowSites != prior.controlFlowSites || current.closures != prior.closures
            || current.explicitSelfAssignments != prior.explicitSelfAssignments
        {
          add(
            "body-structure-changed", "\(key): body syntax counts changed", bodySummary(prior),
            bodySummary(current), at: member.location)
        }
      }
    }
    return DiffReport(
      beforeLabel: beforeLabel, afterLabel: afterLabel, beforeFiles: before.files,
      afterFiles: after.files,
      findings: findings,
      notices: before.notices.map {
        Notice(location: $0.location, message: "Before: " + $0.message)
      } + after.notices.map { Notice(location: $0.location, message: "After: " + $0.message) },
      limitations: after.limitations)
  }

  private static func summary(_ type: TypeRecord) -> [String] {
    [type.header] + type.members.map(\.signature).sorted()
      + type.referencedTypeSpellings.map { "type reference: \($0)" }
  }

  private static func bodySummary(_ metrics: BodyMetrics) -> [String] {
    [
      "control-flow sites: \(metrics.controlFlowSites)", "closures: \(metrics.closures)",
      "explicit self.property = sites: \(metrics.explicitSelfAssignments)",
      "tokens: \(metrics.tokens)",
    ]
  }
}

public enum Renderer {
  public static func json<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
  }

  public static func text(_ snapshot: Snapshot) -> String {
    var lines = [
      "Patchwork · syntax-only scan",
      "\(snapshot.files) Swift files · \(snapshot.types.count) type/extension declarations", "",
    ]
    for type in snapshot.types {
      lines += [
        "\(type.location.file):\(type.location.line)  \(type.kind) \(type.name)",
        "  \(type.members.count) members · \(type.referencedTypeSpellings.count) distinct explicit type expressions",
      ]
      lines += type.referencedTypeSpellings.map { "    → \($0)" }
    }
    lines += snapshot.notices.map { "NOTE \($0.location.file):\($0.location.line): \($0.message)" }
    lines += [
      "",
      "Coverage: syntax only; references are not resolved dependencies. No purity or design judgement.",
    ]
    return lines.joined(separator: "\n")
  }

  public static func text(_ report: DiffReport) -> String {
    var lines = [
      "Patchwork · structural delta (syntax-only)", "\(report.beforeLabel) → \(report.afterLabel)",
      "Swift files: \(report.beforeFiles) → \(report.afterFiles) · \(report.findings.count) observations",
      "",
    ]
    for finding in report.findings {
      lines += [
        "\(finding.location.file):\(finding.location.line)  \(finding.type) [\(finding.rule)]",
        "  \(finding.message)",
      ]
      // Multiset subtraction retains repeated declarations without reporting unchanged members.
      var removed = finding.before
      var added: [String] = []
      for item in finding.after {
        if let index = removed.firstIndex(of: item) {
          removed.remove(at: index)
        } else {
          added.append(item)
        }
      }
      lines += removed.map { "  - \($0)" }
      lines += added.map { "  + \($0)" }
      lines.append("")
    }
    if report.findings.isEmpty {
      lines.append("No observations in the supported syntax checks. This is not a design approval.")
    }
    lines += report.notices.map { "NOTE \($0.location.file):\($0.location.line): \($0.message)" }
    lines.append(
      "Coverage: explicit type syntax and selected body counts; unresolved calls, inferred types and effects are unknown."
    )
    return lines.joined(separator: "\n")
  }

  public static func github(_ report: DiffReport) -> String {
    func escape(_ value: String, property: Bool = false) -> String {
      var result = value.replacingOccurrences(of: "%", with: "%25").replacingOccurrences(
        of: "\r", with: "%0D"
      ).replacingOccurrences(of: "\n", with: "%0A")
      if property {
        result = result.replacingOccurrences(of: ":", with: "%3A").replacingOccurrences(
          of: ",", with: "%2C")
      }
      return result
    }
    var lines = report.findings.map {
      // A removed declaration's line belongs to the base, so do not annotate it on HEAD.
      let position =
        $0.rule == "type-removed"
        ? "" : "file=\(escape($0.location.file, property: true)),line=\($0.location.line),"
      let detail =
        $0.message + "\nBefore: " + $0.before.joined(separator: "; ") + "\nAfter: "
        + $0.after.joined(separator: "; ")
      return
        "::notice \(position)title=\(escape("Patchwork / " + $0.rule, property: true))::\(escape($0.type + ": " + detail))"
    }
    lines += report.notices.map {
      "::notice title=Patchwork coverage::\(escape($0.location.file + ": " + $0.message))"
    }
    lines.append(
      "::notice title=Patchwork coverage::Syntax-only analysis; unresolved calls, inferred types and effects are unknown. \(report.findings.count) observations."
    )
    return lines.joined(separator: "\n")
  }
}
