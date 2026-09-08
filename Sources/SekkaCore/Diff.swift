import Foundation

public enum Differ {
  public static func compare(
    _ before: Snapshot, _ after: Snapshot, beforeLabel: String, afterLabel: String
  ) -> DiffReport {
    var findings: [Finding] = []
    let oldTypes = Dictionary(uniqueKeysWithValues: before.types.map { ($0.id, $0) })
    let newTypes = Dictionary(uniqueKeysWithValues: after.types.map { ($0.id, $0) })
    func family(_ type: TypeRecord) -> String { "\(type.location.file)::\(type.kind):\(type.name)" }
    let oldFamilies = Dictionary(grouping: before.types, by: family)
    let newFamilies = Dictionary(grouping: after.types, by: family)
    for id in Set(oldTypes.keys).union(newTypes.keys).sorted() {
      let old = oldTypes[id]
      let new = newTypes[id]
      let type = new ?? old!
      let ambiguousType =
        oldFamilies[family(type), default: []].count > 1
        || newFamilies[family(type), default: []].count > 1
      // Occurrence IDs distinguish snapshot records, not identities across revisions.
      // A wholly added/removed family is still known to be one-sided.
      if ambiguousType,
        !oldFamilies[family(type), default: []].isEmpty,
        !newFamilies[family(type), default: []].isEmpty
      {
        continue
      }
      func add(
        _ rule: String, _ message: String, _ previous: [String], _ current: [String],
        at: Location? = nil, parameterChanges: [ParameterChange] = []
      ) {
        findings.append(
          Finding(
            rule: rule, type: type.name, location: at ?? type.location, message: message,
            before: previous, after: current, typeID: id, parameterChanges: parameterChanges))
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
        findings[findings.count - 1].textReferenceLines = ReferencePresentation.lines(
          before: old.references, after: new.references)
      }
      let oldSignatures = old.members.map(\.signature).sorted()
      let newSignatures = new.members.map(\.signature).sorted()
      if oldSignatures != newSignatures {
        add(
          "members-changed",
          "Declared members: \(old.members.count) → \(new.members.count) (all access levels)",
          oldSignatures, newSignatures,
          parameterChanges: ambiguousType ? [] : MemberMatching.parameterChanges(old, new))
      }
      // Duplicate/overloaded identities are deliberately not arbitrarily paired.
      if ambiguousType { continue }
      let oldMembers = Dictionary(grouping: old.members, by: \.key)
      let newMembers = Dictionary(grouping: new.members, by: \.key)
      for key in newMembers.keys.sorted() {
        guard let group = newMembers[key], group.count == 1, let member = group.first else {
          continue
        }
        let previousGroup = oldMembers[key] ?? []
        guard previousGroup.count <= 1 else { continue }
        let previous = previousGroup.first
        if let previous, member.kind == "property",
          !sameTokens(previous.initializerTokens, member.initializerTokens)
        {
          let change =
            previous.initializerTokens == nil
            ? "added"
            : member.initializerTokens == nil ? "removed" : "changed"
          add(
            "property-initializer-changed",
            "\(key): initializer syntax \(change); behavior/effects unknown",
            [], [], at: member.location)
        }
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
    var report = DiffReport(
      beforeLabel: beforeLabel, afterLabel: afterLabel, beforeFiles: before.files,
      afterFiles: after.files,
      findings: findings,
      notices: before.notices.map {
        Notice(location: $0.location, message: "Before: " + $0.message)
      } + after.notices.map { Notice(location: $0.location, message: "After: " + $0.message) },
      limitations: after.limitations,
      coverage: CoverageBuilder.build(before, after, findings: findings))
    report.textNotices = NoticePresentation.lines(before: before.notices, after: after.notices)
    return report
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
      "Sekka · syntax-only scan",
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
    let coverage = report.coverage
    let without = coverage.changedFiles.filter { $0.observationCount == 0 }
    var lines = [
      "Sekka · structural delta (syntax-only)",
      "\(report.beforeLabel) → \(report.afterLabel)",
    ] + ReviewEntry.textLines(report) + [
      "Analyzed Swift files: \(report.beforeFiles) → \(report.afterFiles)",
      "Changed Swift files: \(coverage.changedFiles.count) · with observations: \(coverage.changedFiles.count - without.count) · without observations: \(without.count)",
      "\(report.findings.count) observations. These counts are not a coverage percentage.", "",
    ]
    lines += [
      "Bodies in changed files: \(coverage.comparedBodyCount) compared · \(coverage.unchangedBodyCount) token-identical · \(coverage.skippedBodyCount) not compared",
      "Body comparison checks tokens/counts, not behavior. Unchanged bodies are omitted below.",
    ]
    if coverage.bodyComparisons.contains(where: { $0.status == "changed-syntax-only" }) {
      lines.append("changed-syntax-only: body tokens changed; tracked structural counts did not.")
    }
    lines.append("")
    let findings = Dictionary(grouping: report.findings, by: \.typeID)
    let bodies = Dictionary(grouping: coverage.bodyComparisons, by: \.typeID)
    for id in Set(findings.keys).union(bodies.keys).sorted() {
      let observations = findings[id] ?? []
      let comparisons = bodies[id] ?? []
      let name = observations.first?.type ?? comparisons.first!.type
      let location =
        observations.first?.location ?? comparisons.first!.afterLocation ?? comparisons.first!
        .beforeLocation!
      lines.append("\(location.file):\(location.line)  \(name)")
      for finding in observations {
        let position =
          (finding.rule == "body-structure-changed"
            || finding.rule == "property-initializer-changed")
          ? " (after:\(finding.location.line))" : ""
        lines.append("  [\(finding.rule)] \(finding.message)\(position)")
        let delta = displayDelta(finding)
        if let referenceLines = finding.textReferenceLines {
          lines += referenceLines
        } else {
          lines += delta.removed.map { "    - \($0)" }
          lines += delta.added.map { "    + \($0)" }
        }
        lines += ReferencePresentation.contextLines(finding)
        for change in finding.parameterChanges {
          lines.append("    \(change.member) — parameters (unique same-name declaration):")
          lines += change.removed.map { "      - \($0)" }
          lines += change.added.map { "      + \($0)" }
          if change.beforeHeader != change.afterHeader {
            lines += [
              "      declaration before: " + change.beforeHeader,
              "      declaration after: " + change.afterHeader,
            ]
          }
          if parameterOrderChanged(change) {
            lines += [
              "      order before: " + change.beforeOrder.joined(separator: ", "),
              "      order after: " + change.afterOrder.joined(separator: ", "),
            ]
          }
        }
      }
      let bodyPresentation = BodyPresentation(comparisons, findings: observations)
      lines += bodyPresentation.summaries.map { "  [not-compared] " + $0 }
      for body in bodyPresentation.individual {
        let at =
          body.afterLocation.map { "after:\($0.line)" } ?? "before:\(body.beforeLocation!.line)"
        lines.append("  [\(body.status)] \(body.member) (\(at))")
        if body.status != "changed-syntax-only" {
          lines.append("    " + coverageExplanation(body.reason))
        }
      }
      lines.append("")
    }
    if report.findings.isEmpty {
      lines.append(
        "No structural observations in supported checks. Changed files/bodies above still require review."
      )
    }
    lines +=
      report.textNotices
      ?? report.notices.map { "NOTE \($0.location.file):\($0.location.line): \($0.message)" }
    lines.append(
      "Scope: selected declarations/accessor/function bodies only. Unresolved calls, inferred types, unsupported syntax and effects remain unknown."
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
      let delta = displayDelta($0)
      let parameters = $0.parameterChanges.map {
        $0.member + " parameters: - " + $0.removed.joined(separator: ", ") + " / + "
          + $0.added.joined(separator: ", ")
          + (parameterOrderChanged($0)
            ? " / order: " + $0.beforeOrder.joined(separator: ", ") + " → "
              + $0.afterOrder.joined(separator: ", ") : "")
          + ($0.beforeHeader == $0.afterHeader
            ? "" : " / declaration: " + $0.beforeHeader + " → " + $0.afterHeader)
      }.joined(separator: "\n")
      let detail =
        $0.message + "\nRemoved: " + delta.removed.joined(separator: "; ")
        + "\nAdded: " + delta.added.joined(separator: "; ") + "\n" + parameters
      return
        "::notice \(position)title=\(escape("Sekka / " + $0.rule, property: true))::\(escape($0.type + ": " + detail))"
    }
    if let inventory = report.inventory {
      lines.append("::notice title=Sekka comparison scope::" + escape(inventory.textLines.joined(separator: "\n")))
    }
    for file in report.coverage.changedFiles where file.observationCount == 0 {
      lines.append(
        "::notice title=Sekka coverage::"
          + escape(
            file.file + ": changed without structural observations; review the ordinary diff."))
    }
    for body in report.coverage.bodyComparisons where body.status != "changed-metrics" {
      let position =
        body.afterLocation.map { "file=\(escape($0.file, property: true)),line=\($0.line)," } ?? ""
      let detail = body.type + "." + body.member + ": " + coverageExplanation(body.reason)
      lines.append("::notice \(position)title=Sekka body coverage::\(escape(detail))")
    }
    lines += report.notices.map {
      "::notice title=Sekka coverage::\(escape($0.location.file + ": " + $0.message))"
    }
    lines.append(
      "::notice title=Sekka coverage::Syntax-only analysis; unresolved calls, inferred types and effects are unknown. \(report.findings.count) observations; \(report.coverage.changedFiles.count) changed Swift files; \(report.coverage.skippedBodyCount) body comparisons skipped."
    )
    return lines.joined(separator: "\n")
  }
}
