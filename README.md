# Sekka — Swiftの変更を、構造の変化として見る

Swift 6以降のコードを対象にした、実験段階のCLIです。LLM・対象アプリのビルド・Xcodeプロジェクトの読み込みは不要。Gitの変更前後から、設計を見直す材料になる構文上の事実を出します。

**良い設計・悪い設計は判定しません。検出できなかったことを「問題なし」とも扱いません。**

現在位置・次の作業・マイルストーンは [ROADMAP.md](ROADMAP.md) にまとめています。0.2の実装は完了し、現在はレビューの負担を減らせるかを検証する段階です。

Sekka（セッカ）は、葉を糸でつないで巣を作る鳥に由来します。旧名はPatchworkです。CLI名は`sekka`に変更しました。

## まず試す

解析にはGitが必要です（ディレクトリ比較のtextでも入力識別値の生成に使用）。

開発・動作確認環境: macOS / Swift 6.3.3。SwiftSyntax 603.0.1を固定して利用しています。古いSwift 6.xツールチェーンでのビルド互換性は未検証です。

```sh
git clone https://github.com/KantoYamamoto/sekka.git
cd sekka
swift build
.build/debug/sekka diff --before Examples/before --after Examples/after
```

最初の `swift build` は**Sekka自体とその依存ライブラリ**をビルドします。以降、対象コードの解析はバイナリ単独で実行できます。初回の依存取得にはネットワークが必要ですが、解析はローカルで完結します。

同梱例では、enum case追加、ViewModelの明示型参照増加、SwiftUIの状態・条件分岐・クロージャ増加、引数をそのまま渡すメソッド追加が見えます。fixtureの依存型は実装していません。ビルド不要で解析できることを試すためです。

実行結果は [docs/demo-output.txt](docs/demo-output.txt) にも保存しています。

実PRでの出力比較と対照実験は [docs/review-output-v2.md](docs/review-output-v2.md) を参照してください。

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

## レビュー向け出力（0.2）

textは型ごとに観測をまとめます。同じ型内で前後とも名前が一意な関数・initializerの引数変更は、長い宣言を2本並べる代わりに「追加・削除された引数」で表示します。引数以外のアクセス修飾子・戻り値なども変わった場合、その部分も別に表示します。オーバーロードは名前だけでまとめません。この宣言要約を本体の対応付けには使いません。

冒頭に、**変更されたSwiftファイル数・構造観測のある/ないファイル数**を出し、観測のない変更ファイルを列挙します。元データは両スナップショットのソース内容で、Gitモードもディレクトリ比較も同じ仕組みです。対象は除外設定・symlink除外などを適用した後の入力Swiftファイルであり、文書や除外ファイルを含むPR全体の網羅率ではありません。

さらに、変更された入力ファイル内の、対象メンバーの本体比較状態を表示します。

| 状態 | 意味 |
| --- | --- |
| `changed-metrics` | 本体のtoken列と、追跡する構造指標が変化。textでは対応する構造観測にまとめる |
| `changed-syntax-only` | 本体のtoken列は変わったが、分岐等の追跡指標は同じ。通常diffで確認が必要 |
| `not-compared` | 引数節変更・同一キーの重複・本体の追加/削除などで比較できなかった。理由と前後の位置を出す |

比較した本体数とtoken列が同一だった本体数も表示します。同一本体の一覧は省略します。token比較はコメント・整形を除外し、呼び出し式・リテラルの変更を認識しますが、実行結果の正しさは判定しません。本体比較対象外のトップレベル関数やstored propertyのinitializer等は、ファイルの変更としては見えますが、個別本体の一覧には出ません。構造観測があるファイルでも、全変更を説明できているとは限りません。

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

`--json-detail full` なら従来の `before` / `after` リストに加え、要約に使った引数情報を取得できます。両モードで `coverage`, `notices`, `limitations` は同一です。**schema 1向けに `findings[].after` 等を読んでいたスクリプトは、fullを指定するかschema 2へ対応してください。** fullでもschema番号は2です。

`coverage.changedFiles` は各ファイルの追加/削除/変更、構文変化の有無、構造観測数を持ちます。`coverage.bodyComparisons` は変更または比較省略の一覧です。理由コードは `parameter-clause-changed`, `no-exact-member-match`, `ambiguous-member-identity`, `ambiguous-type-identity`, `body-added`, `body-removed`, `type-added`, `type-removed`, `tracked-counts-changed`, `tracked-counts-unchanged`。型の追加・削除では比較相手がない本体もJSONに明示します。textでは宣言一覧と重なる追加・削除の本体説明を型ごとの件数にまとめます。既存型は宣言が追加だけ・削除だけの場合に限り集約し、改名や引数変更、曖昧な照合は個別に表示します。詳細は`coverage.bodyComparisons`を参照してください。

`scan --format json` はsnapshot出力を継続し、`--json-detail` は指定できません。token列・元ソースは内部比較専用でJSONには出しません。

## 観測する事実

| ルールID | 観測内容 |
| --- | --- |
| `type-added` / `type-removed` | class / struct / actor / enum / protocol / extension の追加・削除 |
| `type-header-changed` | 型宣言の属性・modifier・generic constraint・継承節の記述の変更（例: `@MainActor` の追加） |
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
- 関数内のローカル型、トップレベル関数、subscript、deinit、associatedtype等は初版の対象外です。stored propertyのinitializer値は比較しません。
- 構文エラー・読み取りエラーがある場合は終了コード2で停止します。部分的な「観測なし」を成功として出しません。UTF-8のみ対応です。
- JSONには常に `analysis: syntax-only`, `limitations`, `notices` を含めます。同じ入力・設定・ツールバージョンなら同じ並びで出します。

## CIでの使い方

まずは通知のみの運用を想定しています。GitHub Actionsのログに表示できる `--format github` を実装しています（annotation形式の実GitHub上での表示は未検証）。構造観測に加えて、観測のない変更ファイルや本体比較の状態もnoticeとして出します。通常は観測があっても終了コード0。明示的に `--fail-on-findings` を付けると構造観測がある場合に1になります。比較範囲の説明だけでは1にしません。解析失敗は常に2です。

Sekkaバイナリが配置され、比較元の履歴を取得済みのrunnerで:

```sh
sekka diff origin/main --head HEAD --merge-base --format github
```

PRでは「baseブランチ先端との差」より共通祖先からの比較が適します。shallow cloneでは必要な履歴を取得してください。配布方法・実際のworkflowは、使い勝手を確かめてから決めます。

## 開発

```sh
swift test
python3 Scripts/smoke.py .build/debug/sekka
```

実装方針と選択理由は [判断記録](docs/decisions/README.md) に変更の都度残します。設計・今後の候補は [docs/ideas.md](docs/ideas.md)、参考OSSと採用した考え方は [docs/references.md](docs/references.md) に記録しています。

## ライセンス

Sekkaのコードと文書は[MIT License](LICENSE)で公開しています。Copyright (c) 2026 KantoYamamoto。

依存するSwiftSyntaxはApache License 2.0（Runtime Library Exception付き）です。SekkaのMITライセンスで依存ライブラリの条件を置き換えることはありません。[依存と配布時の確認事項](docs/references.md)を参照してください。

Sekka自身のSwift変更では、[自己利用・比較検証の手順](docs/validation/protocol.md)に従い、新旧評価器の案内と通常diffを保存して改善点を記録します。

自身のPRでは[GitHub Actions](.github/workflows/pr-review.yml)がテスト・CLIチェックと構造案内を実行します。PRのChecksからジョブ要約を開くと、変更ファイルへのリンクと展開可能な案内を確認できます。通常diffとJSONは実行ページのartifactに14日間保存します。評価器はそのPRのビルドであり、独立レビューではありません。
