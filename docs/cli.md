# CLIと出力の仕様

利用の入口は[README](../README.md)。この文書は対象ファイル・出力形式・照合の制約を確認するためのリファレンスです。

## 実プロジェクトで使う

```sh
# 現在のファイルの構文情報を列挙
.build/debug/sekka scan --path /path/to/MyApp

# 指定コミットと作業ツリーを比較（未コミットの変更も含む）
.build/debug/sekka diff HEAD --path /path/to/MyApp

# PRブランチのコミット同士を、共通祖先から比較
.build/debug/sekka diff origin/main --head HEAD --merge-base --path /path/to/MyApp

# AIやスクリプトへ渡す。JSON以外は標準出力に混ぜない
.build/debug/sekka diff HEAD --path /path/to/MyApp --format json

# 変更前後の完全な観測リストも必要な場合
.build/debug/sekka diff HEAD --path /path/to/MyApp --format json --json-detail full

# サードパーティーや生成コードを除外（ファイル/ディレクトリの相対prefix、globではない）
.build/debug/sekka diff HEAD --path /path/to/MyApp --exclude Vendor --exclude Sources/Generated
```

Gitモードでは `--path` 内のリポジトリ全体を解析します。作業ツリー側は追跡済みファイルとGitで無視されていない未追跡ファイルを対象にし、削除・ステージ済み・未ステージの変更を含みます。`--head` を指定すると作業ツリーを読みません。Git checkoutや対象プロジェクトのスクリプト実行はしません。

scanとディレクトリ比較は指定ディレクトリ配下を読み、`.gitignore` は解釈しません。全モードでシンボリックリンクをスキップし、`.build`, `.swiftpm`, `.git`, `Pods`, `Carthage`, `DerivedData` を除外します。テストコードもデフォルトで含まれます。

## レビュー向け出力

textは型ごとに観測をまとめます。同じ型内で前後とも名前が一意な関数・initializerの引数変更は、長い宣言を2本並べる代わりに「追加・削除された引数」で表示します。引数以外のアクセス修飾子・戻り値なども変わった場合、その部分も別に表示します。オーバーロードは名前だけでまとめません。この宣言要約を本体の対応付けには使いません。

型参照サイトのtext差分では、同じ宣言を前後それぞれ一度だけ表示し、その下に役割と型表記をまとめます。完全な参照サイトはJSONで確認できます。型表記集合が変わる場合は、同じ型宣言に残る表記を最大5件、既存の文脈として添えます。実際の依存先や関連性の推定ではなく、省略があれば件数と詳細への案内を出します。

冒頭に、**変更されたSwiftファイル数・構造観測のある/ないファイル数**を出し、観測のない変更ファイルを列挙します。元データは両スナップショットのソース内容で、Gitモードもディレクトリ比較も同じ仕組みです。対象は除外設定・symlink除外などを適用した後の入力Swiftファイルであり、文書や除外ファイルを含むPR全体の網羅率ではありません。

さらに、変更された入力ファイル内の、対象メンバーの本体比較状態を表示します。

| 状態 | 意味 |
| --- | --- |
| `changed-metrics` | 本体のtoken列と、追跡する構造指標が変化。textでは対応する構造観測にまとめる |
| `changed-syntax-only` | 本体のtoken列は変わったが、分岐等の追跡指標は同じ。通常diffで確認が必要 |
| `not-compared` | 引数節変更・同一キーの重複・本体の追加/削除などで比較できなかった。理由と前後の位置を出す |

比較した本体数とtoken列が同一だった本体数も表示します。同一本体の一覧は省略します。token比較はコメント・整形を除外し、呼び出し式・リテラルの変更を認識しますが、実行結果の正しさは判定しません。本体比較対象外のトップレベル関数等は、ファイルの変更としては見えますが、個別本体の一覧には出ません。構造観測があるファイルでも、全変更を説明できているとは限りません。

diffのtextでは、全`#if`分岐を読むという共通NOTEを一度だけ表示します。条件ヘッダーが前後で一致しない場合は位置付きで表示し、重複型の照合に関する注意は個別に残します。全位置の前後一覧はJSONの`notices`に保持します。

## 案内から通常diffへ進む

text末尾の`Inspect source hunks:`に、比較元・先を固定した再実行コマンドが出ます。`FILE`を案内されたパスに置き換えるとファイル全体のdiffを表示します。メンバーに表示された`after:123`等を`--at`に渡すと、その宣言範囲に重なるhunkを取り出します。

```sh
# FILEはリポジトリ（ディレクトリ比較なら入力ルート）からの相対パス
sekka diff BASE --head HEAD --show-diff 'Sources/Model.swift'
# IDは直前のtext末尾に表示された値。宣言先頭から離れた変更も含める
sekka diff BASE --head HEAD --show-diff 'Sources/Model.swift' --at after:123 --expect-input ID
```

行指定には入力IDが必須です。コメント追加や作業ツリー変更も含め、前回の解析入力と異なる場合は終了コード2で停止するので、案内を取り直してください。同一実行内では取得済みソースからdiffを作ります。対応が曖昧・トップレベル関数等の未対応構文なら、ファイル全体へ戻ったことを明示します。hunkには隣接する変更や文脈も含まれます。GitHub/JSON形式での`--show-diff`は受け付けません。

## JSON schema version 2

`diff --format json` はデフォルトで `detail: compact` です。`findings` の各項目は `before` / `after` の全リストではなく **`removed` / `added`** を持ち、同じままの宣言・参照を省きます。引数の差分は必要な項目だけに `parameterChanges` を持ち、順序や引数以外の宣言変更も残します。`typeID` で型単位にグループ化できます。

型表記集合の変更では、`unchangedTypeExpressions`に共通の表記を辞書順で最大5件含めます。残りがあれば`omittedUnchangedTypeExpressionCount`を持ちます。全件はfullのbefore/after共通部分から確認できます。

`--json-detail full` なら`before` / `after` リストに加え、要約に使った引数情報を取得できます。両モードで `coverage`, `notices`, `limitations` は同一です。fullでもschema番号は2です。

`coverage.changedFiles` は各ファイルの追加/削除/変更、構文変化の有無、構造観測数を持ちます。`coverage.bodyComparisons` は変更または比較省略の一覧です。理由コードは `parameter-clause-changed`, `no-exact-member-match`, `ambiguous-member-identity`, `ambiguous-type-identity`, `body-added`, `body-removed`, `type-added`, `type-removed`, `tracked-counts-changed`, `tracked-counts-unchanged`。型の追加・削除では比較相手がない本体もJSONに明示します。textでは宣言一覧と重なる追加・削除の本体説明を型ごとの件数にまとめます。既存型は宣言が追加だけ・削除だけの場合に限り集約し、改名や引数変更、曖昧な照合は個別に表示します。詳細は`coverage.bodyComparisons`を参照してください。

`scan --format json` はsnapshotを出力し、`--json-detail` は指定できません。token列・元ソースは内部比較専用でJSONには出しません。

## 観測する事実

| ルールID | 観測内容 |
| --- | --- |
| `type-added` / `type-removed` | class / struct / actor / enum / protocol / extension の追加・削除 |
| `type-header-changed` | 型宣言の属性・modifier・generic constraint・継承節の記述の変更（例: `@MainActor` の追加） |
| `property-initializer-changed` | 一意に対応する型内プロパティの初期化式の追加・削除・トークン変更。値や副作用の良否は判定せず、宣言位置へ案内 |
| `members-changed` | プロパティ・関数・initializer・enum case・typealiasの宣言の変更。全アクセスレベルを含む |
| `type-references-changed` | 明示された型の式の集合の変化。プロパティ、引数、戻り値、継承節、case payload、typealiasが対象 |
| `reference-sites-changed` | 型の式の集合は同じでも、それを書くメンバー・役割が変化 |
| `body-structure-changed` | 対応するメンバー内の制御フロー構文・クロージャ・明示的な `self.property =` の個数の変化 |
| `direct-forwarding-shape` | メソッド本体が1つの呼び出しだけで、全引数を1回ずつ変換せず渡す形になったこと |

制御フロー構文は `if`, `guard`, `switch`, `for`, `while`, `repeat`, `catch` の個数です。経路数や循環的複雑度ではありません。`switch` のcase数、三項演算子、短絡演算子は含みません。クロージャ等の内側も含む構文上の個数で、実行回数ではありません。token数は補助情報として表示し、その変化だけでは通知しません。

`self.property =` はその明示形だけを数えます。`property =`, `+=`, `inout`, 通信、getterや呼び出し先に隠れた作用は未解析であり、**副作用の総数ではありません**。

単純転送は「不要なバケツリレー」とは断定しません。呼び出し先、副作用、認可・抽象化の境界、複数層をまたぐ経路は未解析です。新しい型は宣言全体を1つの観測として表示し、内部メソッドの追加ルールを重ねて通知しません。

## 精度と制約

- `Box<User>` や `any Store` は型の**式の記述**として数えます。名前解決・型推論をしていないため、真の依存辺やfan-outとは呼びません。同名の別型も解決しません。
- `class A: B` のBがclassかprotocolかを推測せず、継承節の記述として出します。循環・fan-in・推移的影響は未実装です。
- 型の識別はファイルパス＋種別＋入れ子の名前＋同名宣言の出現順です。移動・改名は削除と追加です。extensionは独立の記録とし、元の型には統合しません。
- 関数の対応付けは名前＋引数節です。引数変更は宣言の変更として出し、本体同士を無理に対応付けません。同一キーが複数ある場合も本体比較をスキップします。
- `#if` は全分岐を含みます。macroの展開、generic constraintの解決、module/target判定、呼び出しグラフ、純粋性は未対応です。
- 関数内のローカル型、トップレベル関数、subscript、deinit、associatedtype等は現在の対象外です。前後で一意に対応する型内プロパティのinitializerはトークン変更を案内します。型・プロパティの追加削除や改名、重複宣言はinitializerを個別対応させません。
- 構文エラー・読み取りエラーがある場合は終了コード2で停止します。部分的な「観測なし」を成功として出しません。UTF-8のみ対応です。
- JSONには常に `analysis: syntax-only`, `limitations`, `notices` を含めます。同じ入力・設定・ツールバージョンなら同じ並びで出します。

