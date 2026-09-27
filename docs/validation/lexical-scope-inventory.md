# 字句scopeを保持する関数索引

2026-09-27、M2 #83。**extension/top-levelの関数を保持し、意味解決の適格性とは分離した。既知Collections #728で従来0だった索引内の変更関数を9件保持できたが、案内候補は0件のまま。これは有用性の達成ではない。**

## 契約と選択

[実装前の契約](https://github.com/KantoYamamoto/sekka/issues/83#issuecomment-5826965034)を独立レビューした。読み取れる宣言を意味解決の難しさから削らず、既存memberCandidateの保守的な判定を残したまま、同じSourceInventoryの収集を見直す。別CLIや並列の索引を本番へ増やしていない。

字句scopeはfile/nominal/extensionと位置・headerを持つ。extensionは表記型・where/属性をheaderへ保持する。関数対応キーにscopeとsignature、外→内の条件経路を持たせ、行や出現順を同一性にしない。#else/#elseifの前提となる先行条件も含める。active branchや実型への解決は行わない。

同一親の同一header extensionや同一条件ブロックが複数ある場合は、その子孫も前後対応不明とする。where/属性/条件経路の変更や移動で対応外になることがある。extension内のnested nominalを外側やtop-levelの同名型へ混ぜず、既存の型注釈検索対象へ暗黙に加えない。scopeが記録できることとcall検索の適格性を分ける。

## 検証

既存46＋追加7の53テストが成功。top-level/nominalの同名、extension制約と行移動、重複header/overload、入れ子型の祖先と型検索分離、条件の先行節・nesting・重複・移動、実行ブロック内のlocal関数除外を確認。旧テストの総数2はトップレベルを含めて3へ更新し、member2件・localは対象外という期待を追加した。

独立コードレビューで、switch case内のlocal関数はCodeBlockを通らず誤収集される問題を発見。SwitchExprの配下を対象外にし、local関数とlocal nominalの対照を追加した。再点検では残るコード指摘なし。memberCandidateの未解決scope除外や既存の型注釈経路は維持する。CLIの既存10対照も成功。

## 固定入力への回帰

#77のmanifest/入力を変えずに全ファイル一覧とハッシュを照合し、各例2回の出力一致を確認した。対象OSSを実行しない。この入力は既知例であり未見評価とは呼ばない。

| 入力 | 索引内の変更関数 | 対応外の関数 before→after | 案内候補 |
| --- | ---: | ---: | ---: |
| Collections #728 | 9（従来0） | 1,386→1,385 | 0 |
| Collections #727 | 0 | 1,381→1,381 | 0 |
| GRDB #1876 | 0 | 779→779 | 0 |
| GRDB #1869 | 10 | 779→779 | 1（OrderedDictionary） |

**対応外の数は変更関数や問題の数ではない。** 同じheaderで分割した多数のextensionを、字句blockの対応不明として保守的に扱った結果を含む。変更していないものも数える。大量の対応外を毎回人間へ見せることの利益は確認していない。

実行前に通常diffを読み、#728のProducer+Map/Filterの本文変更を保持対象とした。#727はextension削除/制約変更を含み、全例で変更関数数を必ず増やす条件にはしていない。今回の索引の保持から、必要な未変更helperや既存契約へ届いたとはしない。今後の関係検索は、この具体的な確認先と既存の負の対照に基づいて選ぶ。

## 自己利用と仕上げ

ローカル記録は`.build/lexical-scope`。公開Gitに第三者の生ソースや生レビューを置かない。最終バイナリの回帰・自己利用は下記。PR/Actionsは仕上げで確認する。本番CLI/配布への統合は保留。

追加確認: Map/Filterのgenerate宣言は両版で索引に保持されたが、返却型BoolからIntへの変更でsignatureが変わるため、一意対応した9関数には含まれない。9関数はUniqueDeque/UniqueSet/MutableContainer/Producer.reduce等の別の変更である。signature変更の対応も今後の不足として残す。

独立レビュー修正後の最終バイナリで53テスト・10 CLI対照・固定4入力を再確認し、上表と同じ結果を得た。最終結果はreach-finalに保存した。

自己利用: base 8ceec94から実装d1990b6を比較し、.build/self-review/lexical-scopeへ保存。本番CLIは同一バイナリ。実験には19から20の自リポジトリsourceを渡し、既存SourceSiteへ1候補1入口を得た。索引内変更関数7、対応外0から10。switch内localの誤収集は独立コードレビューの発見であり、Sekkaの発見とはしない。
