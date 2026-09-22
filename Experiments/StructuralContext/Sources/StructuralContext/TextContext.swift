import Foundation

extension ContextReport {
  public func text() -> String {
    func safe(_ text: String) -> String {
      text.unicodeScalars.map { CharacterSet.controlCharacters.contains($0) ? "\\u{\(String($0.value, radix: 16))}" : String($0) }.joined()
    }
    func position(_ site: SourceSite) -> String { "\(safe(site.file)):\(site.line) · \(safe(site.declaration))" }
    var lines = ["Sekka experiment · 変更から未変更の実装候補へ（呼び出し先は未解決）",
      "Swiftファイル \(beforeFileCount) → \(afterFileCount) / 対応内の変更関数 \(changedFunctions) / 確認先 \(contexts.count + omittedTargets)"]
    for target in contexts {
      lines.append("\n┌ 未変更の関数候補: \(position(target.after))")
      lines.append("│ before \(position(target.before))")
      lines.append("│ \(target.fileUnchanged ? "ファイル全体が未変更" : "ファイルは変更あり・この宣言のトークンは未変更")")
      for entry in target.entries {
        lines.append("├─ 変更の入口: \(position(entry.afterCaller))")
        lines.append("│  既存call行 before \(entry.beforeExistingCall.line) → after \(entry.afterExistingCall.line) / 直後のcall（旧版に同じ文なし）行 \(entry.newOrChangedCall.line)")
        lines.append("│  receiverの明示型: \(safe(entry.writtenType)) · \(position(entry.afterReceiver))")
        lines.append("│  共通する引数表記: " + entry.sharedArgumentSpellings.map(safe).joined(separator: ", "))
      }
      if target.omittedEntries > 0 { lines.append("│  他\(target.omittedEntries)入口省略") }
      lines.append("└")
    }
    if omittedTargets > 0 { lines.append("他\(omittedTargets)確認先省略") }
    lines.append("\n対応外 before \(unpairedBefore) / after \(unpairedAfter)関数")
    for item in skipped { lines.append("  検索対象外 \(safe(item.reason)): \(item.count)件") }
    lines.append("範囲: member関数の直下のcall文・単純な識別子引数・明示型。位置と構文の接点を示すだけで、責務の一致や統合必要性は判定しません。未変更宣言がdiffのcontext行に出る可能性もあります。0件も設計の妥当性を示しません。")
    return lines.joined(separator: "\n") + "\n"
  }
}
