# 必要な差分外実装と検索条件を照合する

2026-10-02、M2 #91。[0044](../decisions/0044-existing-result-producers.md)。**callee/型の宣言へ辿るだけでは、既存の共有方針を実装した場所へ届かない例があった。次は同じ戻り値名/call表記を持つ未変更producerとの関係を、一つの仮説として実装する。** 本番採用や未見の有用性合格ではない。

## 固定した資料と方法

#87の独立A/Bとsource読解で必要だった23位置を、診断出力前に[needs](../../Experiments/StructuralContext/Diagnostics/needs.json)へ固定。Collections724が10、GRDB1858が8、GRDB1864が5、Collections725は追加の構造負担を示さなかった負の事例。位置集合は必要な差分外資料の一部であり、網羅的正解集合/recallの分母ではない。

着手はbase `66089ff`、[Issue checkpoint](https://github.com/KantoYamamoto/sekka/issues/91#issuecomment-5934110774)。基準検索は#90最終binary `88816fce…`、library tree/入力manifest/必要位置/診断body/binary/各index/結果のhashは[公開checkpoint](../../Experiments/StructuralContext/Diagnostics/checkpoint.json)。自分のtracked packageの一時コピーへ診断entryを合成し、libraryと通常CLIを変更していない。

3,026入力の全一覧/SHAを照合してから、自分の解析器でbefore/afterを読む。全四件の診断JSON/終了コード/stderrを二回実行しbyte一致を確認。対象OSSのcheckout/build/test/script・投稿は行っていない。第三者body/callトークンを含むraw indexはignored `.build/context-misses`。公開[結果](../../Experiments/StructuralContext/Diagnostics/results.json)は位置・selector・件数などに限定した。

## 現在の検索が届かない理由

23位置には選択済みcontextとの交差がなかった。ただし、calleeの候補が存在しないことや全体の網羅率を意味しない。索引宣言が必要な範囲と交差しても、その契約を解析したわけではない。candidate上限による省略は四件とも0で、単に上限を増やして届く問題ではなかった。

| 必要な場所 | 診断で得た根拠 | 現在の範囲で足りないこと |
| --- | --- | --- |
| #724 Utilitiesのraw append/adapter | 二つの未変更関数は索引にあるが同じ`_append(moving:)`宣言は3件、適格な完全ラベル表記の入口は0 | 既存の共有処理/consumerを読む関係がなく、callee一意性を緩めるだけでは届かない |
| #724 InputSpan側append adapter | declarationは属性順変更、bodyはtoken-identical | whole-declaration未変更の候補条件に合わない。bodyだけ同じ状態と区別する |
| #724 `_ptr(at:)` | 必要な関数は未変更。適格な表記8出現に対し同ラベル宣言3件 | 実callee不明のため一件へ選べない |
| #724 MutableContainer要件 | 必要な二要件はbodyless。表記の入口は2/1出現、同ラベル宣言は各8件 | 実際には先に一意性で退ける。bodylessも現候補範囲外だが、順序を逆に原因帰属しない |
| #1858 insert executor | 未変更の関数とbodyは索引にあり、同ラベル宣言1件。適格なmember表記入口0 | 同じ結果組立ての先例へは、呼び出し先としての一致では辿れない |
| #1858 result/callback/schema | 結果型・property・bodyless要件は索引に存在 | 新しいproperty型注釈/適格なmember callだけを入口にする範囲では、この結果・metadata契約を選ばない |
| #1858 DAO renderer | 未変更関数・同ラベル1件だが入口0 | 選択済みSQL helper内の接点を更に追う検索ではない |
| #1864 hook/property/authorizer/delivery | property、type、未変更delivery関数等が索引にある。該当関数への適格な入口0 | 型全体の不変と各memberの不変は別。broker全体は変更済みでもdelivery関数は未変更。今回の変更anchorから必要な境界へ直接の経路がない |

InputSpan/Producerの不変条件の文書やinit等は、必要な行と索引関数の境界が一致しないものもあった。構文索引に入らない資料を「候補なしで妥当」と扱わない。protocol本文、property、契約の文書は、実装関数とは別の確認先である。

## 別の検索単位を探索した結果

必要な関数を対象として、変更anchorから(1)同じcall表記を使う未変更consumer、(2)同じ字句headerとbasenameのAPI familyを試した。これは必要位置が分かった後の探索で、未見実験ではない。

| 入力 | 無条件の共有call表記の組 | 戻り値名で絞った組 | 未変更API familyとの組 |
| --- | ---: | ---: | ---: |
| Collections725 | 0 | 0 | 0 |
| Collections724 | 44 | 0 | 4 |
| GRDB1864 | 0 | 0 | 0 |
| GRDB1858 | 3 | 2 | 0 |

共有callの二列は(target関数, 変更anchor, call表記)の組、family列は(target関数, 変更anchor)の組。candidate数/品質/削減率ではない。44組にはassert/preconditionやbuffer access等の広い一致があり、責務の同一性へ昇格させない。familyは未変更targetに限定し、自分自身を除外した。#724の4組は未変更Utilities二関数×変更anchor二関数。属性変更のInputSpan adapterを第三の未変更先例として数えていない。

ノイズを確認した**後**に、両callerの明示戻り値に書かれた名前で、同名の索引宣言が1件あるunqualified/nontrailingのcallへ絞った。戻り値名はASTのIdentifierType表記で、generic/alias/value bindingや実initializer/型同一性は解決していない。ここを今後の実装契約で限定する。

#1858で同じ`InsertionSuccess(rowID:rowIDColumn:persistenceContainer:)`表記から、未変更`insertAndFetchWithoutCallbacks`（Insert642–675、call670–673）へ二経路を得た。新plain executor447–522は旧caller対応不明・二出現の最初495–498、既存fetch executor526–621はpaired/token-absent・一出現615–618。**二つのtargetではなく、一つの既存producerへの二経路。** 同じ結果や同じ挙動の反復の証明ではない。

その既存insert executorは#87の普通の追加検索で、record操作層に共有実行を置く先例として使われた。診断はその位置との機械的接点を確認しただけで、新しく構造問題を発見したとはしない。SQL helperと別にこの先例を示せることが、次の限定仮説を選ぶ理由。

この案は#724のlifetime/要件や#1864のhook境界へ届かない。family等を同時に足さず、一つの仮説を検証する。本番/M3は保留。

## 実装・レビュー・自己利用

診断helperは自分のtracked-source archiveからビルドし、tuple/genericの表記とcaller位置、parameter default/header・local型の初期値をbodyへ混ぜない判定、JSON/終了コード/stderr二回一致、不正構文の部分出力拒否を確認。全AST dumpと検索のbody-owned観測を分けた。full ASTをそのまま経路に昇格させる案を採っていない。

独立レビューでfamilyがchanged adapter自身を含む点とfull ASTのcaller帰属範囲を点検し、未変更target/self除外・body-owned判定を実装して再実行。必要先/3,026入力の一覧・長さ・SHA、最終body/binary/index/metadataのhash、原因の順序と発見の帰属を独立照合。別のaudit実行も公開結果とbyte一致し、未解消の指摘はなかった。

自己利用はbase `66089ff`→診断実装`760e7a7`で、本番Sekkaと固定試作を使用。本番は新しい診断型を確認する入口として使い、型モデル/API境界と未比較本文を通常diff/sourceで点検した。試作の23→24 sourceには診断Swiftも含め、既存InventoryScope/Function/Declaration/Propertyへの型注釈入口4件/4経路が出た。既存model再利用の位置確認にはなるが、新しい構造判断の材料はなかった。試作のJSON/text二回一致、本番baseline/candidateの同一出力を確認。本番の機能改善とはしない。

必須Actions・実PRコメント/成果物は記録PRの完了時に照合する。次の実装/別の固定比較を別Issueに分け、この既知四件を未見として再採点しない。人間判断待ちはない。
