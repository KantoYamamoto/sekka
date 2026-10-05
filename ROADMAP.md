# Sekka: 現在位置と作業順

更新日: 2026-10-05。現在の計画は[全体方針 #12](https://github.com/KantoYamamoto/sekka/issues/12)、理由は[0031](docs/decisions/0031-structural-success.md)・[0038](docs/decisions/0038-outside-diff-context.md)。Issue本文が現在の進行、コメントが経過、判断/検証文書が根拠を持つ。

## ゴールと現在位置

**通常diffを補い、変更を既存構造へどう組み込むか考えるための差分外の実装・既存窓口を、関連根拠付きで示す。** 構文上の候補と不明を区別し、設計の良否・実calleeを推測で確定しない。Swift 6以降、CLI/Actions、LLMなしの決定論性を維持する。

現在の本番CLIは構造差分と確認先への案内。既存構造の再検討への寄与は未確立。**#102 / PR #104は別入力の素材・全3pairs・独立結果点検まで完了、最終PR確認待ち。** 選択4件中3素材1,891 entries/全diff/4mode各二回一致、1件は固定base不成立で差し替えなし。新入口1件は確認に使われたが構造再検討の機械寄与は0。stage1が原planと異なり非対称だったため純増効果は未判定。[結果と限界](docs/validation/both-side-call-holdout.md)。本番/M3は保留。次は#105で、通常sourceから問いが立った「変更された既存窓口」も含む観測単位を診断する。必要性のA/B判断差を残し、未変更宣言への到達だけを成功にしない。[方針0048](docs/decisions/0048-changed-existing-context.md)。人間判断待ちなし。

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
| 3 | [#81 parser非対応](https://github.com/KantoYamamoto/sekka/issues/81) | 実験依存604.0.0で固定4入力を解析。検索0件を失敗と分離し、独立レビュー・Actions/実成果物までPR #82で完了 |
| 4 | [#83 字句scopeの索引](https://github.com/KantoYamamoto/sekka/issues/83) | extension/top-levelの関数を保持し、前後対応の曖昧さを残す。53テスト・独立レビュー修正・固定入力・自己利用・Actions/実成果物までPR #84で完了 |
| 5 | [#85 member表記の関係](https://github.com/KantoYamamoto/sekka/issues/85) | 旧caller/receiverの不明と同形宣言を分ける。63テスト・11 CLI対照・独立レビュー・既知回帰・自己利用・Actions/実成果物までPR #86で完了 |
| 6 | [#87 固定未読PRの比較](https://github.com/KantoYamamoto/sekka/issues/87) | 別4PR/評価器固定、段階別A/B・根拠照合・独立結果点検・Actions/実成果物までPR #88で完了 |
| 7 | [#89 入口の字句条件](https://github.com/KantoYamamoto/sekka/issues/89) | 記載条件をcall根拠へ添え、異なる条件を別集約にする。適格性/一意性は維持。71テスト/12 CLI・既知4PR・独立レビュー・自己利用・Actions/実成果物までPR #90で完了 |
| 8 | [#91 必要先への未到達診断](https://github.com/KantoYamamoto/sekka/issues/91) | 既存レビューの23位置を固定し索引/検索条件へ戻す。無条件の逆引き/記載API family/戻り値名の仮説を比較、独立点検・自己利用・Actions/実成果物までPR #92で完了 |
| 9 | [#93 戻り値名/call表記](https://github.com/KantoYamamoto/sekka/issues/93) | 既存producerとの関係を現索引/一覧へ統合。85テスト/13 CLI・独立指摘修正・既知4PR・自己利用・Actions/実コメント/10成果物までPR #94で完了 |
| 10 | [#95 別の固定PRで独立比較](https://github.com/KantoYamamoto/sekka/issues/95) | 素材/二回実行/段階別A/Bと6,260検査・source根拠の独立点検まで完了。未解消指摘なし、本番保留。PR #97にActions/実コメント/10成果物の完了記録 |
| 11 | [#96 減った利用と残る窓口の診断](https://github.com/KantoYamamoto/sekka/issues/96) | 58必要位置を先に固定、4caseの全42減少selector/4不変候補を照合。copy先例と挙動helperに交差、同名/必要集合外も記録。37対照・修正後全bytes一致・独立点検/指摘修正完了。PR #99でActions/実コメント/10成果物まで確認して完了 |
| 12 | [#98 実験CLIの失敗表示](https://github.com/KantoYamamoto/sekka/issues/98) | reader/formatterを共有し、path欠落の独立指摘も修正。85テスト/14 CLI/37診断対照と失敗全bytes一致を確認。PR #101で通常Actions/実コメント/10成果物まで確認して完了 |
| 13 | [#100 両側のcall入口](https://github.com/KantoYamamoto/sekka/issues/100) | 前後call索引と不変判定を共有、member経路をintroduced/decreasedへ置換。100テスト/17 CLI/診断37と既知4caseを確認、全81出現/13targetを独立点検。詳細外も全位置を残す。PR #103でActions/実Bot/10成果物まで完了 |
| 14 | [#102 両側入口の別入力比較](https://github.com/KantoYamamoto/sekka/issues/102) | 3素材/全bytes/diff、全3pairs・結果独立点検済み、1入力不成立。stage1非対称を解釈制限として保持、露出誤分類を訂正。最終PR確認待ち、M3保留。次は#105の観測単位診断 |
| 15 | [#105 変更された既存窓口の診断](https://github.com/KantoYamamoto/sekka/issues/105) | #102完了後。必要位置を固定し、initializer等の領域・変更target・記載関係/対応の不足を分離。最小diagnosticと反対例から組み直し/撤去/用途限定を選ぶ |

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
