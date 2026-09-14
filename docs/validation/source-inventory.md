# 明示型と宣言候補の構文索引

#73（M1 #69）、2026-09-14。新しい検索の前提となるlibrary API。**関連性の検索・本番CLI・実用性の評価はまだない。**

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
