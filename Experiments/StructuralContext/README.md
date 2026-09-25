# 変更から未変更の実装候補へ辿る実験

本番CLIへ採用する前の試作。[判断0038](../../docs/decisions/0038-outside-diff-context.md)に従い、通常diffを読むときに、変更していない既存実装も確認する入口を作る。Swift構文を決定論的に読み、LLMや対象アプリのビルドを使わない。

```sh
set -e
swift test --package-path Experiments/StructuralContext --scratch-path .build/structural-context
python3 Experiments/StructuralContext/verify.py --binary .build/structural-context/debug/context-probe --output .build/context-checks.json --text-output .build/context-checks.text
.build/structural-context/debug/context-probe BEFORE AFTER --text
```

Swift 6以降とSwiftSyntax 604.0.0が必要。`BEFORE`/`AFTER`は比較するSwiftソースを含むディレクトリ。末尾の`--text`を省くとJSON。`verify.py`は既存7対照・型注釈・条件付きborrow/mutate・入力境界の計10例を検証する。**合成例の成功は実PRで役立つことの証明ではない。**

## 未変更宣言と根拠経路

出力の単位は未変更の宣言候補。同じ宣言へ複数の場所から届けば1件にまとめ、型宣言とそのmember関数は別の宣言として扱う。次の二種類の根拠を同じ一覧へ統合する。

| 根拠 | 観測できること | 確定しないこと |
| --- | --- | --- |
| propertyの型注釈 | 新しく現れた表記の末尾名と、同名nominal/typealias宣言の位置。例えば`[Migration]`→`OrderedDictionary<String, Migration>`から既存OrderedDictionaryへ進む | 実型、module/owner、alias展開先、依存の追加、同じ責務 |
| 既存callとの接点 | 旧版にも一度現れる直前のmember call、共通する識別子引数、receiverの明示型から関数候補への旧新経路 | call挿入か既存callの編集か、実callee、同じ値・挙動、統合必要性 |

**候補があるのは、その宣言を読む入口があるというだけ。配置を見直す必要があるか、通常検索より助かるかは別に評価する。** 名前から役割を推論しない。

型注釈では`Box<A>`→`Box<B>`のBを入口にし、既存のBoxを新規名として再掲しない。optional/array/tuple/generic引数内の名前も読む。`Left.Item`→`Right.Item`は表記変更として扱い、照合に使う末尾Itemと完全な表記を保持する。同名のLeft.Itemも候補になり得るが、Rightへの解決とは呼ばない。既知のgeneric/associated type parameterとSelfは除外し、`_`等の不明表記を一致なしと区別する。

型/alias宣言はfile・字句owner・名前・種別が一意に対応し、宣言全体のトークンが同じものを候補にする。同名別宣言は別候補で、変更済みの一方を除いても他方を消さない。条件分岐等で前後対応が曖昧なら未変更と断定しない。属性・準拠・generic・extensionの存在自体を、書かれた宣言を消す理由にしない。

call経路はmember関数本体の直下、単純な識別子引数、同じowner内の明示型propertyに限定する。nested block、try/await、closureや曖昧なscopeは対象外。旧版に同じ文がないcallを検索し、callの挿入とは断定しない。[索引の経緯](../../docs/validation/source-inventory.md)。

## JSON/textの範囲と不明

`contexts`の各候補に前後位置、`kind`、`fileUnchanged`、根拠の`entries`を持つ。根拠は`existingCall.evidence`または`changedType.evidence`。textでも候補1件の罫線の下へ根拠を並べる。最大8候補・各8入口で、省略数を共有する。

型経路は旧新property/型表記、新しく現れた名前の位置、末尾名が一致する宣言数を持つ。同じpropertyの同じqualified名は最初の位置を使う。`beforeStatus: no-indexed-counterpart`は旧版索引に対応がない状態であり、旧宣言の不存在や新規propertyの証明ではない。

- `changedFunctions`と`unpairedBefore/After`は索引内の関数数。`changedTypeAnnotations`は索引内の型注釈差の件数で、新しい実型や依存の数ではない。
- `skipped`はcall検索・型注釈の対応・宣言検索の各試行を退けた理由の件数。名前一致なし、旧宣言未確認、変更済み、対応不明、型表記不明を区別する。ファイル数や網羅率として足し合わせない。型注釈の組が未変更の曖昧propertyは毎回再掲しない。
- nominal/typealias宣言やpropertyのうち、extension内・local function内・トップレベルproperty等は索引にない。継承された型bindingやその他のshadowing、生成された宣言、activeな条件は解決しない。全リポジトリの型解決ではない。
- 未変更なのは候補宣言のトークン。extension、alias展開、macro、有効な条件を含む型全体の不変ではない。ファイル全体の一致は別に示し、hunkを見ずに「diffにも出ない」と断言しない。

構文エラーは部分的な成功結果にせず停止する。正常0候補も設計の妥当性を示さない。検索の契約はJSONの`limitations`にも残す。

## 入力と再現の境界

入力配下のドット名は除外する。入力ルート/祖先の名前やFinder非表示属性は除外条件にしない。ルート自身/配下のsymlink、読取り失敗・構文エラーは終了2で部分出力せず停止。祖先symlinkは正規化して許容する。本番のGit入力/ignoreとは別の実験用ディレクトリ入力。

既読のOSS2件を再現する場合は以下。今回の方式の未見評価ではない。

```sh
set -e
python3 Experiments/StructuralContext/fetch.py --manifest Experiments/StructuralContext/retrieval-inputs.json --output .build/context-input
python3 Experiments/StructuralContext/verify.py --binary .build/structural-context/debug/context-probe --output .build/context-oss.json --oss-input .build/context-input
```

`fetch.py`は`gh`の読み取り認証を使い、固定blobをGETで取得してGit blob ID・SHA-256・サイズを照合する。manifestを明示し、新規ディレクトリへ取得する。途中失敗した入力を解析しない。選択したファイルが範囲であり、全リポジトリではない。固定資料の非Swiftファイルは解析しない。

第三者ソースはGitへ保存せず、元のライセンスを維持する。対象アプリのコード/ビルド/スクリプトを実行せず、対象OSSへのコメント・Issue・PR・その他の変更も行わない。

## 以前の方式

実験CLIを置換し、旧方式は固定commitに残す。class配置は`f76bfd32911fa8606f1c06d85a414a0aee8d1b7e`、call接点は`c0eb0b3f783262d0c43c1f189c338174725d584b`、参照減少/残存は`2f089f37de5d925e514df74a5317fb5d4cad1d91`、隣接callだけの案内は`b23a44e707ca4baf76bb9198b3fb81e165780e33`。下記のREFを置き換えて別ディレクトリへ取り出す。

```sh
set -e
mkdir -p .build/archived-context
git archive --output=.build/archived-context/input.tar REF Experiments/StructuralContext
tar -xf .build/archived-context/input.tar -C .build/archived-context
swift test --package-path .build/archived-context/Experiments/StructuralContext --scratch-path .build/archived-context/build
python3 .build/archived-context/Experiments/StructuralContext/verify.py --binary .build/archived-context/build/debug/context-probe --output .build/archived-context/result.json
```

以前の結果は[class配置](../../docs/validation/class-context-experiment.md)・[call接点](../../docs/validation/change-context-experiment.md)・[参照差](../../docs/validation/reference-delta.md)。隣接call方式の結果は[未変更候補への検索](../../docs/validation/unchanged-context.md)と[固定実PR](../../docs/validation/unchanged-context-reach.md)。現在の型注釈を含む結果は[宣言候補への案内](../../docs/validation/typed-declaration-context.md)。
