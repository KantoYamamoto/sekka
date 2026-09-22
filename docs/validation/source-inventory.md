# 明示型と宣言候補の構文索引

#73（M1 #69）、2026-09-14。新しい検索の前提となるlibrary API。**この記録は索引だけを作った時点の結果。後続の検索は[#74の記録](unchanged-context.md)を参照。本番CLIへの採用と実用性は未確立。**

## 実装と範囲

実験packageのSourceInventoryが、型・member関数・propertyの明示型・署名/本文表記・位置を保持する。memberCandidateはcaller/receiver/selectorを与えて、同じownerの明示型付きpropertyと関数候補を辿る。候補を返しても、実際の呼び出し先・依存・役割を解決したとはしない。queryに渡したcall自体が存在するか、追加と関連するかは次の検索側の責任。

最初は単純な明示型と、継承/準拠/属性/generic等を持たない型に限定。同名型/関数、alias、extension、protocol、optional/qualified/generic型、static/computed/属性付きproperty、closure scope等は理由を返す。parameter/local宣言のshadowingは関数全体で保守的に拒否する。明示selfの場合はlocalの同名をpropertyのshadowとしない。正確な実行時scope解析は行わない。

前後の経路確認に必要なproperty表記/型/候補ID/型header/関数本文/位置を保持する。型IDが同じでもstruct→class等のheader変更を比較できる。型が変わってもcall表記が同じだから同一経路とはしない。ファイル内の行移動で本文が同じならIDと本文を比較でき、位置は各snapshotから取る。曖昧な同名キーを出現順で対応させない。

SourceSiteとContextErrorは既存参照差から共通モデルへ移動。既存CLIの挙動はこのPRで変更せず、#74で索引を使った検索へ置換し旧方式を撤去する。三つ目の常設CLIや新しい依存ライブラリは追加しない。

実装者の再読で、暗黙のcatch error bindingと、既定引数を省略できる別overloadの取り逃しを補正した。catch内のerrorはlocal名へ加え、同名memberに既定/可変長引数がある場合はselectorが一見一致しても未対応理由を返す。構文上の候補を安易に一意としないための保守的な境界。

独立レビューで、未展開macroや別宣言のpeer属性が候補の一意性を崩せる箇所を修正した。member/global展開と属性付き宣言の影響範囲を拒否し、関数内の展開・属性付き局所宣言も拒否する。既知の組み込み属性とmacroを型解決なしで識別していないため、属性を含むscope全体に保守的な拒否が広がる。この適用範囲の狭さは次段階でも隠さず記録する。

## 検証

索引用17テストと既存18テストが成功。明示型/位置、同名型/overload、alias/extension/継承、parameter/local/type shadow、closure/条件付き、optional/inferred/generic/protocol、static/computed/属性、同一ファイル/位置移動、property型/let-var変更、global/local除外、重複property/caller、入力順/構文失敗/重複pathを確認した。記録はGit管理外の`.build/milestones/index-tests-final.log`。

この段階で未知のOSSに対する有用性や実callee解決を証明したとはしない。次の#74で構文上の関連候補、前後経路と未変更本文、集約/表示を実装する。独立レビュー・自己利用・最終Actionsの結果はIssue/PRに紐付けて記録する。

## 独立レビューと自己利用

独立レビューでmacroが宣言/局所bindingを増やすscopeの一意性を修正し、再確認で属性付き局所宣言の残りも修正した。最終の重点再確認で追加の必須修正なし。生記録は`.build/milestones/index-review.md`。

本番Sekkaで`4cc794f15369484c0b02f2d0c767ec99301b1e19`→`b19ba9d0138cd322fb6066d9e232904fba84a54e`を比較。9path/4Swift/13観測/35本体未比較。共通モデルの移動と索引の追加は案内され、トップレベルテストは通常diffで確認した。catch/default引数は実装者の再読、macroの一意性は独立コードレビュー由来でありSekkaの発見とはしない。

新旧の本番バイナリは同一、full JSONも一致。既存ReferenceDeltaの17本体はtoken-identical。結果は`.build/self-review/source-inventory-reviewed`。後続の文書だけの記録では再実行しない。次の#74では属性やmacroによるscope全体の拒否も出力の不明範囲に残し、対象外が多すぎる場合はM1の終了時に方式を見直す。
