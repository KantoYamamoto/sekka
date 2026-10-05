# 両側call入口の独立比較（#102）

**既知先例への到達を有用性とせず、別入力で通常diff+検索と比較する。利益が支持されなければ本番へ統合しない。** [Issue #102](https://github.com/KantoYamamoto/sekka/issues/102) / [PR #104](https://github.com/KantoYamamoto/sekka/pull/104)。2026-10-05。結果の独立点検、最終Actions/実コメント/成果物まで完了。

## 固定と検証の範囲

[原計画と選択](../../Experiments/StructuralContext/BothSideHoldout/README.md)はsource/diff/機械出力閲覧前に固定。前段PR #103のSources treeと同一の固定binary `d460007` を使い、default/all JSON/textを各二回実行した。3入力の全1,891 entriesと通常diff344paths/1,697hunksを照合、全modeでexit/stdout/stderr bytes一致。対象ビルド・スクリプト・checkout・外部投稿なし。

選択4件中Collections #745は固定beforeとmerge-base不一致の入力不成立。source/diff/query/reviewへ渡さず、ref修正・差し替えをしない。候補0、未到達や成功の母数へ混ぜない。空白pathへの素材照合器修正は[対照と理由](../../Experiments/StructuralContext/BothSideHoldout/README.md#入力を比較へ渡す境界)へ記録し、評価器は変えていない。

各caseに履歴なしのA/B担当を用意した。stage1はAにPR本文+通常diff、Bに同じ本文+default/all索引を渡し、同じ範囲/限界説明を添えた。両初期checkpointの保存・hash固定と全素材の再照合後だけ、同じsource/diffをstage2へ開放。指示による分離でOS隔離ではない。747のstage2とprotocol修正点検は利用上限で中断し、同じ担当/素材で再開、checkpoint同一を確認した。各担当の未精読範囲を全読了として扱わない。

**手順の相違：原planの「同じ素材+Sekka」に対し、stage1のBへ通常diffを渡していなかった。** stage2では共通資料だが、初期の情報と読む順序が非対称である。純粋に同じ情報へ索引を追加した増分効果として、A/Bの差や確認先の違いを評価できない。原plan/receiptは書き換えず、この逸脱を公開する。機械出力の到達/未到達と共通sourceにある問いは記録できるが、今回からレビュー効率や増分利益の肯定・否定へ進めない。後続比較はBのstage1にも同じ通常diffを渡す契約を事前固定する。

## 結果と帰属

| 入力 | 全根拠のtarget / entry | A / Bの配置の問い | 案内の寄与 |
| --- | ---: | --- | --- |
| [Collections #747](https://github.com/apple/swift-collections/pull/747) | 14 / 25 | 両方とも追加再配置の根拠不足 | Bは共有探索・移行helperを確認。新decreased入口は1件、sourceでtrailing closureへの表記変更を確認し、利用消失とする初期疑問を棄却。増分利益は未確立 |
| [GRDB #1885](https://github.com/groue/GRDB.swift/pull/1885) | 0 / 0 | Aは必要性不足、Bは限定的な問い成立 | Bの問いは通常diff+sourceから。機械が案内した成果ではない。必要な未変更binding等の確認先も検索で得た |
| [GRDB #1884](https://github.com/groue/GRDB.swift/pull/1884) | 0 / 0 | 両方とも反復負担なし | 同期/非同期の開始が既に同じ変更関数へ合流することを検索で確認。0候補でも関連先は存在 |

747のBによる25entry分類は、必須4・文脈19・不要2。新decreased1件は必須の確認に実使用されたが、入口callは通常diffに既露出で、表記の変化を意味上の利用減少としないために使った。既存経路はintroduced22/type2で、必須は3entry。共有移行helperから条件節を追加確認した例もあるが、静的な挙動確認事項であって構造再配置の成果ではない。不要候補は同名distanceと別のSlot型で、callee/type未解決のまま実使用関係を認めない。

独立点検で露出分類を1件訂正した。raw Bのentry25（`_BTree+UnsafeCursor.swift:301`のtoNode）は「通常diffのcontext」と記録されていたが、hunkは273–295/311–368で、入口もtargetも差分外。公開metadataはこの露出を訂正し、raw誤分類は残す。Bによる文脈という必要性分類は変わらず、全入口が通常diffに出るとは一般化しない。

## 見直す根拠

GRDB #1885では、scalar initializer（after `GRDB/Core/DatabaseFunction.swift:90–119`）と既存`report`（after同`:444–461`）のString結果転送へ同種の変更が入る。Bは、この二箇所を既存reportへ揃える問いを、反復修正・成立条件・現配置の利点と併せて立てた。Aも同じ候補を検討したが、主要な規則は新しいString helperへ既に集約され、残る薄いswitchの統合が必要とする根拠は不足と判断した。合意や設計欠陥へ書き換えない。

この問いの根拠となるreportは**既存だが本体が変更された宣言**で、現在の候補契約「宣言全体が不変」から外れる。scalar側もinitializerで、関数中心の索引とは範囲が違う。通常diffのfragmentだけでは、両宣言全体と共有先の利用側の関係は読めない。差分外の根拠を、未変更宣言だけに限定してよいかを診断する理由になる。ただし、この1例へ後から到達すること自体は未見の利益としない。

## 結論の境界と次の分岐

今回、**Sekkaに帰属できる根拠付きの構造再検討は0件**。必要先への案内は一部にあるが、増分利益は手順の相違もあって未判定、M3/本番採用は保留する。3有効入力とAI担当の部分的静的レビューであり、全PRの有効性/無効性、網羅的必要集合、人間の時間・token削減を断定しない。

次は候補ルールを足すより、変更された既存窓口と、その差分外body/利用側を含める関係単位が成立するかを、既読例と反対例で診断する。配置の問い、必要性の判断差、SDK/条件/型の未解決を残す。条件が成立しなければ別の検索方式や用途限定へ戻り、今回の入力を再び未読評価と呼ばない。

## 証拠

結果の独立点検で3pairs/25entry/65source regionと全freeze/hashを照合し、追加要修正なし。stage1手順の相違は正常実験へ修復されたとは扱わず、解釈制限として保持。露出誤分類は公開結果だけ訂正した。[audit receipt](../../Experiments/StructuralContext/BothSideHoldout/audit.json)は点検時のbytesへ結び付く。

- [inputs / 検証receipt](../../Experiments/StructuralContext/BothSideHoldout/input-validation.json)：成立/不成立、全path/mode/blob/bytes/SHA、diff照合と素材対照。
- [execution](../../Experiments/StructuralContext/BothSideHoldout/execution.json)：固定binaryと全process bytes。
- [stage1 freeze](../../Experiments/StructuralContext/BothSideHoldout/review-material.json)、[結果metadata](../../Experiments/StructuralContext/BothSideHoldout/results.json)：target/entryの位置と分類、初期/final/release hash。raw source/body/diff/レビューはignored `.build/both-side-comparison` に保持。
- 素材protocolの独立点検は、release前のfreeze検査不足P2を修正後、コピー上で正常1/拒否19、747実releaseの全1,211fileと両checkpoint一致まで確認。初期指摘はraw記録へ残した。
- commit `8508750` のActions `37255787147` は成功、実Bot `5987019929` とsummaryが一致、10成果物・base/head/diff hashを点検。これは素材固定段階の確認で、結果確定後の最終PR確認とは分ける。
- 最終head `ff0e4b5` の[Actions `37281008235`](https://github.com/KantoYamamoto/sekka/actions/runs/37281008235)成功。同じBotの更新後全文とsummary一致、10成果物・base/head/diff SHAを確認。21変更パス/Swift変更0も表示された。[完了記録](https://github.com/KantoYamamoto/sekka/pull/104#issuecomment-5993221290)。`fe3c1eb`でマージ、#102完了。これは検証作業の完了であり、目的達成や純増効果の証明ではない。
