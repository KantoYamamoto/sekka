# 減った利用と残る窓口の原因診断（#96）

**必要先へ届かなかった場合は、候補経路を足す前に、変更前に使っていた既存窓口を確認する。** #95の同じ4PRを使う既読診断であり、未見のレビュー利益を測っていない。[固定条件と再現](../../Experiments/StructuralContext/WithdrawnEntry/README.md)、[判断0046](../decisions/0046-withdrawn-entry-context.md)。

## 固定したものと観測

raw A/Bで実際に必要だった58の読み取り位置を先に固定した。構造の先例1、挙動確認35、変更宣言の部分/コメント/条件、production索引外testを分ける。幅を持つ位置は読取範囲であり、完全な宣言extentや網羅的正解集合ではない。文脈だけの確認先と未検証SDKは必要集合へ混ぜない。独立レビューで6件のreview行参照を訂正し、元の凍結値と訂正receiptを残した。対象位置/用途/条件は変えていない。

| 既知PR | 減少selector（組） | 不変の同形宣言候補（件） | 必要位置に交差する候補 |
| --- | ---: | ---: | --- |
| Collections723 | 38 | 4 | copy先例、gap cleanupの2件 |
| Collections721 | 0 | 0 | なし。変更コメントの引数照合は同じ宣言の部分 |
| GRDB1852 | 4 | 0 | なし |
| GRDB1850 | 0 | 0 | なし。条件/importとtest注釈の確認先は別関係 |

全42減少groupの件数/form/status/occurrence hashを残し、候補を絞るためのcapは使わない。適格4候補は全利用位置・条件位置を公開し、不適格38groupの全位置はreceiptにboundしたprivate indexから再現する。同形宣言非一意は「0件」も含むため、同名競合だけの件数ではない。件数はproduction索引関数bodyのmember/unqualified/nontrailing表記であり、リポジトリ全callや実callee数ではない。宣言のtoken/字句条件不変もコンパイル構成の有効性を保証しない。

## 到達と不要な接続

Collections723の`_copyContents(into:)`は記載利用4→0、索引内宣言は前後1件ずつで不変。旧RigidDequeの利用367/451、UniqueDequeの297/499から、未変更`InternalCollectionsUtilities/BorrowingIteratorProtocol+Extras.swift:34–47`へ進める。このhelperは#95の通常diff担当が、短いspanを繰り返す責務と操作後の個数/終端検査の分担に使った先例。現after入口の不足を示す材料にはなるが、この既読診断で新しい構造の問いを発見したとはしない。型条件・callback間のiterator保持・提供条件・性能の成立は未検証。

`_resizeGap(in:to:)`は3→2、未変更`BasicContainers/RigidArray/RigidArray.swift:473–491`へ到達し、部分初期化後のcleanupを確認した必要位置に交差する。挙動確認であり構造再配置の根拠ではない。旧利用のcaller対応には曖昧さがあり、具体的なrename/移行対応を断定しない。

残りは`deinitialize()`（23→22）と`mutablePtr(at:)`（14→13）。前者はArrayのbuffer等とDeque segmentの同名を混ぜ、すべてを同一calleeへ繋げられない。減少数1からどのcallが意味上消えたかも確定できない。後者はDeque handleへの利用として文脈を読めるが、#95の必要集合や反復負担/別配置の根拠にはない。**4件全体を有用な関係として採点しない。** 合成SDK同名対照でも構文候補は残るため、実型未解決のまま誤接続を完全には除けない。

残る必要先は、selector数が減っていない、property/deinit/initializer/条件/コメントなど索引関数のcall関係ではない、testがproduction prefix外、と分ける。source範囲との交差は必要な本文をすべて解析した証明ではなく、到達率/recallへ換算しない。

## 検証と限定

全入力bytes/blobを照合し、元の診断の成功4caseはexit/stdout/stderr二回一致。自分の25対照は全削除、移動/rename/署名、同名SDK、helper削除/変更、条件/false節/先行else条件、ancestor header、本文なし、曖昧/overload、本文境界/trailing/specialized、0、parse/read/symlink/missing-directoryを含む。失敗も二回比較しstdoutの部分成功を拒否する。独立指摘を受け、集計前に実行receipt、全4case、exit/全bytes一致、manifest/binary/runner/実stdout・stderr hashを必須照合し、12の正常/欠落/改変対照を追加した（計37）。receipt自体は暗号署名された実行証明ではなく、保存素材との整合確認である。

元のmissing-directory対照はFoundationのメモリアドレスでstderr不一致だった。診断catchを安定したdomain/codeへ修正した。元の失敗のhashと修正後の凍結記録を分け、後処理による一致は採らない。実験context-probeにも再現した問題は#98へ分離し、この診断中のruntime方式は変更しない。

自己利用（base `78e0b4d` → `42ea458`）はSwift変更1を読む入口にはなったが観測0。変更がtop-level catchのため、6 indexed bodyがtoken同一と出る。本体比較の範囲外である今回の失敗表示変更は通常diffと対照で確かめた。独立した有用性や全体の整合性確認とはしない。

修正後binaryでも全4caseを二回実行し、元の成功時dumpと全bytes同一だった。集計も二回一致。独立診断レビューで全3,006 entries、42group/4候補、58必要位置、全索引callのAST body境界、元の失敗と最終出力を点検し、未解消の修正要求なし。公開版は独立再生成とも全bytes一致。[独立receipt](../../Experiments/StructuralContext/WithdrawnEntry/independent-review.json)。[PR #99](https://github.com/KantoYamamoto/sekka/pull/99)の最終Actions [37183945478](https://github.com/KantoYamamoto/sekka/actions/runs/37183945478)は成功。実Botコメントと10成果物を照合し、merge `8409378`で完了した。

## 次の分岐

4caseの構文事実として「使わなくなる窓口」への入口は成立した。一例への到達だけで実装採用せず、独立点検で事実性/不要接続を確認する。本番統合/M3は保留。次の単位は先に#98の失敗出力境界、その後に#100で既存call入口を前後両側の共有契約へ組み直す。必要だった先例と未解決を同じ候補一覧で読めるようにし、別検出器の継ぎ足しと比較する。既読4caseを新しい有用性評価へ読み替えず、原型のLogger/Analytics全般の解決と呼ばない。
