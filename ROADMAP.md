# Sekka: 現在位置と次の作業

更新日: 2026-09-08。現在の計画の正本。変更理由は[0021](docs/decisions/0021-whole-project.md)・[0023](docs/decisions/0023-review-entry.md)、以前の計画と完了履歴は[見直し前のROADMAP](https://github.com/KantoYamamoto/sekka/blob/fca2987/ROADMAP.md)で追えます。

## 目的と現在位置

**Swiftの変更を、既存の構造へどう組み込むかを考える入口を作る。** 短い出力や速いdiff移動は、そのための手段です。開発側も、局所の変更とプロジェクト全体の目的・優先順位の両方を見直します。

構文差分・型別要約・引数差分・本体比較状態・diffへの案内・自身のCI/PRコメントは実装済みです。初期値変更の盲点修正も[PR #27](https://github.com/KantoYamamoto/sekka/pull/27)で完了しました。一方、既存の役割分担を見直す助けになるか、通常diffのみよりレビューの手間や見落としが減るかは未確立です。

**全変更一覧（#34）とGit実行境界（#45）は完了。現在は#35で確認先の一覧と型別詳細を統合している。次は#36の初期値・新規宣言の案内再現と#38の再掲ノイズ比較。** [試用報告](docs/validation/bloom-feedback.md)に基づき、解析項目追加より入口を整える。全変更一覧は[PR #44の実コメント](https://github.com/KantoYamamoto/sekka/pull/44#issuecomment-5578916364)まで確認済み。

[#8の独立A/B比較](docs/validation/v03-01-results.md)は実施済み。両担当はほぼ同じ確認先に到達し、Sekka固有の利益は確認できなかった。中断・検索失敗があるため速度比較は判定不能。#41は[修正・固定入力検証済み](docs/validation/ambiguous-structure.md)。#35/#38で読む負担を整理してから未読入力で次の比較を選ぶ。Mermaid生成は保留。[Sekka自身の試用報告](docs/validation/sekka-pr-feedback.md)も統合し、当面は大きなSwift PRへのopt-in CLI/artifactを利用仮説とする。全PRの常設botは推奨しない。

## マイルストーンと判断の節目

| 段階 | 完了条件 | 現在の状態 |
| --- | --- | --- |
| M0・M1: 観測と読みやすさの土台 | 構文事実・限界・重複整理・diff到達が再現可能 | 完了。[M1検証](docs/validation/m1-output.md) |
| R1: 目的と現状をつなぎ直す | 文書・計画を統合し、元の問いと観測・不足文脈を対応付ける | 完了。#28の再構成と[#29の6ケース検証](docs/validation/structural-questions.md) |
| R2: 小さな改善か見送りを選ぶ | 現状出力・再編集・追加観測を比較し、対照例込みで一つ選ぶ | #31で既存情報を再編集。材料と増える負担を検証 |
| R3: 比較範囲と確認先を統合する | 対象外を隠さず、未比較箇所へ重複せず到達できる | #34→#35。#36/#38は1検証から実装を選ぶ |
| M2: 実レビューで利益を比較する | 確定した問いについて通常diffのみとの差と限界を記録 | #8の初回結果を記録。利益未確認・速度判定不能。修正後に次の条件を選ぶ |
| M3: 外部導入を整える | 有益だった用途を別環境でも再現できる | M2と用途判断の後。public/MIT・自身のCI完了とは別 |

## 1PR・1検証単位のタスク

| 作業 | 成果物・完了条件 | 状態・再開条件 |
| --- | --- | --- |
| [#28](https://github.com/KantoYamamoto/sekka/issues/28) 文書と開発方針の統合 | README/仕様/開発手順/ROADMAPの役割が明確。旧説明・重複・Issueの順序を整理 | 完了・[PR #30](https://github.com/KantoYamamoto/sekka/pull/30) |
| [#29](https://github.com/KantoYamamoto/sekka/issues/29) 元の問いとの接続を検証 | 3場面と妥当な対照例を固定し、問い→観測→不足文脈を記録。次の一手か見送りを選ぶ | 完了・[記録](docs/validation/structural-questions.md)。独立比較ではない |
| [#31](https://github.com/KantoYamamoto/sekka/issues/31) 既存表記を添える | Loggerの手掛かりと無関係なIntのノイズ、表示上限・JSON整合を確認 | 完了・PR #33の最終CIと実コメント確認済み |
| [#34](https://github.com/KantoYamamoto/sekka/issues/34) 全変更一覧 | CLI/JSON/PRで非Swift・除外・解析済みの対象範囲が一致 | 完了・PR #43/#44の最終CI・実コメント確認。[検証記録](docs/validation/comparison-inventory.md) |
| [#41](https://github.com/KantoYamamoto/sekka/issues/41) 同名宣言の対応 | extension先頭追加を既存メンバーの置換と誤表示しない | 完了。[PR #42](https://github.com/KantoYamamoto/sekka/pull/42)の最終CI・実コメントを確認 |
| [#45](https://github.com/KantoYamamoto/sekka/issues/45) Gitの実行境界 | 対象repoのfilter/fsmonitorを実行せず一覧を取得する | 完了・[PR #46](https://github.com/KantoYamamoto/sekka/pull/46)。独立実装レビュー・最終CI・実コメント確認 |
| [#35](https://github.com/KantoYamamoto/sekka/issues/35) 確認先を統合 | 本体のみ・比較相手なしへの入口と詳細が重複しない | 実装・固定入力比較中。1 PR。[判断0027](docs/decisions/0027-integrated-review-index.md) |
| [#36](https://github.com/KantoYamamoto/sekka/issues/36) 初期値の案内 | フォールバック再現と前後式/hunk表示の比較 | 1検証。結果から実装を選ぶ |
| [#38](https://github.com/KantoYamamoto/sekka/issues/38) 再掲ノイズ | 既存型表記とcompact JSONのnoticeを、省略・任意表示含めて比較 | #34の対象範囲を使い、#35と整合。1検証 |
| [#39](https://github.com/KantoYamamoto/sekka/issues/39) 試用配布 | 1環境で初回導入時間・実行互換性・成果物由来を検証 | #34/#35の後。Homebrewや広範なM3導入は含めない |
| [#8](https://github.com/KantoYamamoto/sekka/issues/8) API・モデル比較 | 役割/APIの拡大について理由付き確認先を選べるか | 初回完了・[結果と制約](docs/validation/v03-01-results.md)。M2全体は未完了 |
| [#9](https://github.com/KantoYamamoto/sekka/issues/9) SwiftUI比較 | 状態・表示の配置を考える入口になるか | #34/#41と出力整理の後、未読入力・資料取得・読取り順を固定して選び直す |
| [#10](https://github.com/KantoYamamoto/sekka/issues/10) 追加削除・分割比較 | 新しい窓口や分割と既存の配置を照らせるか | #34/#41と出力整理の後、未読入力・資料取得・読取り順を固定して選び直す |
| [#11](https://github.com/KantoYamamoto/sekka/issues/11) 小さい変更の比較 | 読む負担が利益を上回らないか | #34/#41と出力整理の後、未読入力・資料取得・読取り順を固定して選び直す。小変更を無理に重要視しない |
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
