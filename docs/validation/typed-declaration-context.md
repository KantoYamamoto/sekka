# 型注釈を含む未変更宣言への案内

2026-09-23、M2 #78。[判断0040](../decisions/0040-reach-before-integration.md)。**既知GRDB例で届かなかったOrderedDictionary宣言へ、型注釈から到達した。これは既知入力への回帰確認であり、未見の有用性や配置変更の必要性の証明ではない。** 本番CLIは変更しない。

## 契約と検証

[実装前の契約](https://github.com/KantoYamamoto/sekka/issues/78#issuecomment-5786379823)を独立レビューし、generic引数・qualified表記・同名の旧新対応・未変更の範囲・統合出力の期待を固定した。出力は宣言ごとの`contexts`に、call経路または型注釈経路を種類付きで保持する。別の並列一覧やCLIを増やしていない。

46テスト（既存31＋型経路15）で次を確認した。

- generic/属性/準拠付きのnominal宣言も位置付きで候補にできる。aliasはその宣言で止まり展開しない。
- `Box<A>`→`Box<B>`はB、`Left.Item`→`Right.Item`はRight.Itemという表記から末尾Itemを検索。後者ではLeft.Itemも同名候補に含み得るので、owner解決とは呼ばない。
- optional/array/tupleの内部、generic/associated parameterとSelf、placeholderを区別する。同名別宣言は混ぜず、変更済みや前後不明を分ける。
- nominalとmemberは別候補。同じ宣言へ複数の入口が届いた場合は一件にまとめ、共通の上限・位置・省略を持つ。
- 索引外の旧propertyを不存在と断定しない。未変更の曖昧な型注釈は毎回検索対象外として再掲しない。

独立コードレビューで、protocolのT/Self.Tを同名nominalへ案内する誤り、placeholderと一致なしの混同、旧propertyが索引外なのに「宣言なし」と表示する誤りを修正した。再点検で全指摘の解消を確認した。これは独立した事実性レビューであり、有用性の承認ではない。

CLIは境界対照1・型注釈対照1・既存7例の計9例をJSON/textで確認した。既存Loggerへのcall経路は維持。dispatch-growthでは、以前からあるAnalytics型へ新しいproperty2箇所からも到達し、Logger関数とAnalytics型を別の宣言として表示する。今回増えた候補の根拠は型注釈で、既存の反復箇所を検索する能力を得たとはしない。

## 既知の実入力への回帰

#77のmanifest/入力を変更せず、production prefixだけを解析した。入力一覧/ハッシュを先に照合し、各出力を2回実行して一致を確認した。

| 入力 | 今回 | 範囲と意味 |
| --- | --- | --- |
| GRDB #1869 | struct候補1件・型注釈経路1件 | `Migration/DatabaseMigrator.swift:114`の型注釈から、未変更`Utils/OrderedDictionary.swift:11`へ。同じ名前の宣言候補であり実型解決ではない |
| GRDB #1876 | 正常・0候補 | 誤字修正。0から設計の良否を評価しない |
| Swift Collections #727/#728 | ともに終了2、部分出力なし | 固定parserでの非対応は残る。検索の0件に含めず、失敗ファイルを除外しない |

GRDBのpathは`GRDB/`からの相対位置。以前必要だった実行側の未変更関数への逆引きや、OrderedDictionary内部のどの操作を読むべきかまでは案内していない。型宣言への到達を、通常レビューで挙がった確認先全件への到達や構造の再検討と数えない。以前のSwift Log #390 / Alamofire #4051も再照合し、今回も候補0だった。

再現は[実験README](../../Experiments/StructuralContext/README.md)と[固定入力の手順](../../Experiments/StructuralContext/Reach/README.md)。現在のバイナリをReach/run.pyへ渡した結果は、初回の保存評価器の結果と別ディレクトリへ記録する。生出力はGit管理外の`.build/typed-context/checks.*` / `reach-regression`。第三者ソースの実行や投稿は行わない。

## 実行環境と残り

開発環境はSwift 6.4、parser依存はSwiftSyntax 603.0.1のまま。Documents配下の生成test bundleでFinder metadataによる署名失敗が起きたため、`/tmp`の新規scratch pathで検証し46テストが通った。ソースを署名回避用に変更していない。#77のSwift 6.3.3製固定評価器は別に保存し、結果を上書きしない。

通常diffを読み、共通の宣言一覧へ経路を統合していること、曖昧な名前を意味解決として扱わない境界を確認した。最終Actions/実成果物はPRで確認する。次は解析非対応を独立して扱い、候補へ到達できる条件で確認先選択や配置の問いへの寄与を評価する。既知GRDBでの到達だけでM3へ進めない。

## 自己利用

base `49950b4` → 実装 `993e601ca35b0beacfabca54a59fb59a4d5acb48`。本番CLIの自己利用は12変更ファイルを対象とし、旧新バイナリが同一SHA256で出力も一致。本番の変更検出能力が改善したとはしない。保存先は`.build/self-review/typed-context`。

実験CLIには両版の`Sources`と実験`Sources`だけをGit blobから取り出した19→19ファイルを渡した。未変更の`SourceModel.swift:1`にある`SourceSite`を1候補、14入口（8表示・6省略）として案内した。新しい位置情報モデルが既存の位置表現を使う接点は追える。一方、`ContextEntry`→`CallEntry`の改名でも旧索引との対応が切れ、同じ型名の入口が繰り返された。45型注釈差は意味上の新しい依存45件ではない。

この案内から新たに構造上の問題を発見したわけではない。共通一覧に統合する判断とgeneric/placeholderの誤案内は通常のコード読解・独立レビューによる。次の評価では、到達件数だけでなく改名や広く使う型が生む重複と、構造を再検討する問いへの寄与を分けて確認する。
