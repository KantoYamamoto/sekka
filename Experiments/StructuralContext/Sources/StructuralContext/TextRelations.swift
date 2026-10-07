import Foundation

private func display(_ value: String) -> String {
  // Quote paths/spellings to keep embedded controls from forging tree structure.
  String(reflecting: value)
}
private func location(_ s: RegionPosition) -> String { "\(display(s.file)):\(s.line)–\(s.endLine)" }
private func written(_ s: CallShape) -> String {
  "\(display(s.calledExpression)) / \(display(s.selector ?? "unresolved")) / trailing \(s.trailingClosures) \(s.trailingClosureLabels.map(display).joined(separator: ", "))"
}
extension RelationReport {
  public func text() -> String {
    var lines = [
      "Written structure relations (experimental)",
      "├─ Swift files: \(before.files) → \(after.files); switches: \(before.switches) → \(after.switches)",
      "├─ Changed paired switches: \(transitionCount); relationships: \(relationships.count)",
      "├─ Unknown correspondence groups: \(unknown.count); omitted shape details: \(omittedShapeDetails)",
      "└─ Syntax only; no resolved callee or design verdict. Zero is not design approval.",
    ]
    if relationships.isEmpty { lines.append("\nNo matching shape-transition relationships. Read ordinary diff.") }
    for (i, relation) in relationships.enumerated() {
      lines += ["\nRelation \(i + 1) [\(relation.id.prefix(12))] — same written switch-shape transition",
                "├─ Argument spellings differ: \(relation.argumentSpellingsDiffer); enclosing conditions differ: \(relation.enclosingConditionsDiffer)"]
      for member in relation.members {
        lines += ["├─ \(member.after.owner.kind) \(display(member.after.owner.selector ?? "")) [owner \(member.ownerState)]",
                  "│  ├─ before switch \(location(member.before.site)); owner \(location(member.before.owner.site))",
                  "│  ├─ after  switch \(location(member.after.site)); owner \(location(member.after.owner.site))",
                  "│  └─ lexical conditions: \(display(member.after.conditions.map { $0.joined(separator: " | ") }.joined(separator: " → "))) (active branches unresolved)"]
      }
      if let old = relation.beforeShape, let new = relation.afterShape {
        for (side, branches) in [("before", old), ("after", new)] {
          lines.append("├─ \(side) written shape")
          for branch in branches {
            lines.append("│  ├─ \(display(branch.label))")
            for call in branch.calls { lines.append("│  │  └─ \(written(call))") }
          }
        }
      } else { lines.append("├─ Shape detail omitted; --all shows it. All locations retained.") }
      lines.append("├─ Same-selector users: \(relation.users.count) (callee unresolved)")
      for user in relation.users {
        lines.append("│  └─ \(user.side) \(location(user.site)); \(display(user.calledExpression)); \(user.owner.kind) \(user.ownerState), owner \(location(user.owner.site))")
      }
      lines.append("└─ Introduced common call spellings: \(relation.introducedCommonCallSpellings.count) (not resolved dependencies)")
      for call in relation.introducedCommonCallSpellings {
        lines.append("   ├─ \(written(call.spelling))")
        for site in call.afterSites { lines.append("   │  ├─ call \(location(site))") }
        for declaration in call.sameBasenameDeclarations {
          lines.append("   │  ├─ name-only declaration \(display(declaration.selector ?? "")) \(location(declaration.site))")
        }
        lines.append("   │  └─ Parameter binding and callee unresolved; a shared implementation may already exist.")
      }
    }
    lines.append("\nUnknown switch correspondence (all locations)")
    for group in unknown {
      lines.append("├─ \(group.reason)")
      for (side, sites) in [("before", group.before), ("after", group.after)] {
        for site in sites { lines.append("│  └─ \(side) \(location(site))") }
      }
    }
    if unknown.isEmpty { lines.append("└─ None in this narrow syntax correspondence") }
    lines.append("\nLimits")
    lines += limitations.map { "├─ " + $0 }
    return lines.joined(separator: "\n") + "\n"
  }
}
