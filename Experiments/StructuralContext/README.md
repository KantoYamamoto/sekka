# 同形変更と既存窓口の関係を直接示す実験

通常diffでは離れて見える変更領域・既存helper・利用側を、書かれた構文の根拠から一緒に読むための試作。[判断0048](../../docs/decisions/0048-changed-existing-context.md)・[0049](../../docs/decisions/0049-direct-written-relations.md)。本番CLIへの統合は保留。未変更宣言への検索を継ぎ足す構成を撤去し、内部の領域索引から小さな関係レポートを直接作る。LLM、対象アプリのbuild/test/scriptは使わない。

```sh
swift test --package-path Experiments/StructuralContext --scratch-path .build/structural-context
python3 Experiments/StructuralContext/verify.py \
  --binary .build/structural-context/debug/context-probe \
  --output .build/direct-relations/checks.json \
  --text-output .build/direct-relations/controls.text
.build/structural-context/debug/context-probe BEFORE_DIR AFTER_DIR --text
```

Swift 6以降・SwiftSyntax 604.0.0・macOS 13以降。`--text`を省くとJSON、`--all`は同じ関係の形の詳細を全件表示する。既定は8関係まで形を詳述し、以降も全ての関係・owner・利用表記・反対材料・対応不明の位置を保持する。本番SekkaのGit入力とは別のディレクトリ入力で、非Swiftファイルは解析しない。

## 何を一緒に示すか

一意に対応する実行領域のswitchに、同じcaseラベル・呼び出し表記の前後変化が複数入ったとき、1関係へまとめる。関数だけでなくinitializer、property/accessor、binding本文を含み、変更された既存helperも除外しない。二つ以上のcaseという条件は今回の構文範囲であり、危険度ではない。

JSONの`relationships`と罫線textは次を示す。

- 前後のswitch・所属宣言の位置、ownerの構文変更状態、記載された外側条件。
- caseラベル、called expression、明示selector、trailing closure数と追加ラベルの前後形。引数/closure本文の表記差と条件差は別の事実。
- 所属functionと同じ明示selectorを持つ前後の利用表記、そのownerがtoken-identical/changed/対応不明か。
- 新しく共通になったcall表記の全位置と、同じbasenameの宣言候補。共有処理がすでに存在する可能性の反対材料であり、trailing closureの引数対応や実calleeの解決ではない。

例えば同じ結果転送の変更がinitializerと既存helperへ入った場合、両switch全体と未変更property内の同名利用表記へ進める。これは「既存helperへ揃えるか」と考える入口にすぎない。主処理がすでに共有済み、引数や条件が異なる、別目的である可能性も残る。Logger/SwiftUI一般や任意の重複処理を検出する契約ではない。

## 対応・不明・入力の境界

前後の対応はUTF-8 bytesが等しいfile・字句祖先header・条件・switch式が各側で一意の場合だけ。同じowner内の複数switchを位置順で対応させない。条件コンパイルのcase一覧は展開せず、追加/削除・header変更・曖昧さとともに`unknown`へ全位置を残す。空白/コメントは構文変更としないが、入力SHAは元のbytesを識別する。`#sourceLocation`の仮想位置ではなく物理位置を返す。

形が同じことは、挙動・責務・制御フローが同じことではない。引数値・receiver型・callee・有効条件・実行順・macro展開・意図・性能は未解決。0関係は設計の妥当性を示さず、通常diffと周辺コードの読解は必要。

入力配下のドット名を除外。ルート自身/配下のsymlink、UTF-8読取り失敗、構文エラーは終了2・stdoutなし。祖先symlinkは正規化して許容する。成功時のみJSON/textを返し、部分結果を正常0へ変換しない。path/表記の制御文字はtextでquoteする。

## 検証と履歴

現行のSwiftテストと`verify.py`は合成例・曖昧さ・反対材料・入力失敗・同じ入力の全process bytesを検証する。合成例の成功や既読入力への到達は、未読PRの有用性ではない。[直接出力の検証](../../docs/validation/direct-written-relations.md)に状態と再現手順を記録する。外部OSSは読み取り専用、第三者のsource/diff/生出力はGitへ入れない。

前方式と#105診断は固定commit `5177d21c476728e7fd4f3bbadba53cce9c181cfc`に保存した。現行CLIで旧検証runnerを実行しない。再現する場合は別ディレクトリへ取り出し、その版のREADME/runnerを使う。

```sh
mkdir -p .build/archived-context
git archive --output=.build/archived-context/input.tar \
  5177d21c476728e7fd4f3bbadba53cce9c181cfc Experiments/StructuralContext
tar -xf .build/archived-context/input.tar -C .build/archived-context
```

[前後call入口の比較](../../docs/validation/both-side-call-holdout.md)は機械起因の配置再考0、stage1資料の非対称で純増効果未判定。[既読の観測単位診断](../../docs/validation/cochange-diagnostic.md)は1関係へ到達、他2件0。過去の評価は置き換えて成功扱いせず、未読比較の根拠と限界として保持する。
