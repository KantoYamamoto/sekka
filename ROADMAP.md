# Sekka: 現在位置と作業順

更新日: 2026-10-08。現在の計画は[全体方針 #12](https://github.com/KantoYamamoto/sekka/issues/12)、理由は[0031](docs/decisions/0031-structural-success.md)・[0038](docs/decisions/0038-outside-diff-context.md)。Issue本文が現在の進行、コメントが経過、判断/検証文書が根拠を持つ。

## ゴールと現在位置

**通常diffを補い、変更を既存構造へどう組み込むか考えるための差分外の実装・既存窓口を、関連根拠付きで示す。** 構文上の候補と不明を区別し、設計の良否・実calleeを推測で確定しない。Swift 6以降、CLI/Actions、LLMなしの決定論性を維持する。

本番CLIは構造差分と確認先への案内であり、元目的の一般有用性は未確立。保存した直近の検証単位は[0054](docs/decisions/0054-callback-contract-adaptation.md)の共有callback契約拡大への既存closure適応。設定なし/LLMなしで、追加値を捨てる利用側とAPI位置をまとめ、現API・event payload・旧入口/adapterを比較する。

**#124 / PR #125は完了。** 実装前に固定したMaple五closureを取得し、15負例/5入力失敗、独立指摘修正/再確認、初読A/B、自己利用、最終Actions/実Bot/18成果物確認後merge `3a1ccdb`。[結果と限界](docs/validation/callback-contract-cost.md)。通常資料も同じ境界の問い/専用入口案へ到達し、追加資料の支持は根拠整理/照合の補助に限る。問いの新規性/時間短縮/未見の有用性は未支持。

**[#126](https://github.com/KantoYamamoto/sekka/issues/126) / [PR #127](https://github.com/KantoYamamoto/sekka/pull/127)で実入力へ限定接続。** `sekka review`が共通解析をGit/dir/worktree・text/JSONへ接続する。新しいdetector/未対応構文/素材探索は増やしていない。65 tests/39 smoke/実CLIと表示対照、固定source parity、独立指摘修正・再確認済み。自己利用の実PR候補は0で、対象callback拡大のないPRを有用性の成否へ数えない。最終Actions/実Bot/20成果物/mergeは#126の完了記録を参照する。

**新規開発は当面休止（2026-10-08、ユーザー合意）。** [#130](https://github.com/KantoYamamoto/sekka/issues/130)の判断は解決済み。コード/資料を残し、元の目的は未達として維持する。根拠整理の限定CLIを最終目標にする案は採らない。接続作業はPR #127/先行PR #129までmerge済みで、実装/CI/レビューの未完了はない。

再開はユーザーの指示を受け、最初に「どんな出力なら、どの配置を考え直せるか」という具体的な成功状態と、通常資料だけの判断に対する利益を検証する根拠を決める。構文対応/素材探索/配布/次のPR分解を自動継続しない。[理由と再開条件](docs/decisions/0056-development-pause.md)。M2/M3は未完了のまま保留する。

直前#122は実source二候補で「純中継の既存二型の契約拡大」が不成立なので実装せず終了。#119の中継1→2取得と#121の案内明確化は保存するが、本番の根拠へ読み替えない。旧構造索引/関係試作も統合しない。これまでの直接関係/状態入口の結果は下の完了表と各検証記録を参照する。

## Issueの階層と判断の節目

以下のM1〜M3は2026-09-14以降の計画。過去の出力整理に使った同名の段階とは別。

| マイルストーン | 終了条件 | 結果による次の判断 |
| --- | --- | --- |
| [M1 #69](https://github.com/KantoYamamoto/sekka/issues/69) 最小の根拠付き案内 | 位置・型注釈・候補・本文未変更と、不明/省略を再現できる。独立レビュー・自己利用・Actionsまで検証 | 事実性が成立すれば評価器を固定してM2。狭すぎる/誤誘導なら範囲または方式を変更 |
| [M2 #71](https://github.com/KantoYamamoto/sekka/issues/71) 未見の実変更で比較 | 必要な差分外の確認先、案内の寄与と無関係な候補、配置の問いと反対理由を記録 | 継続・用途限定・再設計・保留を#12で選ぶ。利益が弱ければM3へ進めない |
| [M3 #72](https://github.com/KantoYamamoto/sekka/issues/72) 有効な用途を統合 | 本番CLI/JSON/text/Actionsの入力・範囲・利用方法を整え、実出力を確認 | M2が支持した用途だけ統合。必要なら配布を再評価 |

## 直近だけをPR単位に分解する

| 順序 | Issue | 完了条件 / 状態 |
| --- | --- | --- |
| 完了 | [#115 成功状態から一課題を選ぶ](https://github.com/KantoYamamoto/sekka/issues/115) / PR #116 | 自作のconstructor試作。最終Actions/実Bot/14成果物点検とmerge済み。本番保留 |
| 完了 | [#117 実変更から取得範囲を決める](https://github.com/KantoYamamoto/sekka/issues/117) | 実sourceのcallback中継1→2と別配置の条件を確認、独立照合済み。記録PR #118はActions/実Bot/14成果物確認後merge `30232a4` |
| 完了 | [#119 保持callbackの一経路取得](https://github.com/KantoYamamoto/sekka/issues/119) | 固定実sourceの1→2/旧field削除を取得、独立修正/自己利用/最終Actions/実Bot/16成果物点検とmerge済み。本番保留 |
| 完了 | [#121 素材と案内寄与](https://github.com/KantoYamamoto/sekka/issues/121) / PR #123 | 探索不成立/案の明確化だけ確認。最終Actions/実Bot/16成果物確認後merge `6033ce0` |
| 終了 | [#122 実際の中間API変更](https://github.com/KantoYamamoto/sekka/issues/122) | 最大二Swift候補で元条件不成立。拡張を実装せず、根拠を#124の比較単位へ置換 |
| 完了 | [#126 実入力への限定接続](https://github.com/KantoYamamoto/sekka/issues/126) | PR #127。実Git/dir/worktree、独立レビュー/自己利用まで確認。最終Actions/実Bot/20成果物は#126記録参照。ルール追加なし、M3合格とは別 |
| 完了 | [#124 共有callback契約の適応](https://github.com/KantoYamamoto/sekka/issues/124) / PR #125 | 固定五caller/独立比較/自己利用/最終Actions・実Bot/18成果物まで完了。根拠整理の補助、本番保留 |
| 完了 | [#113 状態/操作入口の限定比較](https://github.com/KantoYamamoto/sekka/issues/113) / PR #114 | 限定寄与/核心未提示を保存。最終Actions/実Bot/12成果物点検とmerge済み。次方式の実装へ自動継続しない |

<details><summary>完了したM1/M2の作業と根拠</summary>

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
| 14 | [#102 両側入口の別入力比較](https://github.com/KantoYamamoto/sekka/issues/102) | 3素材/全bytes/diff、全3pairs・結果独立点検済み、1入力不成立。stage1非対称を解釈制限として保持、露出誤分類を訂正。PR #104の最終Actions/実Bot/10成果物まで完了、M3保留 |
| 15 | [#105 観測単位の診断](https://github.com/KantoYamamoto/sekka/issues/105) | 26対照・全1,891入力entries・独立code/fact/文書点検・自己利用、PR #106の最終Actions/実Bot/10成果物まで完了。既読1関係・他2件0、未読利益は未確立 |
| 16 | [#107 直接関係CLI](https://github.com/KantoYamamoto/sekka/issues/107) | 旧検索runtime撤去、13Swift/31CLI対照・既読全1,891entries/全位置parity・独立指摘修正・自己利用・最終Actions/実Bot/10成果物を確認しPR #108で完了。本番/M3保留 |
| 17 | [#109 直接関係の未見比較](https://github.com/KantoYamamoto/sekka/issues/109) | 新4入力/全3,054 entries/全mode二回一致/同じstage1資料/4pairsを確認。機械関係0、配置への寄与未支持。独立指摘修正・最終Actions/実Bot/10成果物までPR #110で完了 |
| 18 | [#111 状態/操作の新入口](https://github.com/KantoYamamoto/sekka/issues/111) | 既読11固定位置への候補到達、41対照・独立指摘修正・自己利用・最終Actions/実Bot/12成果物を確認しPR #112で完了。未見利益の証明とはしない |

</details>

必要な確認先へ届いた例はA/B比較を始める根拠とし、有用性の合格とはしない。範囲内の必要箇所へ届かなければ検索方式へ戻す。確認先を特定できない例だけなら今回の標本では判断保留。出力に合う入力への差し替え、同じ入力の未見扱いはしない。M2の続きとM3は結果が出てから分解する。独立比較でも配置再考へ寄与せず、別の決定論的根拠もなくなった場合は、用途限定/プロジェクト撤退を人間へ判断事項として通知する。

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
