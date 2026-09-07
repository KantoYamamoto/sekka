# 既存の型表記を添える表示実験

**変更だけでは既存の構造を見失う場合は、取得済みの共通情報を上限付きで添え、増える負担も測る。**

Issue #31、実装`ab495ff`。判断は[0022](../decisions/0022-retained-context.md)。新解析を追加せず、ReferencePresentationをtext/compactで共有する構成にした。

## 検証

- Swift 52件、CLI/Git 27件、Python 10件成功。境界15件と設計の問い6件は期待終了コードどおり。
- text最大5件、残り件数、共通要素なし、他ルールに出さないこと、compactの同じ上限をテスト。
- 6件すべてで新旧full JSONがバイト一致。compactは新しい文脈項目を除くと新旧同一。観測件数・coverage・noticesを増減させていない。

| 固定入力 | text文字数の変化 | 得られたもの・限界 |
| --- | --- | --- |
| logger-shared | 1572→1665（+93） | 新Analyticsの下に既存Loggerの表記が見える |
| logger-separated | 1584→1677（+93） | 同じ表示。統合と分離のどちらも推奨しない |
| view-growth | 1249→1249 | 追加材料はない。状態所有の判断は未対応 |
| view-owned-part | 1453→1453 | 同上。子Viewが正解とはしない |
| model-io | 1393→1483（+90） | Intの再掲は役立ちにくい。追加の負担として記録 |
| model-calculation | 1499→1499 | 追加材料なし |

入力のパスを固定して比較。文字数はレビュー時間・token数ではない。原データは`.build/design-review/context-comparison.json`。

## 自己利用と通常diff

実装の親→実装を新旧評価器で解析した。自身のtextは2497→2882文字。CompactFindingとReferencePresentationの既存表記が読めたが、Stringや配列等が多数添わり、全行が有用ではなかった。上限5件で1件を詳細へ回した。

通常Swift diff全文と関連実装を読み、共通表記の編集を既存のReferencePresentationへまとめ、compactとtextが同じ選択を使うことを確認した。JSONの文脈は派生情報で、fullの原事実は維持する。テストがトップレベルのため案内がない部分は通常diffで読んだ。raw bundleは`.build/self-review/retained-context`に保持。

## 次の検証

これで役割の重複や設計の正しさが分かったとは言えない。次は未読の実PRで、通常diffのみとSekka併用を独立した担当で比較する。既存の文脈へ到達した具体的な根拠と、余分な出力・誤誘導を記録する。実装者の自己評価をその代用にしない。

Actionsには同じ実行器による設計6件も組み込み、design-review.jsonとして保存する。実PRのActions・コメント確認結果はPR本文へ記録する。
