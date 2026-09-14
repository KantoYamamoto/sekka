# 固定した配置抽出を別の実変更で確かめる

2026-09-13、[#62](https://github.com/KantoYamamoto/sekka/issues/62)。#57の抽出器を変更せず、追加実装を既存構造へどう組み込むかという問いへの寄与を調べる。継承中心の試作の本番採用は見送る。

## 固定した条件

抽出器は[PR #61](https://github.com/KantoYamamoto/sekka/pull/61)の`f76bfd32911fa8606f1c06d85a414a0aee8d1b7e`。評価用バイナリのSHA-256は`566e714a9ac43ddf66c14a1c8b7645de46b582cffedf63669ca0c3a769f33537`。新しい入力を見て検出条件を調整しない。Swift 6.3.3で対象を構文として読み、対象コードは実行しない。

公開PRのタイトルを検索し、全変更ファイル一覧までで2件を選んだ。WordPressでは「既存アップロードへ外部入力を追加」、別ライブラリのNukeでは「非同期デコードを追加」という異なる拡張を選ぶ。新class・空hookが出ることを選定条件にせず、元の用途に対する取りこぼしも調べる。後続修正やレビューコメントを選定に使わない。

WordPressの検索候補にはComments v2、ReaderのSkip、Statsのlegend、CI/文書等もあったが、前回のエディターと別の入力経路の統合を選んだ。Nukeの候補にはdemo追加、Error/Statusの便利API、AVIF識別等もあったが、既存の処理経路を拡張する変更を選んだ。無作為標本でも、継承検出の精度測定でもない。「意図的な拡張」は先に正解ラベルを貼らず、コードと要件から評価する。

| 入力 | base → head | 読む範囲 |
| --- | --- | --- |
| [WordPress #25624](https://github.com/wordpress-mobile/WordPress-iOS/pull/25624) | `9aa73328cf429f144750d406cb937723c44237f4` → `989a00e0d8453dbd92a8a2ca7cb2ff637bbaa9fe` | 変更Swift全7ファイルとMedia配下の全Swift。60→66ファイル |
| [Nuke #879](https://github.com/kean/Nuke/pull/879) | `63a8fcbd6621340a2410bc3e9575ac97058615f4` → `5aa0d5f5a8f82615df20157fe0a3aea18bd50712` | 変更Swift全4ファイルとSources/Nuke配下の全Swift。56→56ファイル |

Git treeはtruncatedでないこと、対象が通常のファイルであることを確認。238 side/blob件（重複を除く127blob）のGit blob ID・サイズ・SHA-256を固定した。[manifest](../../Experiments/StructuralContext/holdout-inputs.json)の範囲であって全リポジトリではない。WordPressMediaLibrary moduleや外部SDK等の宣言は含まれず、その契約が必要な判断は未確認として残す。取得はGitHub APIのGETだけ。先方へのコメント・Issue・PR等は行わない。

## 読み方と判定

Aは通常diffと選択ソースだけからcheckpoint、Bは機械出力だけからcheckpointを保存した後、同じdiff/ソースを読む。最後に両者へ同じPR本文を渡す。PR本文は要件の参考であり、正解や実装の保証と扱わない。生レビューとソースはGit管理外に置く。

各入力で、具体的な配置の問い・根拠位置・別配置が妥当な条件・現配置を保つ理由・未確認点を挙げる。出力から得た問いと、ソースで初めて得た問いを分ける。0件は安全や妥当性の判定ではない。不要な共通化を促したか、問いを得られなかったかも結果にする。中断/通信/読み順を制御した時間測定ではないため、速度やトークン削減を評価しない。

## 機械抽出

| 入力 | 関係候補 | JSONのbyte数 | 解釈 |
| --- | ---: | ---: | --- |
| WordPress #25624 | 0 | 4,705 | 正常終了。追加class/既存親の空body/既存兄弟overrideの組がない |
| Nuke #879 | 0 | 6,448 | 正常終了。同上。protocolやgeneric classの関係はこの試作の対象外 |

0件でもscope/limitations/skippedが出力される。これらの説明が構造の問いに寄与するかはレビューで区別する。抽出器をこの2件で調整してから「未見の成功」と呼ばない。

## レビュー結果・次の判断

Aは通常diff/ソースからWordPressで3問、Nukeで2問を得た。Bは出力先読みで具体的な配置の問いを得られず、ソースを読むと同じ5領域へ到達した。数は不具合数でも検出精度でもない。

| 配置の問い（両レビュー） | 既存構造の根拠と現配置を保つ理由 | 機械出力の寄与 |
| --- | --- | --- |
| WordPress: option組立てをroutingに保つか、source descriptorへ寄せるか | 既存のMediaPickerSourceでgateは共有済み。routingは既にapp依存の構成地点。V1/V2のUI寿命まで統合しない | 該当するrouting enum/メソッドの関係は出ない |
| WordPress: picker構築だけを共有するか | 既存makeStockPhotos/showStockPhotosPickerと新StockPhotosPickerSheetに同じdata source/service/welcomeの構築がある。選択結果とdismissの境界は異なる | 除外したCoordinatorのパスは弱い入口。構築の接点はソースから初めて分かった |
| WordPress: asset変換の方針をadapterとimporterのどちらへ置くか | stockPhotosAsset専用の変換と共通のファイル名処理は分けて考える。importerの定義が入力外で結論不可 | 接点も変換内容も出ない |
| Nuke: 同期protocolのrefinementでasync能力を足すか | 既存registry/decoder契約・同期fast pathを保つ理由がある。PR本文の互換要件も現配置を支持 | 新protocolの除外パスのみ。契約はソースと本文から |
| Nuke: 共通decode入口を保つか、実行adapterを分けるか | network/disk側が既に同じ入口を使い、operationとqueueの寿命を保持する。汎用queueへdecode知識を移さない。response生成も今回既に共有された | 既存呼び出し元・共通入口・所有者の関係は出ない |

代表位置はWordPress afterの`MediaPickerMenu+External.swift:19`と`StockPhotosPickerSheet.swift:10`、Nuke afterの`AsyncPipelineTask.swift:44`と既存の`TaskLoadImage.swift:31`・`TaskFetchOriginalImage.swift:57`。位置の前提は上記固定SHAとmanifest。詳細な根拠と反対理由はGit管理外の`review-a.md`/`review-b.md`に保持した。

PR本文は両者ともcheckpoint後に読み、Nukeの同期cache API制限を受けて、許可された入力内の`ImagePipeline+Cache.swift:225`付近を追加で確認した。この発見を機械出力や初回ソースレビューの成果へ混ぜない。本文のテスト成功報告も、本検証では実行・検証していない。

Bのskipped一覧は対象外と弱い読む場所を示すが、具体的な配置の根拠にはならず、変更と無関係な除外も含む。妥当な拡張を積極的に問題扱いする出力ではなかったが、候補0件なので空hookを誤警告しない精度を確認したとは言えない。Nukeはソースと要件から現配置を支持する対照になった。WordPressの未取得module契約は結論を限定する。

**次は[#63](https://github.com/KantoYamamoto/sekka/issues/63)。継承中心の試作は本番採用を見送り、変更宣言から既存実装との接点を検索する方式へ置換する。** 今回は単なる表示改善では届かない。未変更の構築と共有する呼び出し表記、既存の共通入口と呼び出し位置を同じ索引から取り出す仮説を試す。解決済み依存や意味上の重複とは呼ばず、共通化の反対根拠も残す。[判断0036](../decisions/0036-change-context-retrieval.md)参照。この2件は以後既知入力であり、次の方式を当てた成功は未見の有用性ではない。

## 再現

```sh
set -e
swift test --package-path Experiments/StructuralContext --scratch-path .build/structural-context
python3 Experiments/StructuralContext/fetch.py --manifest Experiments/StructuralContext/holdout-inputs.json --output .build/context-holdout-input
.build/structural-context/debug/context-probe .build/context-holdout-input/wordpress-ios-25624/before .build/context-holdout-input/wordpress-ios-25624/after
.build/structural-context/debug/context-probe .build/context-holdout-input/nuke-879/before .build/context-holdout-input/nuke-879/after
```

当時の抽出器は[履歴手順](../../Experiments/StructuralContext/README.md#以前の方式の再現)で上記commitのpackageを取り出して使う。#63以降の常設packageは別方式なので、上記入力へ現行バイナリを当てても本記録の0件は再現しない。manifest変更だけで他実験の既定入力を置換しないよう、取得スクリプトに`--manifest`を追加した。入力取得先は新規ディレクトリに限る。ローカルの取得/検証結果と固定packetは`.build/context-holdout`。

取得スクリプトのmanifest指定は固定1blobで動作・hash一致を確認した。全238件は資料準備時のGET取得でblob ID/サイズ/SHA-256を照合済み。固定packetの246ファイル（ソース238と各caseのdiff/出力/stderr/PR本文）のhash一覧のSHA-256は`67c37bd989c57ae42bb908cd486cb55e3371df5c0886faeb3af8042d40495bda`。Swift解析器は変更していないため、本件で本番Swiftテストをローカル再実行していない。
