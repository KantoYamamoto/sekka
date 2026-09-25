# Sekka: 現在位置と作業順

更新日: 2026-09-25。現在の計画は[全体方針 #12](https://github.com/KantoYamamoto/sekka/issues/12)、理由は[0031](docs/decisions/0031-structural-success.md)・[0038](docs/decisions/0038-outside-diff-context.md)。Issue本文が現在の進行、コメントが経過、判断/検証文書が根拠を持つ。

## ゴールと現在位置

**通常diffを補い、変更を既存構造へどう組み込むか考えるための未変更実装を、関連根拠付きで示す。** 構文上の候補と不明を区別し、設計の良否・実calleeを推測で確定しない。Swift 6以降、CLI/Actions、LLMなしの決定論性を維持する。

現在の本番CLIは構造差分と確認先への案内。既存構造の再検討への寄与は未確立。**#78はPR #80で自己利用・独立レビュー・Actions/実成果物確認まで完了。現在は#81で実験parserを更新し、固定4入力への到達を再確認している。** Collectionsの解析失敗は解消したが候補は0。GRDBの既知1件へは到達する。[結果](docs/validation/parser604-reach.md)。索引外のextension/契約変更をどう入口にするかを次に見直す。本番統合は保留、人間の判断待ちはない。

## Issueの階層と判断の節目

以下のM1〜M3は2026-09-14以降の計画。過去の出力整理に使った同名の段階とは別。

| マイルストーン | 終了条件 | 結果による次の判断 |
| --- | --- | --- |
| [M1 #69](https://github.com/KantoYamamoto/sekka/issues/69) 最小の根拠付き案内 | 位置・型注釈・候補・本文未変更と、不明/省略を再現できる。独立レビュー・自己利用・Actionsまで検証 | 事実性が成立すれば評価器を固定してM2。狭すぎる/誤誘導なら範囲または方式を変更 |
| [M2 #71](https://github.com/KantoYamamoto/sekka/issues/71) 未見の実変更で比較 | 必要な差分外の確認先、案内の寄与と無関係な候補、配置の問いと反対理由を記録 | 継続・用途限定・再設計・保留を#12で選ぶ。利益が弱ければM3へ進めない |
| [M3 #72](https://github.com/KantoYamamoto/sekka/issues/72) 有効な用途を統合 | 本番CLI/JSON/text/Actionsの入力・範囲・利用方法を整え、実出力を確認 | M2が支持した用途だけ統合。必要なら配布を再評価 |

## 直近だけをPR単位に分解する

M1の#73（構文索引/PR #75）と#74（検索と表示/PR #76）は完了。M2は直近の単位だけを具体化する。

| 順序 | Issue | 完了条件 / 状態 |
| --- | --- | --- |
| 1 | [#77 実PRへの到達範囲](https://github.com/KantoYamamoto/sekka/issues/77) | 固定4件・機械出力前の独立通常レビュー・入力照合・実行・結果の独立点検を完了。PR #79で完了 |
| 2 | [#78 入口の見直し](https://github.com/KantoYamamoto/sekka/issues/78) | 変更明示型→未変更の型宣言候補という契約と最小検索。候補の存在と意味解決の不明を分け、既知GRDBへ到達。46テスト・独立レビュー・自己利用・Actions/実成果物確認を経てPR #80完了 |
| 3 | [#81 parser非対応](https://github.com/KantoYamamoto/sekka/issues/81) | 実験依存604.0.0で固定4入力を解析。検索0件を失敗と分離し、独立レビュー/PR互換性確認へ |

必要な確認先へ届いた例はA/B比較を始める根拠とし、有用性の合格とはしない。範囲内の必要箇所へ届かなければ検索方式へ戻す。確認先を特定できない例だけなら今回の標本では判断保留。出力に合う入力への差し替え、同じ入力の未見扱いはしない。M2の続きとM3は結果が出てから分解する。

## 既存の保留課題

| Issue | 現在の扱い |
| --- | --- |
| [#9 SwiftUI](https://github.com/KantoYamamoto/sekka/issues/9) / [#11 小変更](https://github.com/KantoYamamoto/sekka/issues/11) | M2の用途候補。M1の結果を見て再定義し、自動着手しない |
| [#18 トップレベル案内](https://github.com/KantoYamamoto/sekka/issues/18) | 既知の不足。必要な差分外案内との関係が示されたとき再開 |
| [#39 試用配布](https://github.com/KantoYamamoto/sekka/issues/39) | M3で必要性を再評価。Homebrew/全PR常設を既定目標にしない |

## 完了済みの根拠

構造差分、全変更一覧、未比較箇所、diff移動、自己利用CI/PRコメントは実装済み。過去の詳細な計画とPR一覧は[方針統合時のROADMAP](https://github.com/KantoYamamoto/sekka/blob/4cc794f/ROADMAP.md)に残す。

- [#52 材料評価](docs/validation/structural-reconsideration-results.md)、[#54 反復抽出](docs/validation/call-sequence-experiment.md)：手作業材料と機械化の狭さを確認。独立した実用性の証明ではない。
- [#56 公開OSS](docs/validation/oss-structural-context.md)、[#57 継承配置](docs/validation/class-context-experiment.md)、[#62 未見比較](docs/validation/context-holdout.md)：継承方式は別2変更で0候補、本番採用見送り。
- [#63 call接点](docs/validation/change-context-experiment.md)、[#10 未見比較](docs/validation/retrieval-holdout.md)：一部の比較導線は有用。中心的な根拠は普通のソースから得た。
- [#66 参照差](docs/validation/reference-delta.md)：PR #68の実装/CI完了。単独未見評価は保留して閉じ、方針を#69へ統合。
- [#70 検証契約](docs/validation/outside-diff-plan.md)：既存7例の現行出力は全て0候補。関連先への経路、無関係call/型変更、案内の寄与を独立レビューして次の条件を固定。

実装検証と有用性を分け、同じ結論への到達でも案内の寄与は別に評価する。作業手順は[development](docs/development.md)、比較条件は[protocol](docs/validation/protocol.md)。
