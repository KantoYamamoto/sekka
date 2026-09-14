import Foundation

extension ContextReport {
  public func text() -> String {
    func safe(_ value: String) -> String {
      value.unicodeScalars.map { CharacterSet.controlCharacters.contains($0) ? "\\u{\(String($0.value, radix: 16))}" : String($0) }.joined()
    }
    func position(_ site: SourceSite) -> String {
      "\(safe(site.file)):\(site.line) · \(safe(site.declaration))"
    }
    var lines = ["Sekka experiment · 減った参照と残る参照（参照先は未解決）",
      "Swiftファイル \(beforeFileCount) → \(afterFileCount) / 対応内の変更宣言 \(changedDeclarations) / 参照グループ \(contexts.count + omittedContexts)"]
    for context in contexts {
      lines.append("\n┌ \(safe(context.spelling))")
      for (label, changes, omitted) in [("減少", context.reductions, context.omittedReductions), ("残存", context.retained, context.omittedRetained)] {
        for change in changes {
          lines.append("├─ \(label) \(change.before.count) → \(change.after.count)箇所 · 宣言構文\(change.bodyChanged ? "変更あり" : "変更なし")")
          for (side, location) in [("before", change.before), ("after", change.after)] {
            lines.append("│  \(side) \(position(location.declaration))")
            if !location.sites.isEmpty { lines.append("│    参照行: " + location.sites.map { String($0.line) }.joined(separator: ", ")) }
            if location.omittedSites > 0 { lines.append("│    他\(location.omittedSites)箇所省略") }
          }
          if !change.increasedReferences.isEmpty {
            lines.append("│  同じ宣言で増加（置換関係は未判定）: " + change.increasedReferences.map { "\(safe($0.spelling)) \($0.beforeCount)→\($0.afterCount)" }.joined(separator: ", "))
          }
          if change.omittedIncreasedReferences > 0 { lines.append("│  他\(change.omittedIncreasedReferences)表記省略") }
        }
        if omitted > 0 { lines.append("│  \(label)の他\(omitted)宣言省略") }
      }
      lines.append("└")
    }
    if omittedContexts > 0 { lines.append("他\(omittedContexts)参照グループ省略") }
    lines.append("\n対応外 before \(unpairedBefore) / after \(unpairedAfter)宣言（曖昧 \(ambiguousKeys)キーを含む）")
    lines.append("範囲: 関数と型/ファイルのプロパティにある明示参照。条件分岐は未評価。残存は両版の宣言に表記があるという意味で、同一文の維持・移行漏れ・統合必要性は判定しません。0件も設計の妥当性を示しません。")
    return lines.joined(separator: "\n") + "\n"
  }
}
