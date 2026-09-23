import Foundation

extension ContextReport {
  public func text() -> String {
    func safe(_ text: String) -> String {
      text.unicodeScalars.map { CharacterSet.controlCharacters.contains($0) ? "\\u{\(String($0.value, radix: 16))}" : String($0) }.joined()
    }
    func position(_ site: SourceSite) -> String { "\(safe(site.file)):\(site.line) · \(safe(site.declaration))" }
    var lines = ["Sekka experiment · 変更から未変更の宣言候補へ（型・呼び出し先は未解決）",
      "Swiftファイル \(beforeFileCount) → \(afterFileCount) / 対応内の変更関数 \(changedFunctions) / 索引内の型注釈差 \(changedTypeAnnotations) / 確認先 \(contexts.count + omittedTargets)"]
    for target in contexts {
      lines.append("\n┌ 未変更の宣言候補 [\(safe(target.kind))]: \(position(target.after))")
      lines.append("│ before \(position(target.before))")
      lines.append("│ \(target.fileUnchanged ? "ファイル全体が未変更" : "ファイルは変更あり・この宣言のトークンは未変更")")
      for evidence in target.entries {
        switch evidence {
        case let .existingCall(entry):
        lines.append("├─ 変更の入口: \(position(entry.afterCaller))")
        lines.append("│  既存call行 before \(entry.beforeExistingCall.line) → after \(entry.afterExistingCall.line) / 直後のcall（旧版に同じ文なし）行 \(entry.newOrChangedCall.line)")
        lines.append("│  receiverの明示型: \(safe(entry.writtenType)) · \(position(entry.afterReceiver))")
        lines.append("│  共通する引数表記: " + entry.sharedArgumentSpellings.map(safe).joined(separator: ", "))
        case let .changedType(entry):
          lines.append("├─ 型注釈の入口: \(position(entry.afterProperty))")
          lines.append("│  before \(entry.beforeProperty.map(position) ?? "旧版索引に対応なし") · \(safe(entry.beforeType ?? (entry.beforeProperty == nil ? "旧版の型は未確認" : "型注釈なし")))")
          lines.append("│  after  \(safe(entry.afterType))")
          lines.append("│  新しく現れた表記: \(safe(entry.reference.written)) · \(position(entry.reference.site))")
          lines.append("│  照合した末尾名: \(safe(entry.reference.name)) · 読み取った同名宣言 \(entry.matchingDeclarations)件（型の解決ではない）")
        }
      }
      if target.omittedEntries > 0 { lines.append("│  他\(target.omittedEntries)入口省略") }
      lines.append("└")
    }
    if omittedTargets > 0 { lines.append("他\(omittedTargets)確認先省略") }
    lines.append("\n対応外 before \(unpairedBefore) / after \(unpairedAfter)関数")
    for item in skipped { lines.append("  検索対象外 \(safe(item.reason)): \(item.count)件") }
    lines.append("範囲: member関数直下のcall接点、またはproperty型注釈の新しい名前から宣言を検索。責務の一致や統合必要性は判定しません。未変更はその宣言のトークンだけで、extension・alias展開・macro・有効な条件分岐を含む型全体の保証ではありません。diffのcontext行に出る場合もあり、0件も設計の妥当性を示しません。")
    return lines.joined(separator: "\n") + "\n"
  }
}
