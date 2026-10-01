# member表記の入口に書かれた条件を示す

2026-10-01、M2 #89。[0043](../decisions/0043-written-conditional-context.md)。#87で判明した条件の誤読余地を修正する。実callee/有効条件や、配置見直しの必要性を判定する機能ではない。本番CLIは変更していない。

## 実装の事実性

71 packageテストでnested/外側条件、elseif/elseの先行節とheader位置、条件あり/なし/異条件の別集約、同条件反復と行移動、closureとlocal本文除外、旧callトークンの適格性維持、入力順・JSON往復・textを確認した。CLIは既存7対照を含む12例。妥当な分離/自然なモデル追加の0件と、方針だけ違う同一ソースの同一出力を維持する。

初稿のテストfixtureに改行で途切れた不正な`#if`式があり、parserが拒否した。正しい式のtrivia除去と、不正入力の部分出力拒否へ分けた。parserを緩めて通していない。

独立コードレビューでtextの先行節にも位置を示す点を修正した。選択節と先行節のどちらも、JSONのheader位置とtextのfile:lineから戻れる。

## 既知の4PRと自己利用

固定#87の3,026入力について全一覧/ハッシュ照合後、JSON/textを各二回実行した。全件parse成功、終了コード/stdout/stderrが一致。候補数は0/4/0/1、入口は0/9/0/1で維持。評価器はSwift 6.4、SwiftSyntax 604.0.0、最終binary SHA-256 `88816fceca3b6f0a77333fc2fc1e72d479a542072f45bb24dd8982ecc046311d`。修正後の既知回帰であり、新しい有用性評価ではない。

| 入力 | 確認できたこと | 残る不足 |
| --- | --- | --- |
| Collections #725 | 0候補を維持 | 追加の構造負担を示す評価ではない |
| Collections #724 | 4候補/9入口を維持。Utilitiesのcall56行→`#if false`55行、SpanPreviewのcall40行→`#if false`39行。compiler/featureの外側条件も表示 | 実ループと既存共有adapterの先例への未到達は残る |
| GRDB #1864 | 0候補を維持 | activation/authorizer/deliveryの必要先へ届かない |
| GRDB #1858 | SQL宣言1候補/1入口、二出現のgroupを維持 | insertの先例/結果/callback/schema契約へ未到達。同groupの異なる引数/位置は列挙しない |

#724の二つの`#if false`位置をJSON/textでsourceと照合した。他の入口も外側条件を持つが、有効なbranchは判定していない。条件表示の成立だけを根本的な構造検討の成功には数えない。入力ソースや生出力はGit管理外`.build/conditional-context`。OSS側の実行・投稿は行っていない。

自己利用はbase `739e0ab`→実装初稿`c8f2c51`、整理後`01c0277`で、本番Sekkaと固定実験をそれぞれ使用。本番出力のdirect-forwarding-shapeが、共有処理への移設後に残った二つの転送関数を示した。通常sourceで不要と確認し、既存readerの呼び出し元から共有処理を直接参照する形へ整理。再テストと追加独立レビューを通した。これは自己利用の案内が具体的整理に寄与した一例であり、独立した有用性の証明ではない。

実験の自己利用は22→23 Swift source、未変更SourceSiteへの型注釈入口1件。JSON/text二回一致。新しい構造判断の材料はなく、既存構造を考え直す目標の達成とはしない。本番CLIのbaseline/candidateは同一binaryで、試作の改変が本番改善になったとは主張しない。

## 完了条件

71テスト/12 CLI対照、既知回帰、自己利用と独立コードレビューを実施。先行節のtext位置欠落と転送関数整理の差分を再点検し、未解消指摘なし。必須Actions・実PRコメント/成果物はPR完成時に照合する。

次は条件以外の必要先へ届かない理由を、既知入力のソース位置と検索条件へ戻して整理する。本番統合と新しい未見評価は別判断。人間の判断待ちはない。
