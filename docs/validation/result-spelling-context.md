# 戻り値名/call表記から既存producerへ（#93）

目的は、局所追加を既存構造へどう組み込むか考えるとき、直接呼んでいない既存処理にも比較の入口を作ること。[判断0045](../decisions/0045-written-result-relations.md)。型・callee・constructor・引数値・責務や統合の必要性は未解決。この実装検証を有用性の成功にしない。

## 入力と確認状態

2026-10-04、base `3e374a3`から#93で作業。本番CLI/依存は変更せず実験packageのみを更新。Swift 6.4 / SwiftSyntax 604.0.0。自分のtracked packageを一時archiveし、変更ファイルのみを重ねてテストした。第三者code/script/build/testは実行せず、[Holdout manifest](../../Experiments/StructuralContext/Holdout/inputs.json)の3,026入力を一覧/サイズ/SHA照合後に読み取る。

合成85テストが成功。既存71対照と新14対照で、tuple/単一/generic戻り値、unqualified/明示ラベル、旧call再掲/対応不明、known generic/associated/Self/value binding、alias/qualified/SDK/同名競合、default/local宣言本文の除外、全宣言/祖先不変、一意対応、両側の条件/件数、共通targetキー/上限、入力順/JSON roundtrip/textを確認。CLI13例はJSON二回一致・位置と表示・入力エラーを確認。構文が有効でもtypecheckを要求しない合成例であり、実型解決のテストではない。

## 既知4PRへの回帰

#91の診断で仮説を選んだ**既知入力**。未見の有用性・precision/recall評価ではない。修正後の同じfrozen binary（SHA256 `b403f914b496b93d77f484a04fcf498a6b972a6300ed6f36a969811505612a73`）でJSON/text各二回、終了コード/stdout/stderrが一致。旧経路の全候補/根拠・旧理由件数・変更関数/型注釈/対応外件数を前回と照合し、新callのformフィールドを除いて不変。候補/根拠の省略は全て0。

| 既知PR | 変更前の候補/根拠 | 新経路の候補/根拠 | 意味 |
| --- | ---: | ---: | --- |
| Collections725 | 0 / 0 | 0 / 0 | typo/docの負担未確認という旧レビューを上書きしない |
| Collections724 | 4 / 9 | 4 / 9 | 寿命/共有append先例への未到達はこの仮説の範囲外 |
| GRDB1864 | 0 / 0 | 0 / 0 | hook/property/authorizer/deliveryへ未到達 |
| GRDB1858 | 1 / 1 | 2 / 3 | SQL helperに加えて既存insert executor1候補/二経路 |

修正後もGRDB1858の`InsertionSuccess(rowID:rowIDColumn:persistenceContainer:)`から、未変更`insertAndFetchWithoutCallbacks`のcall670–673へ二経路を得た。宣言は属性込み641–675（func行642）。新plain upsert447–522は旧caller対応不明、call495–498・適格二出現の最初。変更fetch upsert526–621はpaired/token-absent、call615–618・一出現。旧insertの同名callは一出現。既存SQL helperと別の候補に統合される。

このinsert executorは#87の普通の追加検索で共有配置の先例として既に使われた。今回の機械出力はその既知位置への接点を再現する。callが返す実型や処理の等価性、rowID/cursor/error policyの同一性は解析しない。配置比較に必要な理由は通常sourceへ戻す。

## 独立レビューと修正

独立コードレビューで、同名member function/enum caseのknown value bindingが除外されない穴を確認。関数名・variable pattern（tupleを含む）・enum case名をdirect scope索引へ統合し、split extension/全fileの値名とbody/closure bindingも保守的に除外するよう修正。実callee判定を足さない。textの範囲列挙にも新経路を統合。修正後、両側のmember/enum bindingとtuple/split extension/closure capture・positiveの8対照、入力順反転JSON、20回の実行出力を独立点検し、未解消指摘なし。

自己利用後の共通化を独立増分レビューし、旧新WrittenCallSearchの11合成対照でJSON/anchors/stable理由がbyte一致。local protocolの名前除外も確認。整理後の85テスト/13 CLIと既知4PRも再実行し、四件のJSON/textが前述のbinding修正後と同一。未解消指摘なし。

過去#91の診断JSONを現在のauditで再計算し、公開resultsとbyte一致。library変更後のHEAD検証と過去結果の再現を混同しないため、診断builderは`--source-ref`を明示可能にした。過去索引のschema読取りだけを保持し、旧call inventoryをlibraryへ併存させない。

## 自己利用・Actions・次の判断

自己利用の初稿はbase `3e374a3`→`cfe5367`、同じ本番binaryをbaseline/candidateへ使用。モデル/API変更と本文未比較を入口にし、Python/docs/テストは普通diffへ戻った。固定試作はroot/experiment/diagnostic Swift24→26入力に4候補/14根拠（JSON/text各二回一致）。hasUnambiguousDeclarationContext/InventoryTypeName/SourceSite/WrittenConditionalBranchを読む入口になった。既存対応判定への4call位置と普通diffを照らすと、入口/targetの一意性と字句header判定が同じだったため`counterpart`へ共通化した。Sekkaが重複や設計不良を自動検出したとはしない。整理後`c329c3d`で自己利用を再実行し、同じ24→26入力の4候補/12根拠を確認。対応判定の4call入口が2にまとまり、型注釈からmodel再利用へ進む位置は維持。新result経路自体による独自の構造問題の発見はない。同じ本番binaryのbaseline/candidate一致、試作のJSON/text各二回一致を確認。

必須Actions・実コメント/10成果物の照合は未完了。M3/本番統合は保留。事実性と既知到達を確認できた場合だけ別の固定比較を分解し、一般的な結果名から無関係なproducerへ広がるか、必要な先例を読み忘れにくくするかを確認する。人間の判断待ちはない。
