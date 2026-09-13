import Foundation

extension ContextReport {
  public func text() -> String {
    func safe(_ value: String) -> String {
      value.unicodeScalars.map { CharacterSet.controlCharacters.contains($0) ? "\\u{\(String($0.value, radix: 16))}" : String($0) }.joined()
    }
    func position(_ site: SourceSite) -> String { "\(safe(site.file)):\(site.line) · \(safe(site.declaration))\(site.signature.map { " [" + safe($0) + "]" } ?? "")" }
    var lines = ["Sekka experiment · 変更と既存実装の接点（呼び出し先は未解決）",
      "Swiftファイル \(beforeFileCount) → \(afterFileCount) / 変更宣言 \(changedDeclarations) / 材料あり \(contexts.count)", ""]
    for context in contexts {
      lines.append("┌ after \(position(context.after))")
      for previous in context.before { lines.append("│ before \(position(previous))") }
      for neighbor in context.sharedCalls {
        lines.append("├─ 変更後の基準宣言と共通する表記（隣接候補の前後で比較）")
        for (side, overlaps) in [("before", [neighbor.before]), ("after", neighbor.after)] {
          if overlaps.isEmpty { lines.append("│  \(side) 同じ宣言キーの候補なし") }
          for overlap in overlaps {
            lines.append("│  \(side) \(position(overlap.site))")
            lines.append("│    " + (overlap.spellings.isEmpty ? "共通表記なし" : overlap.spellings.prefix(8).map(safe).joined(separator: ", ")))
            if overlap.spellings.count > 8 { lines.append("│    表記の残り \(overlap.spellings.count - 8)件はJSON") }
          }
        }
      }
      if context.omittedNeighbors > 0 { lines.append("│  他の一致宣言 \(context.omittedNeighbors)件は省略") }
      if let selector = context.sameSelector { lines.append("├─ 表記グループ: \(safe(selector))（使用位置は下段に集約）") }
      lines.append("└")
    }
    for group in selectorGroups {
      lines.append("")
      lines.append("┌ 同じ名前・引数ラベル: \(safe(group.selector))")
      lines.append("│ afterの宣言候補 \(group.declarationCandidates.count + group.omittedDeclarationCandidates)件 / 使用位置 before \(group.before.count + group.omittedBefore) → after \(group.after.count + group.omittedAfter)件")
      for site in group.declarationCandidates { lines.append("│ 宣言 \(position(site))") }
      if group.omittedDeclarationCandidates > 0 { lines.append("│ 宣言候補の残り \(group.omittedDeclarationCandidates)件は省略") }
      for (side, uses, omitted) in [("before", group.before, group.omittedBefore), ("after", group.after, group.omittedAfter)] {
        for use in uses { lines.append("│ \(side) \(position(use.site)) · \(safe(use.expression))") }
        if omitted > 0 { lines.append("│ \(side)の使用位置 \(omitted)件は省略") }
      }
      lines.append("└")
    }
    lines.append("")
    lines.append("材料なし \(withoutContext.count + omittedWithoutContext)宣言 / 対応が曖昧 \(ambiguous.count)宣言")
    for site in withoutContext { lines.append("  材料なし \(position(site))") }
    if omittedWithoutContext > 0 { lines.append("  材料なしの残り \(omittedWithoutContext)件は省略") }
    for site in ambiguous { lines.append("  対応が曖昧 \(position(site))") }
    lines.append("範囲: 入力内の関数・型/ファイルのプロパティ。条件分岐は未評価。外部宣言・macro展開・既定引数等は未解決。同名候補が1件でも呼び出し先は未解決。0件も設計の妥当性を示しません。")
    return lines.joined(separator: "\n") + "\n"
  }
}
