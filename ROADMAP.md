# Sekka: 現在位置と次の作業

更新日: 2026-09-07。現在の計画の正本。変更理由は[0021](docs/decisions/0021-whole-project.md)、以前の計画と完了履歴は[見直し前のROADMAP](https://github.com/KantoYamamoto/sekka/blob/fca2987/ROADMAP.md)で追えます。

## 目的と現在位置

**Swiftの変更を、既存の構造へどう組み込むかを考える入口を作る。** 短い出力や速いdiff移動は、そのための手段です。開発側も、局所の変更とプロジェクト全体の目的・優先順位の両方を見直します。

構文差分・型別要約・引数差分・本体比較状態・diffへの案内・自身のCI/PRコメントは実装済みです。初期値変更の盲点修正も[PR #27](https://github.com/KantoYamamoto/sekka/pull/27)で完了しました。一方、既存の役割分担を見直す助けになるか、通常diffのみよりレビューの手間や見落としが減るかは未確立です。

**次は[Issue #31](https://github.com/KantoYamamoto/sekka/issues/31)：変更した型表記に、同じままの明示型表記を併記する小さな表示実験。** #29の6ケースで、短い案内から既存Loggerが消えることを確認した。新ルールより既存情報の再編集を先に試す。独立比較の入力不足を理由に無関係な機能追加へは進まない。

## マイルストーンと判断の節目

| 段階 | 完了条件 | 現在の状態 |
| --- | --- | --- |
| M0・M1: 観測と読みやすさの土台 | 構文事実・限界・重複整理・diff到達が再現可能 | 完了。[M1検証](docs/validation/m1-output.md) |
| R1: 目的と現状をつなぎ直す | 文書・計画を統合し、元の問いと観測・不足文脈を対応付ける | 完了。#28の再構成と[#29の6ケース検証](docs/validation/structural-questions.md) |
| R2: 小さな改善か見送りを選ぶ | 現状出力・再編集・追加観測を比較し、対照例込みで一つ選ぶ | #29で再編集を選択。#31の小さな表示実験へ |
| M2: 実レビューで利益を比較する | 確定した問いについて通常diffのみとの差と限界を記録 | #8〜#12はR1/R2による課題の再定義まで保留 |
| M3: 外部導入を整える | 有益だった用途を別環境でも再現できる | M2と用途判断の後。public/MIT・自身のCI完了とは別 |

## 1PR・1検証単位のタスク

| 作業 | 成果物・完了条件 | 状態・再開条件 |
| --- | --- | --- |
| [#28](https://github.com/KantoYamamoto/sekka/issues/28) 文書と開発方針の統合 | README/仕様/開発手順/ROADMAPの役割が明確。旧説明・重複・Issueの順序を整理 | 完了・[PR #30](https://github.com/KantoYamamoto/sekka/pull/30) |
| [#29](https://github.com/KantoYamamoto/sekka/issues/29) 元の問いとの接続を検証 | 3場面と妥当な対照例を固定し、問い→観測→不足文脈を記録。次の一手か見送りを選ぶ | 完了・[記録](docs/validation/structural-questions.md)。独立比較ではない |
| [#31](https://github.com/KantoYamamoto/sekka/issues/31) 既存表記を添える | Loggerの手掛かりと無関係なIntのノイズ、表示上限・JSON整合を確認 | 着手可能。依存解決や設計の判断は追加しない |
| [#8](https://github.com/KantoYamamoto/sekka/issues/8) API・モデル比較 | 役割/APIの拡大について理由付き確認先を選べるか | #29後に課題を更新し、未読入力・比較条件を確保 |
| [#9](https://github.com/KantoYamamoto/sekka/issues/9) SwiftUI比較 | 状態・表示の配置を考える入口になるか | 同上 |
| [#10](https://github.com/KantoYamamoto/sekka/issues/10) 追加削除・分割比較 | 新しい窓口や分割と既存の配置を照らせるか | 同上 |
| [#11](https://github.com/KantoYamamoto/sekka/issues/11) 小さい変更の比較 | 読む負担が利益を上回らないか | 同上。小変更を無理に重要視しない |
| [#12](https://github.com/KantoYamamoto/sekka/issues/12) 投資判断 | 継続・用途限定・方向修正と次の一手を根拠付きで記録 | #8〜#11の課題再定義と実測後 |
| [#18](https://github.com/KantoYamamoto/sekka/issues/18) トップレベルの個別案内 | 現行の具体的な不足として保持 | 保留。#29または実比較で目的への寄与が確認されたら検討 |

## 完了済みの根拠

- [Git読み取り改善](docs/validation/git-batch.md)：同じ出力で実行時間を削減。
- [自己利用CI](docs/validation/pr-actions.md)・[PRコメント](docs/validation/pr-comments.md)：投稿・更新・罫線・diffリンクを確認。
- [予備試行](docs/validation/review-pilots.md)・[15境界ケースと実変更](docs/validation/coverage-boundaries.md)：観測と不足を確認。独立比較には数えない。
- [初期化式](docs/validation/property-initializers.md)：49 Swiftテスト、27 CLI/Gitチェック、15probe。通常diffと自己利用も実施。

## 作業を選び直す基準

利用場面と助けたい検討、既存機能へ組み込む方法、読む負担・誤誘導、後回しにする仕事を明示します。新しい要求は既存計画と統合し、不要なIssueは理由付きで閉じます。保留は未達のまま保持し、検証結果が不利でも有効な結果として扱います。

自己レビューは実装者による検査です。独立比較には未読の入力と比較条件が必要で、同じPRの再読を速度改善の証拠にはしません。検証手順は[protocol](docs/validation/protocol.md)、日々の進め方は[development](docs/development.md)を参照してください。
