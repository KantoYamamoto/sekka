# Sekka: 現在位置と次の作業

更新日: 2026-09-09。現在の計画の正本。変更理由は[0021](docs/decisions/0021-whole-project.md)・[0023](docs/decisions/0023-review-entry.md)、以前の計画と完了履歴は[見直し前のROADMAP](https://github.com/KantoYamamoto/sekka/blob/fca2987/ROADMAP.md)で追えます。

## 目的と現在位置

**Swiftの変更を、既存の構造へどう組み込むかを考える入口を作る。** 短い出力や速いdiff移動は、そのための手段です。開発側も、局所の変更とプロジェクト全体の目的・優先順位の両方を見直します。

構文差分・型別要約・引数差分・本体比較状態・diffへの案内・自身のCI/PRコメントは実装済みです。初期値変更の盲点修正も[PR #27](https://github.com/KantoYamamoto/sekka/pull/27)で完了しました。一方、既存の役割分担を見直す助けになるか、通常diffのみよりレビューの手間や見落としが減るかは未確立です。

**入口改善は完了。#50の独立A/B比較も完了し、現在は#12の方針判断待ち。次は「設定不要のPR索引を磨く」か「プロジェクトの役割・境界を明示する入力を一例で検証する」かを選ぶ。** [提案0030](docs/decisions/0030-next-hypothesis.md)は後者。新しい利用者負担を伴うため未採用で、実装は始めない。

全変更一覧（#34）、Git実行境界（#45）、確認先統合（#35）、初期値・片側宣言の移動（#36）、compact NOTE整理（#38）は検証済み。#35のPR表示は[PR #48の実コメント](https://github.com/KantoYamamoto/sekka/pull/48#issuecomment-5582855713)をブラウザでも確認した。

[API比較 #8](docs/validation/v03-01-results.md)と[削除比較 #50](docs/validation/v03-02-results.md)では、両担当がほぼ同じ確認先に到達し、Sekka固有のレビュー利益は未確認。中断で速度も判定不能。削除例ではtextが433行・46,929 bytes、Swift diffが408行・17,171 bytesで、同名extensionの未比較説明が重い。[試用報告](docs/validation/bloom-feedback.md)・[Sekka自身の報告](docs/validation/sekka-pr-feedback.md)と合わせ、大きなSwift PRへのopt-in CLI/artifactは引き続き利用仮説に留める。全PRの常設botは推奨しない。Mermaid・配布拡大は保留。

## マイルストーンと判断の節目

| 段階 | 完了条件 | 現在の状態 |
| --- | --- | --- |
| M0・M1: 観測と読みやすさの土台 | 構文事実・限界・重複整理・diff到達が再現可能 | 完了。[M1検証](docs/validation/m1-output.md) |
| R1: 目的と現状をつなぎ直す | 文書・計画を統合し、元の問いと観測・不足文脈を対応付ける | 完了。#28の再構成と[#29の6ケース検証](docs/validation/structural-questions.md) |
| R2: 小さな改善か見送りを選ぶ | 現状出力・再編集・追加観測を比較し、対照例込みで一つ選ぶ | #31で既存情報を再編集。材料と増える負担を検証 |
| R3: 比較範囲と確認先を統合する | 対象外を隠さず、未比較箇所へ重複せず到達できる | 機能・固定入力検証は完了（#34/#35/#36/#38）。未比較詳細の重さは#50で残存確認 |
| M2: 実レビューで利益を比較する | 確定した問いについて通常diffのみとの差と限界を記録 | #8/#50の独立比較を記録。利益未確認・速度判定不能。#12の判断を前倒し |
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
| [#35](https://github.com/KantoYamamoto/sekka/issues/35) 確認先を統合 | 本体のみ・比較相手なしへの入口と詳細が重複しない | 完了・PR #47/#48の最終CI・実投稿・展開表示を確認。[記録](docs/validation/integrated-review-index.md) |
| [#36](https://github.com/KantoYamamoto/sekka/issues/36) 初期値の案内 | フォールバック再現と前後式/hunk表示の比較 | 完了・PR #48の最終CIと実コメント確認。[記録](docs/validation/declaration-navigation.md) |
| [#38](https://github.com/KantoYamamoto/sekka/issues/38) 再掲ノイズ | 既存型表記とcompact JSONのnoticeを、省略・任意表示含めて比較 | 完了・PR #49の最終CI・実コメント確認。既存型表記は暫定維持。[判断0029](docs/decisions/0029-compact-notice-scope.md) |
| [#50](https://github.com/KantoYamamoto/sekka/issues/50) 削除の独立A/B比較 | 先読みcheckpointと通常diffの照合で固有の助け・負担を比較 | 完了。[結果](docs/validation/v03-02-results.md)。固有の利益未確認、速度判定不能 |
| [#39](https://github.com/KantoYamamoto/sekka/issues/39) 試用配布 | 1環境で初回導入時間・実行互換性・成果物由来を検証 | #12の用途判断後に再開可否を選ぶ。Homebrewや広範なM3導入は含めない |
| [#8](https://github.com/KantoYamamoto/sekka/issues/8) API・モデル比較 | 役割/APIの拡大について理由付き確認先を選べるか | 初回完了・[結果と制約](docs/validation/v03-01-results.md)。M2全体は未完了 |
| [#9](https://github.com/KantoYamamoto/sekka/issues/9) SwiftUI比較 | 状態・表示の配置を考える入口になるか | #12で仮説を選んだ後、未読入力・資料取得・読取り順を固定する |
| [#10](https://github.com/KantoYamamoto/sekka/issues/10) 追加削除・分割比較 | 新しい窓口や分割と既存の配置を照らせるか | 削除の1例は#50で実施済み。追加・分割は未完了。#12で仮説を選んだ後、未読入力・資料取得・読取り順を固定する |
| [#11](https://github.com/KantoYamamoto/sekka/issues/11) 小さい変更の比較 | 読む負担が利益を上回らないか | #12で仮説を選んだ後、未読入力・資料取得・読取り順を固定する。小変更を無理に重要視しない |
| [#12](https://github.com/KantoYamamoto/sekka/issues/12) 投資判断 | 継続・用途限定・方向修正と次の一手を根拠付きで記録 | 判断待ちへ前倒し。#8/#50の結果と[提案0030](docs/decisions/0030-next-hypothesis.md)を利用者に提示。未実施の#9/#11を完了扱いにしない |
| [#18](https://github.com/KantoYamamoto/sekka/issues/18) トップレベルの個別案内 | 現行の具体的な不足として保持 | 保留。#29または実比較で目的への寄与が確認されたら検討 |

## 完了済みの根拠

- [Git読み取り改善](docs/validation/git-batch.md)：同じ出力で実行時間を削減。
- [自己利用CI](docs/validation/pr-actions.md)・[PRコメント](docs/validation/pr-comments.md)：投稿・更新・罫線・diffリンクを確認。
- [予備試行](docs/validation/review-pilots.md)・[15境界ケースと実変更](docs/validation/coverage-boundaries.md)：観測と不足を確認。独立比較には数えない。
- [初期化式](docs/validation/property-initializers.md)：49 Swiftテスト、27 CLI/Gitチェック、15probe。通常diffと自己利用も実施。

## 作業を選び直す基準

利用場面と助けたい検討、既存機能へ組み込む方法、読む負担・誤誘導、後回しにする仕事を明示します。新しい要求は既存計画と統合し、不要なIssueは理由付きで閉じます。保留は未達のまま保持し、検証結果が不利でも有効な結果として扱います。

自己レビューは実装者による検査です。独立比較には未読の入力と比較条件が必要で、同じPRの再読を速度改善の証拠にはしません。検証手順は[protocol](docs/validation/protocol.md)、日々の進め方は[development](docs/development.md)を参照してください。
