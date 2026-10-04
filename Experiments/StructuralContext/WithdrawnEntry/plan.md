# #96: 減った記載利用と残る窓口の原因診断（実行前固定）

こういう場合はこうする：afterのcallから必要先へ届かない場合は、before/afterの記載selector数と残る宣言を照合し、入口の不足と同名の不要先を分ける。

## 入力・必要先

#95のResultHoldout/inputs.jsonの4case全体を同じproduction prefixで読む。差し替え・対象のビルド/実行なし。既読の原因診断であり、新しい有用性評価ではない。必要位置/用途はraw A/Bの必要先の表と保存sourceからneeds.jsonへ出力前に固定する。文脈だけの位置は必要集合に混ぜない。変更宣言内の未変更部分、条件が変わるbody、索引外のtest/SDKを分ける。位置の集合は網羅的正解ではない。

現在のSourceInventory.functions[].writtenCalls（body内member/unqualified、nontrailing）を使う。既存Diagnosticsのown temporary-copy reader/dumpを再利用し、runtime/library/通常context-probeは変更しない。全ASTのcallsは形式とbody境界の不足確認だけに使い、検索入口へ混ぜない。

## 固定する仮説

1. 同じ記載selectorの索引内出現数を全before/afterで数える。form別の数も保存し、before > afterだけを減少groupとする。移動で位置が変わっただけの表記を減少にしない。実callee数・意味上の対応ではない。
2. 減少selectorと同形の索引関数を全件照合する。両側1件ずつ、bodyあり、correspondenceID一意、宣言context不曖昧、宣言tokensと字句祖先header同一の場合だけ、残る未変更候補とする。宣言なし/複数/変更/条件・header差/本文なし/対応不明を記録する。適格候補だけでなく全減少groupを保存し、capをかけない。
3. 利用元の位置とform・条件を保持する。対応keyがないことを「削除」と断定しない。同じdeclaration tokensが他位置に残る、同selectorが残る、一意対応が変化、条件header変化、曖昧を区別し、rename/移行/receiver実型を推測しない。
4. needsの位置との交差は案内先への到達の材料だけ。構造の問いに使われた先、挙動確認先、変更宣言の部分、条件変更先を別集計する。関連性はsourceへ戻って確認し、同名SDK/別receiverの候補を棄却する。必要先との交差率をrecallや実用性の合格値にしない。

## 対照・分岐

自分の合成Swiftで全削除call、移動/rename・署名変更、同名SDK、helper削除/変更、条件変更/false節、曖昧対応、local/default/trailing/specialized、0/読み取り・parse失敗を検証する。同じ入力/設定からexit/stdout/stderr全bytesを二回比較し、失敗の部分成功を拒否する。SDK同名の適格構文候補が残る場合も実関係の成功に数えない。

必要先と事実性/ノイズの理由が追跡できれば次の実装または追加診断だけを分解する。必要先へ届かない、同名が多い、入口対応を捏造する必要があるなら実装せず仮説へ戻す。score・API family・型解決・result条件緩和を同時に追加しない。原型のLogger/Analytics全般の解決とはしない。本番統合/M3は保留。

生source/diff/dump/reviewsはignored、公開は位置/selector/count/hash・自分の診断codeと判断だけ。実装者点検と独立レビュー、Actions/実コメント/成果物を分けて記録する。
