# 変更から未変更の実装候補へ辿る実験

本番CLIへ採用する前の試作。[判断0038](../../docs/decisions/0038-outside-diff-context.md)に従い、通常diffを読むときに、変更していない既存実装も確認する入口を作る。Swift構文を決定論的に読み、LLMや対象アプリのビルドを使わない。

```sh
set -e
swift test --package-path Experiments/StructuralContext --scratch-path .build/structural-context
python3 Experiments/StructuralContext/verify.py --binary .build/structural-context/debug/context-probe --output .build/context-checks.json --text-output .build/context-checks.text
.build/structural-context/debug/context-probe BEFORE AFTER --text
```

Swift 6以降とSwiftSyntax 604.0.0が必要。`BEFORE`/`AFTER`は比較するSwiftソースを含むディレクトリ。末尾の`--text`を省くとJSON。`verify.py`は既存7対照・型注釈・条件付きborrow/mutate・入力境界・member表記・字句条件・戻り値名の計13例を検証する。**合成例の成功は実PRで役立つことの証明ではない。**

## 未変更宣言と根拠経路

出力の単位は未変更の宣言候補。同じ宣言へ複数の場所から届けば1件にまとめ、型宣言とそのmember関数は別の宣言として扱う。次の四種類の根拠を同じ一覧へ統合する。

| 根拠 | 観測できること | 確定しないこと |
| --- | --- | --- |
| 戻り値名/call表記 | 変更関数と未変更の既存関数にある同じ戻り値名、unqualified callの名前/明示ラベル列、同名nominal宣言、両call/型表記の位置・条件 | 実型/constructor、callがその戻り値を返すこと、引数値、挙動や責務の一致、共通化の必要性 |
| propertyの型注釈 | 新しく現れた表記の末尾名と、同名nominal/typealias宣言の位置。例えば`[Migration]`→`OrderedDictionary<String, Migration>`から既存OrderedDictionaryへ進む | 実型、module/owner、alias展開先、依存の追加、同じ責務 |
| 既存callとの接点 | 旧版にも一度現れる直前のmember call、共通する識別子引数、receiverの明示型から関数候補への旧新経路 | call挿入か既存callの編集か、実callee、同じ値・挙動、統合必要性 |
| member callの表記 | 変更関数に書かれた名前・明示ラベル列と、同一記載ラベル列の索引内1関数宣言への位置 | receiver型、実callee、default引数等の適合性、責務の一致 |

**候補があるのは、その宣言を読む入口があるというだけ。配置を見直す必要があるか、通常検索より助かるかは別に評価する。** 名前から役割を推論しない。

型注釈では`Box<A>`→`Box<B>`のBを入口にし、既存のBoxを新規名として再掲しない。optional/array/tuple/generic引数内の名前も読む。`Left.Item`→`Right.Item`は表記変更として扱い、照合に使う末尾Itemと完全な表記を保持する。同名のLeft.Itemも候補になり得るが、Rightへの解決とは呼ばない。既知のgeneric/associated type parameterとSelfは除外し、`_`等の不明表記を一致なしと区別する。

型/alias宣言はfile・字句owner・名前・種別が一意に対応し、宣言全体のトークンが同じものを候補にする。同名別宣言は別候補で、変更済みの一方を除いても他方を消さない。条件分岐等で前後対応が曖昧なら未変更と断定しない。属性・準拠・generic・extensionの存在自体を、書かれた宣言を消す理由にしない。

既存callとの接点経路はmember関数本体の直下、単純な識別子引数、同じowner内の明示型propertyに限定する。nested block、try/await、closureや曖昧なscopeは対象外。旧版に同じ文がないcallを検索し、callの挿入とは断定しない。[索引の経緯](../../docs/validation/source-inventory.md)。

member表記経路は、変更fileのafter関数の宣言トークンが旧fileの関数索引にない場合を入口にする。一意に対応したcallerでは旧本文に同じcallトークンがない出現だけを検索。対応不明なら本文のmember表記を読み、「新規call」とは呼ばない。defer/if/closure内も表記として読み、local関数・local型の本文は混ぜない。初回は明示的な引数リストだけで、trailing closure/unqualified/specialized callは対象外。

一致数は変更済み/新規も含むafter索引全体で数え、複数なら選ばない。1件でも実calleeの一意性ではない。候補はbodyがあり、旧新の宣言と全字句祖先headerが同じもの。SDK・索引外・macro展開・propertyに格納した関数等は解決しない。[方式と結果](../../docs/validation/member-spelling-context.md)。

## 戻り値名から既存producerを比較する

call先の宣言だけでなく、同じ結果表記を扱う既存処理へ進む。両関数の戻り値に書かれたunqualified名と、本文の同名call/明示ラベル列が一致し、after索引に同名の非alias nominal宣言が1件ある場合を候補にする。tupleやgeneric引数内の名前も記載名として読む。式が実際にその戻り値を作る/返すかは解析しない。

member経路と同じcaller適格性・旧対応・target不変を使う。parameter default/header/local宣言本文を混ぜず、既知generic/associated/Self、parameter/local/closure bindingと同名なら除外する。direct file/字句ownerのfunction・variable pattern・enum case名も除外し、単純なextension owner表記と索引内nominal名の一致はbinding除外にだけ使う。owner型を解決したとはしない。位置/条件の前後を問わないため偽陰性を許容する。alias/qualified/specialized/implicit/trailingの形式は対象外。継承、qualified extension、SDK/生成/未索引bindingは未解決。

`resultSpelling.evidence`は前後callerと対応状態、`anchorReturn`/`targetReturn`/`matchingNominal`、`anchorCall`/`targetCall`、両側の出現数を持つ。入口と比較先の条件経路を別々に集約し、その組を表示する。同条件内は最初の位置と件数だけで、引数値や挙動を比較しない。複数の未変更関数が同じ条件を満たせば全て候補とし、共通の上限・省略へ統合する。[方式と検証](../../docs/validation/result-spelling-context.md)。

## 構文索引と検索の適格性

関数索引にはnominal直下だけでなく、ファイル直下とextension内の関数を保持する。字句scopeにはextensionの表記型・属性・where節、宣言位置、条件分岐の表記経路を記録する。これを解決済みの型やactiveなコンパイル条件とは呼ばない。実行ブロック内のlocal関数・closure/accessor内のlocal関数は対象外。

関数の前後対応はfile・字句scope・signatureと条件経路の一意な宣言キーを使う。分割された同一headerのextensionでも、完全な宣言キーが一意なら構文上の対応を取る。blockの実体同一性は主張しない。同じキーの複数関数、nominal/条件blockの重複は不明として保持する。条件経路は外→内の順と先行条件を含む。member表記の候補では全字句祖先headerも照合する。[判断0041](../../docs/decisions/0041-written-member-relations.md)。

extension内のnested nominalにも字句祖先を保持するが、型注釈検索の対象へ暗黙に追加しない。既存call接点の保守的判定とmember表記経路の事実を分ける。[索引の検証](../../docs/validation/lexical-scope-inventory.md)。

## JSON/textの範囲と不明

`contexts`の各候補に前後位置、`kind`、`fileUnchanged`、根拠の`entries`を持つ。根拠は`existingCall.evidence` / `changedType.evidence` / `memberSpelling.evidence` / `resultSpelling.evidence`。textでも候補1件の罫線の下へ根拠を並べる。最大8候補・各8入口で、省略数を共有する。

型経路は旧新property/型表記、新しく現れた名前の位置、末尾名が一致する宣言数を持つ。同じpropertyの同じqualified名は最初の位置を使う。`beforeStatus: no-indexed-counterpart`は旧版索引に対応がない状態であり、旧宣言の不存在や新規propertyの証明ではない。

member表記の根拠には前後caller・対応状態、call位置・receiver表記・記載ラベル列を持つ。`callerEvidence: no-unique-old-indexed-correspondence`は旧宣言不存在を意味しない。差分の適格性で出現を絞ってから同じcaller/selector/receiver/記載条件経路を集約し、最初の位置と`eligibleOccurrences`を示す。`call.writtenConditions`は外→内の選択節と先行節のkeyword/条件表記/header位置。条件なしは空配列、異なる条件は別入口、同じ条件の行移動は集約を分けない。textはcallのそばへ条件と「有効節未判定」を示す。旧本文に同じcallトークンがあれば、条件移動だけでは新しく適格にしない。[条件表示の検証](../../docs/validation/written-conditional-context.md)。

- `changedFunctions`と`unpairedBefore/After`は索引内の関数数。`changedTypeAnnotations`は索引内の型注釈差の件数で、新しい実型や依存の数ではない。
- `skipped`はcall検索・型注釈の対応・宣言検索の各試行を退けた理由の件数。名前一致なし、旧宣言未確認、変更済み、対応不明、型表記不明を区別する。ファイル数や網羅率として足し合わせない。型注釈の組が未変更の曖昧propertyは毎回再掲しない。
- 型注釈検索用のnominal/typealias宣言やpropertyでは、extension内・local function内・トップレベルproperty等は対象にない。継承された型bindingやその他のshadowing、生成された宣言、activeな条件は解決しない。全リポジトリの型解決ではない。
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
