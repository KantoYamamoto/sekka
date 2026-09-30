# member表記から未変更の宣言へ辿る

2026-10-01、M2 #85。**既存helperへの接点を、旧callerの対応やreceiver型の確定とは分けた。固定済みCollections #728で、通常レビューが必要とした未変更`OutputSpan._remove(from:where:)`へ初めて到達した。既知回帰の成立であり、根本的な配置見直しへの寄与は未検証。**

## 何を見直したか

[0041](../decisions/0041-written-member-relations.md)に契約と理由を記録した。分割extensionのblock同一性ではなく、各版に一件だけ存在する完全な関数キーを対応させる。同じheaderのextensionが複数あっても、異なる関数は比較できる。nominal/条件blockや完全キーの重複は引き続き不明とする。候補には全字句祖先headerと宣言トークンの一致も必要。

変更fileのafter関数で旧索引に同じ宣言トークンがないものから、本文のmember表記を読む。callerが一意対応する場合は旧本文にないcallトークンだけ。対応不明なら本文に書かれた接点を示すが、新規callとは言わない。名前と明示ラベル列が一致する全after関数を数え、変更済み/新規を含め一件の場合だけ未変更宣言を候補にする。receiver型、default引数やoverloadの適用可能性、SDK/索引外を解決した結果ではない。

第三の根拠経路として既存contexts/上限へ統合した。別の候補一覧やCLIは増やさない。本番CLIは変更していない。

## 事実性と負の対照

実験packageは63テスト成功。10個の追加対照で、signature変更/対応不明、旧callの再掲防止、適格性で絞ってから最初の位置/件数を数えること、変更済み/新規の同形競合、全祖先header、nominal/条件重複、local本文、default引数の非解決、共通候補への統合・順序・省略を確認した。

CLIは11対照成功。既存7例の件数を維持し、独立Analytics/自然なモデル追加の0件を保った。方針だけ違う同一ソースは同じ出力を返す。独立コードレビューは修正を要する指摘なし。追加の独立probeでもextensionの分割/並べ替え、一意キー重複、defer/if/closureとlocal本文除外、specialized calleeの対象外を確認した。これらは実装契約の検証であり、設計判断の有効性ではない。

## 同じ既知入力を再実行した結果

#77のmanifestと3,008ファイル一覧/ハッシュを照合し、固定4例を各二回実行して終了コード・stdout/stderrの一致を確認した。旧Reach/results.jsonは変更していない。対象OSSのコードやscript/build/testは実行せず、先方へ投稿していない。

| 入力 | 対応内の変更関数 | 対応外 before→after | 未変更の候補 |
| --- | ---: | ---: | --- |
| Collections #728 | 15 | 84→83 | `_remove(from:where:)` 1件 |
| Collections #727 | 1 | 79→79 | 0件 |
| GRDB #1876 | 0 | 88→88 | 0件 |
| GRDB #1869 | 10 | 88→88 | `OrderedDictionary`と`appendValue(_:forKey:)` 2件 |

Collections #728: afterの`Producer+Filter.swift`にある`ConsumingFilterProducer.generate(into:)`のcall行98から、未変更`OutputSpan+Extras.swift`行112–138へ案内した。返却型が変わって旧callerと一意対応しないため、その不明を出力する。#77の機械出力前レビューで必要とされた確認先の一つに当たる。`_consumeAll`のtrailing closureと`_producerBufferSize`のpropertyは今回の経路外。必要な確認先全てへ届いたとはしない。

GRDB #1869: `registerMigration(_:)`行578の新しい表記から、未変更`OrderedDictionary.appendValue(_:forKey:)`行57–61へ案内した。型注釈からOrderedDictionaryへの既存経路も維持した。候補の存在は実calleeや配置変更の必要性を証明しない。Collections #727の契約/補助処理にはまだ届かない。

以前読んだSwiftLog #390 / Alamofire #4051もmanifestで照合して再実行。SwiftLogは`InMemoryLogHandler.log(...)`の`self.metadataProvider?.get()`表記から未変更`Logger.MetadataProvider.get()`へ1件、Alamofireは0件。既存のcall接点/型経路は0を維持した。これも未見比較とは呼ばない。

対応外数の減少は分割extensionの対応契約を見直した結果を含む。変更数・問題数や「改善の大きさ」に使わない。

## 再現・現在位置

ローカル証拠はGit管理外の`.build/member-spelling`。第三者の生ソース/生レビューを公開Gitへ入れない。テスト/CLI出力、独立レビュー、固定入力の結果を保持した。評価器SHA-256は`5376f29bdbfb15a24c150792c43b77da33d53704b65050c0a0adbbd2c2bb7626`。ローカルSwift 6.4 / SwiftSyntax 604.0.0。

再現: 実験READMEのpackage test/verify手順と、Reach/run.pyに#77と同じ入力を渡す。今回の回帰結果は`.build/member-spelling/reach`にあり、初回の公開manifest/resultsと分離した。

自己利用: base `86ca08a`→実装`3236b51`。本番CLIは同一評価器で新旧出力一致。8 Swift変更・16観測・10本体未比較から変更モジュールとテストの通常diffへ進めた。実験にはGitから自分のSourcesと実験Sourcesを20→22ファイル渡し、二回の出力一致を確認。未変更SourceSiteへ型注釈の4入口/1候補、新member表記経路は0件。位置モデルの確認先にはなるが、構造見直しの独自発見とはしない。適格性→集約、一意性の数え方、共通候補/上限への統合は通常diffと独立コードレビューで確認した。

PR #86はhead `2fa2810`で完了、merge `8f722fc`。[Actions36788343971](https://github.com/KantoYamamoto/sekka/actions/runs/36788343971)成功、10成果物のmanifest.headと[実コメントの照合](https://github.com/KantoYamamoto/sekka/pull/86#issuecomment-5921199976)を確認。コメントの単位、実験textの罫線と解決不明の表示を点検した。次は[#87](https://github.com/KantoYamamoto/sekka/issues/87)で評価器を固定し、別の未読PRで独立比較を行う。弱い表記一致が探索に寄与するか、無関係な候補で配置変更へ誘導しないかを評価する。M3は保留、人間の判断待ちはない。
