# 変更宣言からの接点検索: 別2変更の独立比較

**結果：比較先への案内は得られたが、配置を見直す中心的な根拠は通常のソース読解から得た。本番へは採用せず、検索の起点を参照の前後差へ変更する。** #10の検証記録。2026-09-13。

## 固定した条件

抽出器は`c0eb0b3f783262d0c43c1f189c338174725d584b`、Swift 6.3.3。バイナリSHA-256は`ee271313751b49c0f2e5c38828e5ccea0d684f7bbcbf5ff36fc97985ff5b97b2`。評価中は実装・閾値を変更していない。後続のPR #65のコミットは文書と成果物保存の変更だけ。

入力は[retrieval-inputs.json](../../Experiments/StructuralContext/retrieval-inputs.json)でbase/head、path、blob、サイズ、SHA-256を固定。108 side/blob、64 unique blobs。Swiftは100 side/file、非Swiftは8。PRの題名と変更ファイル情報から、既存logging系への新handler追加と共通clock導入を選び、本文・ソース・抽出結果は選択後に取得した。ランダム標本ではなく、後続修正やレビューコメントで正解を選んでもいない。既知WordPress/Nukeを未見例として再利用しない。

| 入力 | base → head | 範囲 |
| --- | --- | --- |
| [Swift Log #390](https://github.com/apple/swift-log/pull/390) | `3612813963f8f3ec777e6110e2bb749252b29ac4` → `9a8c50753a41b413017bc9e09366620f4a59e80b` | 全変更5ファイル + Sources配下のSwift。Swift 5→7ファイル |
| [Alamofire #4051](https://github.com/Alamofire/Alamofire/pull/4051) | `5c393d870fda646c519a10f9792c68e10490a4da` → `9490009365c90746782b6b7d1770c5c8637057a8` | 全変更7ファイル + Source配下のSwift。Swift 43→45ファイル |

両担当へ同じ固定diff・周辺ソースを供給。Aは通常diff/ソース、Bはcontext.textだけのcheckpointを保存した後に同じdiff/ソース。両者とも最後にPR本文を読み、要件による問いの変化を追記した。他担当の結果・抽出実装・後続PRは読んでいない。BはJSONを使用していない。各入力最大3個の配置の問い、現配置の反対根拠、未確認要件を記録した。

外部取得はGETのみ。対象ソースのビルド/実行・外部投稿は一切しない。生レビュー・第三者ソース・packetはGit管理外の`.build/change-context-holdout`。packetファイル一覧のSHA-256は`8e2fdae427eee8a27550c15aa05e16587845f9df0ba9d1a328d14fd750d0cb02`。使用量制限による長い中断を挟んだため、経過時間はレビュー速度の評価に使用しない。

## 観測と読む負担

| 入力 | contexts / selector groups | text bytes | JSON bytes | 全変更ordinary diff bytes |
| --- | --- | ---: | ---: | ---: |
| Swift Log | 6 / 4 | 7,669 | 14,275 | 9,317 |
| Alamofire | 4 / 3 | 15,874 | 27,362 | 20,471 |

diffは固定blobから生成し非Swiftも含む。これは情報量やレビュー時間の比率ではない。試作はSwiftしか解析せず、PR本文も解釈しない。

## 問いの出所と反対根拠

| 問い | 機械出力の寄与 | 通常読解で初めて得た根拠 / 現配置を支持する条件 |
| --- | --- | --- |
| 新handlerのmetadata方針を既存handlerと揃えるか | 既存log候補への弱い案内 | 新handlerはprovider→handler→call、Stream側はhandler→provider→call。両担当がソースから発見。新テストは新しい順序を意図しており、全handler共通契約は未確認。単純にhelperを移すべきとは言えない |
| 収集store・別productをどう分けるか | 新handlerとネストしたstoreへの案内 | 値型の設定と共有参照storeの境界、Mutex/availabilityとproduct依存はソース由来。PR本文は独立productを明示し、現在の配置を支持。公開storeへの拡張要求はない |
| Data/Downloadの計測を共通層へ上げるか | 両_responseと非serializer版への比較導線が実際に役立った | 通常読解ではserialize本体だけを測りqueue待ちを含めない現配置を支持。共通call表記が多いだけで上位へ移すと意味を変え得る |
| 共通clock導入の範囲にWebSocketを含めるか | 残存参照は出力されない | after `Source/Core/WebSocketRequest.swift:286,296`にsystemUptimeが残る。両担当がソースから発見。PR本文のAPI排除目的で確認価値が強まった。条件付きexperimental SPIであり、配布範囲や外部規則の適用は未確認 |
| 認証履歴を時点型にするか | refresh周辺への位置案内 | Instant.valueをTimeIntervalへ戻す境界はソース由来。API置換が目的なら既存private履歴の維持で足り得る。型の強化は必須要件ではない |

主な位置は新handlerの`Sources/InMemoryLogging/InMemoryLogHandler.swift:106–112`、既存`Sources/Logging/Logging.swift:1527–1552`、Alamofireの`Source/Core/DataRequest.swift:249–268`、`DownloadRequest.swift:378–397`、`Source/Features/AuthenticationInterceptor.swift:391,412–419`。位置は固定head側。PR要件を読んだ後の強い問いを、機械出力だけで発見した問いへ遡及しない。

## 判断と次の検証

#63の接点は索引以上の比較を促す場面が一つあったが、通常diff側でも主要な問いへ届いた。固有の見落とし削減や速度効果は確認できない。common API・同名テストの混入と出力の長さも残る。2例から全PRの有用性や精度は推定しない。

[0037](../decisions/0037-reference-delta.md)と[#66](https://github.com/KantoYamamoto/sekka/issues/66)で、変更後宣言のcall集合全体を入口にする方式から、**減った参照表記が変更後のどこに残るか**を入口にする方式へ置換する。call以外のmember accessも扱い、適用範囲を問い直す位置を示す。今回のAlamofireは以後既知材料で、同じ例を捉えても未見成功ではない。metadataの優先順位や別SDK間の責務推論を解決したとはしない。

## 再現

固定commitの`Experiments/StructuralContext`を別ディレクトリへ取り出してbuildし、同commitの`fetch.py --manifest PATH/TO/retrieval-inputs.json --output FRESH_DIR`で入力を取得する。各caseのbefore/afterへ`context-probe BEFORE AFTER`と末尾`--text`を実行する。対象OSS自体は実行しない。manifest内の非Swiftは通常diff用であり抽出器は読まない。生レビューは公開せず、上記はその条件と所見の要約である。
