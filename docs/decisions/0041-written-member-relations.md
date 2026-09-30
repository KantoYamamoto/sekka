# 0041: 宣言の対応とmember表記の関係を分ける

**型や旧callerを同定できない場合は、書かれた名前・ラベル列と未変更宣言への位置を、意味解決の不明と一緒に示す。分割extensionではblockではなく一意な宣言キーを比較する。**

- 記録日: 2026-10-01
- 状態: 実験採用。0040の#83で採った「同一extension blockが複数なら子も全て対応不明」はこの記録へ置換

## 目的・What

通常diffを読む際に必要な未変更実装へ、再現できる根拠で辿る。Collections #728ではFilter.generateのsignature変更と、OutputSpanの分割extensionが入口/候補の対応を阻んでいた。

member表記を同じ宣言一覧の第三の根拠経路にする。型を確定した経路と同じ強さにはしない。afterの名前/ラベル列と一致する索引内関数を、変更済み/新規も含めて数える。複数なら一方を選ばない。一件でも実calleeの一意性ではなく、未索引/SDK/default引数/overload等は不明。

## Why / Why not

対応させたいのは同じ字句条件下の関数宣言であり、extension blockの実体ではない。同じheaderで複数blockへ分ける一般的な書き方を全て落とすと、位置/宣言トークンが一意でも既存helperへ届かない。完全な関数キーが各版一件なら対応できる。nominal/条件blockの曖昧さと重複関数は保持する。

callerの一意対応を必須にすると、返却型が変わっただけで本文の接点を失う。一方、対応するcallerの全旧callを再掲すると、別処理が変わっただけでも無関係なcallが増える。pairedでは旧本文にないcallトークンだけ、unpairedでは対応不明の弱い入口として本文の表記を示す。

名前だけの類似、責務や統合を推論する警告、実calleeへの昇格は採らない。型解決を完備する方式は未実装で、対象buildなしの今の試作には不明が残る。出力の弱い関係が負担ならこの経路を保留/撤去する。

## How / 境界

SourceInventoryに明示ラベル付きmember callと全字句祖先headerを保持する。収集はdefer/if/closureも読むがlocal関数/型の本文は除外。初回のtrailing closure/unqualified/specialized callは対象外。

MemberSpellingContextが差分の適格性で出現を絞り、caller/selector/receiverごとに最初の位置と件数を示す。候補はbodyと、旧新の一意な対応・全祖先header・宣言トークンの一致を必要とする。UnchangedContext/TextContextは同じ候補/上限へ根拠を統合する。

## 根拠と再検討

63テスト・11 CLI対照・独立コードレビューで事実性を確認。既知Collectionsで_removeへ到達、GRDBでOrderedDictionary.appendValueへ到達した。これは既知回帰であり、配置変更の必要性や未見の有効性を証明しない。[検証](../validation/member-spelling-context.md)。M3は保留し、次は方式を固定した独立比較を行う。
