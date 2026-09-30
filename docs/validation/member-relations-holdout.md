# member表記案内を別の実PRで比較する

2026-10-01、M2 #87。PR #86の評価器を固定し、出力閲覧前に選んだ別4PRで、通常diff/検索のAと案内併用Bをcaseごとに比較した。**解析・案内の再現性、必要確認先への到達、構造配置を見直す根拠への寄与を別に評価する。** 二件で両担当が具体的な再配置の比較条件まで到達したが、通常diff側も同じ問いに達している。機械案内は一部の未変更契約を読む入口になった。単独の設計判定や本番採用の根拠とはしない。

## 固定・隔離と実際の手順

[計画](../../Experiments/StructuralContext/Holdout/plan.md)を独立レビューし、履歴/段階隔離と構造判定の二点を実行前に修正。各case新しい履歴なしA/B。両者同じ本文のあと、Aは普通のdiffだけ、Bは機械JSON/textだけを先に読んだ。checkpointの存在とSHA-256を確認し、それから同じdiff/before/after sourceを開放。相互結果・別caseの所見・開発者の既知判断は渡していない。共有workspaceのallowed pathを指示して隔離したもので、OSレベルの読取り権限制限ではない。

検索は通常のrg/file読取り。全担当が先読み逸脱なしと申告。一部Aの許可範囲内ファイル名一覧が広く、出力の切れた読取りは対象箇所を読み直した。ファイル名列挙の広さを含む探索履歴は保持した。統合担当は終了後に両者の結果を読む。独立AI各1担当の差も含む小標本であり、人間の効率/一般性/時間token費用を結論しない。

## 入力・機械結果

#77と同じ2repoで既読4PRを除外し、固定日までにmergeされた作成日順の先頭からproduction Swift変更2件ずつ。コメントだけの変更も含め、結果で差し替えなかった。repo自体の未見ではなく別PRの未読レビュー。[selection/manifest/checkpoint](../../Experiments/StructuralContext/Holdout/README.md)に前後commit、3,026エントリ、hash、取得条件と評価器を保存した。

ローカルSwift 6.4 / SwiftSyntax604.0.0、source `2fa2810`、binary SHA-256 `5376f29bdbfb15a24c150792c43b77da33d53704b65050c0a0adbbd2c2bb7626`。全ファイル一覧/Git blob/SHAを照合後、JSON/textを各二回実行。全4件で終了コード/stdout/stderr一致、解析成功。共有Reach runnerをmanifest指定で再利用し、初回凍結出力と一致。破損manifestはquery/出力作成前に拒否した。解析/候補条件は変更していない。対象OSSのcheckout/build/scripts/test/先方への投稿は行わなかった。

| 入力 | 対応内変更関数 | 未変更候補 | 初期案内の性質 |
| --- | ---: | ---: | --- |
| [Collections #725](https://github.com/apple/swift-collections/pull/725) | 0 | 0 | 表記修正。候補なしから通常diffへ |
| [Collections #724](https://github.com/apple/swift-collections/pull/724) | 1 | 4 | 既存の可変span走査、source終端確認、buffer範囲抽出 |
| [GRDB #1864](https://github.com/groue/GRDB.swift/pull/1864) | 2 | 0 | 候補なし。通知選択/activationの文脈は普通のソースから |
| [GRDB #1858](https://github.com/groue/GRDB.swift/pull/1858) | 3 | 1 | 未変更のDAO.upsertStatementへ |

省略候補/入口は全4件0。必要箇所を全て案内した意味ではない。public results.jsonは宣言位置/関係だけに絞り、call/body tokenや生レビューを載せない。

## 照合済みの所見

### Collections #725

両者が現配置を支持。表記修正はその操作/契約/診断の位置に適合し、反復する局所追加の負担は未確認。必要な本文や比較対象は通常diff/検索で見つけた。Sekkaの0件は健全性や有用性の証明ではなく、構造根拠への積極的な寄与はなかった。既存文書の不整合は通常ソース読解の発見であり、Sekkaに帰属させない。

### Collections #724

両者が、4つの新しいOutputSpan/InputSpanのsubrange/all移動処理に同じ手動ループ、無効な最適化分岐、workaround/TODOが繰り返されると確認。修正/最適化を四箇所で揃える具体的負担がある。通常diffだけのAも到達しており、独自発見ではない。

Bは機械先読みで`_extracting(unchecked:)`への両moduleの入口を選び、span/utility境界を問いにした。最終的な共通化候補の根拠は、通常diff内の四重ループと、その後の未変更source探索で得たadapterの先例/初期化領域の契約。機械候補だけで結論を得たとはしない。高層のMutableContainer走査とsource終端確認は現配置を支持する根拠になった。

具体的な先例はbefore `InternalCollectionsUtilities/OutputSpan+Extras.swift:55–79`と`SpanPreview/OutputSpan+InputSpanHelpers.swift:25–32`。prefix/suffixをadapterが選び、共有raw-buffer処理へ渡す。これらの本文/dispatchは通常diffのcontext外で、今回の機械候補にも含まれていない。InputSpanのsuffix初期化契約も必要で未到達だった。

代替案は、低層の移動更新kernelだけをutilityへまとめ、range/count/lifetimeとprefix/suffix選択をwrapperへ残すこと。初期化ではなく既存要素の更新、alias/overlap、noncopyable/lifetime、availability/module境界を保てる場合に限る。短期のstdlib置換予定や局所の読みやすさは、現状を許容する反対理由になる。提案のbuild/runtime/performanceは未検証で、上流へ提案していない。

**重要な限界:** `_extracting`へのmoving入口の一部は`#if false`内（utility after55–59、preview after39–43）。同じ#ifの#else側は`_ptr`と手動ループ。outerのcompiler/feature条件も含め有効な構成を判定したわけではない。先読み時に実経路と断定しなかったが、字句条件が表示されないためsource読解で訂正が必要だった。表記の一致数を現役の共通実装への集約と誤読してはいけない。次の改善候補は候補増より、各入口の書かれた条件を明示すること。

### GRDB #1864

両者がPR自身によるper-observer選択のTransactionObservationへの移動を支持。wrapperは既存のobserver/lifetimeを持ち、brokerはconnection hookとtransaction/savepoint deliveryを持つ。更なる再配置のための反復負担は未確認。必要だった未変更のhook activation、authorizerのdeletion判定、既存event predicateへは機械の0件から届かず、全て通常diff/ソース検索の根拠だった。PR本文の旧説明と実APIの違いも普通のソースで確認した。

### GRDB #1858

Bは先読みで、変更された`upsertWithoutCallbacks`から未変更`DAO.upsertStatement`のbody/契約（before/after `Record/MutablePersistableRecord+DAO.swift:42–139`、diff/context外）を選んだ。callerが選ぶRETURNINGに既存のSQL計画が依存することを読み、修正や共通処理を単純にDAOへ押し込まない反対理由に使った。これは構造比較の境界条件に使われた案内であり、候補の件数だけの評価ではない。

両者が反復するsuccess情報の組立てを再検討。Aは既存insert（`Record/MutablePersistableRecord+Insert.swift:659–674`）と旧fetch upsertに対する新しい三箇所目の組立てを根拠に、狭いmetadata helperを条件付き候補にした。Bはplain/fetch executorでrowID判定、cursor完了、success組立てが繰り返される点から、record操作層の共有executor/planを比較する案まで広げた。同じ唯一解になったのではない。

必要なinsertの先例、InsertionSuccessとRecord callback、schemaのhidden rowID契約は通常の追加検索で得て、機械には未到達。返却行の有無、decoderが見るrow形状、cursor完了、callbackの順序、mutating/nonmutatingの違いを維持できなければ共通化しない。現状の明示分岐にも理由があり、改修/性能/動作を検証した提案ではない。

機械は同じcaller/receiver/selectorの二出現をまとめ、最初の`returning: [Column.rowID]`と件数を示した。後の`returning: []`（after502–507）の位置/引数はsourceで初めて見えた。この省略は同じ挙動の反復を意味しない。Aの別の静的SQL指摘もsource読解の所見であり、Sekkaの発見や実行検証にはしない。

## 判断

| case | 根拠付き構造比較 | 機械案内が寄与したもの | 機械だけでは足りなかったもの |
| --- | --- | --- | --- |
| Collections725 | 反復負担未確認、現配置支持 | 積極的寄与なし | 必要な契約/文書比較はdiff/検索 |
| Collections724 | 低層kernelの四重化とadapterを残す条件 | moduleをまたぐbuffer/走査/終端の確認先、現配置の支持 | 実ループ、共有adapterの先例、suffix/lifetime契約。条件内のcallは実経路ではなかった |
| GRDB1864 | 更なる再配置の反復負担未確認 | 積極的寄与なし | activation/authorizer/deliveryの境界、PR自身の配置改善 |
| GRDB1858 | success組立て/共有executorの条件付き比較 | 既存SQL選択契約とDAO境界を読む入口 | insertの先例、結果/callback/schema契約と具体的負担 |

**継続。ただし本番統合は保留。** 二件は「局所追加を続ける案と別配置を比べる」検討まで到達し、一部の差分外案内はその支持/反対理由に使われた。根拠の中心は通常diffと追加source読解であり、独自発見/負担削減/全PR必須を証明していない。構造を考える補足というコンセプトを直ちに撤回する結果ではなく、関係の伝え方を一つ修正して再点検する根拠とする。

次は#724で初期関係の読み違いを招き得た字句条件を入口へ表示し、異なる条件の出現を混ぜない1PRへ分解する。`#if false`を含む記載条件を保持し、有効branch/実calleeは解決しない。候補増加や必要性scoreより先に不明/条件を確かめられることを優先する。評価条件/方式を変えたら今回の四件は既知回帰であり、未見として再採点しない。

## 現在位置と制約

生資料はGit管理外`.build/m2-unseen`、入力/出力のbyte hash、段階の開放時刻、checkpointとraw reviewを保持した。機械結果の再現とAI所見の再現は異なる。必要箇所のA/B合併を網羅的正解集合にせず、precision/recallやレビュー負担削減を主張しない。

独立結果点検で3,026入力の一覧/blob/SHAと段階・レビューhashが一致し、必要な位置と発見の帰属を確認。公開/非公開selectionと初回/再現runnerのhashの区別を明示した後、未解消の指摘はなかった。記録PR [#88](https://github.com/KantoYamamoto/sekka/pull/88)はhead `6d9b17f`、[Actions 36791837704](https://github.com/KantoYamamoto/sekka/actions/runs/36791837704)、実botコメントと10成果物のhead/summary一致を確認してmerge `739e0ab`で完了した。次は[#89](https://github.com/KantoYamamoto/sekka/issues/89)の入口の字句条件表示。構造を見直す根拠への寄与がどこから来たかで判断し、案内候補が出た数でM3へ進めない。人間の判断待ちはない。
