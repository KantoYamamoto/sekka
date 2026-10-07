# #111: 記載状態と操作を入口にする診断

2026-10-07。**既読GRDB1881の必要な関係を候補として表現できる。未見での利益は後続[#113の限定比較](state-entry-holdout.md)で別に評価した。** 同形switchの入口の利益未支持を修復した結果とは扱わない。本番/M3保留。

## 仮説と出所

新insertを追加する案と、既存の汎用合成を改善する案を比べる問いは、#109のBが通常diff/sourceから出したもの。Aは追加の再配置を不要とし、Bも現配置を支持する。新試作がこの問いを発見したわけではない。[確認先/反対材料](../../Experiments/StructuralContext/StateOperations/anchors.json)を`ef95827`で実装前に固定した。

旧入口は複数実行領域の同形switch変更を要求する。今回必要な関係は同じ型のデータと汎用/専用の操作・既存利用であり、その条件に依存しない。旧runtimeは変更/再buildせず、新packageで書かれたproperty名と操作の参照を読む。変更された既存helperも含め、unchanged targetの条件は復活させない。

## 段階別に残した結果

初稿は変更された関数全体を入口にして10groups/46,182 JSON bytes。本文の別部分の変更でも既存の参照を入口にしたため、7つのStatementAuthorizer field等が候補に入った。本文参照の式token multisetの増加へ変更し、4groups/39,420 bytesになった。件数減少は有用性ではなく、変更との接点を限定する契約の修正。

直接字句ownerの試作ではstatic union494/500が別extensionのため欠落した。`15ad9aa`で範囲変更を先に記録し、property/operationの所属は結合せず、incoming callの検索に一意な同じfileの記載型名→unqualified extension名の候補を加えた。型解決済みではない。最終hash/bytes/時間は[execution](../../Experiments/StructuralContext/StateOperations/execution.json)。debugローカル実行であり、旧方式と同じ計測条件/レビュー時間の比較ではない。

## 固定位置への到達と露出

全てafter `GRDB/Core/DatabaseRegion.swift`。parser scopeでは`Core/DatabaseRegion.swift`。

| 固定位置 | 最終候補の経路 | 通常diffの露出 |
| --- | --- | --- |
| 174/181、397/402 | 新しい参照式を持つ操作 | 追加hunk。差分外発見ではない |
| 144 | field名→既存union | 全体hunk外 |
| 169 | incoming callのcaller/target | body170–171はcontext。新発見としない |
| 377 | 同じfield名→既存union | 末尾contextのみ |
| 205/211 | 同じfield名の既存関数、wrapperへの利用表記 | hunk外。205は関数である |
| 494/500 | 同じfileのextension名候補、wrapperへの利用表記496/503 | hunk外。owner/callee未解決 |

11固定位置への候補到達と、問いへの寄与を分ける。property45は新仮説の材料で、以前のBが必要先としたものに置き換えない。

## ノイズと反対材料

候補にはisEmpty/intersection/contains等も含む。149/160、383/391のunion表記は別のSet/TableRegion側の呼び出しであり、狙ったunionの実calleeとは読めない。selector候補数1でも解決できたことを意味しない。caller/target/条件/候補数と未解決を表示し、textは重複callをまとめるが、これらを無関係として隠さない。

専用insertは狭い入力で一時regionの作成を省き、汎用合成への広い変更を避ける。汎用側を改善するには全DB/nil列/nil行/行制限/コピー独立/識別子/性能の成立条件が要る。支配的なコストや必須refactorは未実測。この反対理由は元レビュー由来で、機械は判定しない。

## 点検と次の判断

独立初稿レビューでP2を2件（implicit getter内local宣言の型memberへの混入、同じheaderの別conditional owner結合）、P3を1件（対照のassert不足）確認した。実行本文をmember inventoryの境界にし、字句ownerを物理宣言identityで分離、前後対応はowner/header/条件の一意性を別に検査する修正を行った。再点検で条件式の空白/コメントだけでも誤anchorするP2、text件数assertの誤passのP3を追加確認し、条件をtoken表記で照合、group数をJSONと明示比較するよう修正した。

property initializer closure/subscript/local function、CodeBlock/Closure内のlocal、別conditional owner、extension候補/同名型/alias/protocol/修飾名、条件triviaのみの対照を加えた。41対照の正常0/失敗とJSON/text二回一致を確認。既読JSON/textの内容は修正前と同じbytesで、source/binary/control hashは更新した。独立最終点検/自己利用/最終Actions/実Bot/12成果物までPR #112で完了。[完了receipt](https://github.com/KantoYamamoto/sekka/pull/112#issuecomment-6036271072)。

既読での必要先到達は、旧条件を足すより新しいstate/operation入口を一度固定して別入力で試す根拠になる。細かなrule、汎用scope拡張、高速化、移植を先行させない。次の小さな未見比較で案内が既存構造/代替案と反対材料を考えるために実際に使われたか、余計な候補を読む負担を記録する。寄与が得られなければ同じ入口を繰り返し調整せず、用途限定/撤退の判断を通知する。

対象OSSはread only、対象code/build/test/script/checkout/投稿なし。rawsource/diff/生出力/生レビューはignored、公開はown code/位置/count/hash/所見。既読・実装者点検を独立した未見評価として扱わない。
