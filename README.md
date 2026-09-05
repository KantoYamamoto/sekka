# Patchwork — Swiftの変更を、構造の変化として見る

Swift 6以降のコードを対象にした、実験段階のCLIです。LLM・対象アプリのビルド・Xcodeプロジェクトの読み込みは不要。Gitの変更前後から、設計を見直す材料になる構文上の事実を出します。

**良い設計・悪い設計は判定しません。検出できなかったことを「問題なし」とも扱いません。**

## まず試す

開発・動作確認環境: macOS / Swift 6.3.3。SwiftSyntax 603.0.1を固定して利用しています。古いSwift 6.xツールチェーンでのビルド互換性は未検証です。

```sh
cd /path/to/patchwork
swift build
.build/debug/patchwork diff --before Examples/before --after Examples/after
```

最初の `swift build` は**Patchwork自体とその依存ライブラリ**をビルドします。以降、対象コードの解析はバイナリ単独で実行できます。初回の依存取得にはネットワークが必要ですが、解析はローカルで完結します。

同梱例では、enum case追加、ViewModelの明示型参照増加、SwiftUIの状態・条件分岐・クロージャ増加、引数をそのまま渡すメソッド追加が見えます。fixtureの依存型は実装していません。ビルド不要で解析できることを試すためです。

実行結果は [docs/demo-output.txt](docs/demo-output.txt) にも保存しています。

## 実プロジェクトで使う

```sh
# 現在のファイルの構文情報を列挙
.build/debug/patchwork scan --path /path/to/MyApp

# 指定コミットと作業ツリーを比較（未コミットの変更も含む）
.build/debug/patchwork diff HEAD --path /path/to/MyApp

# PRブランチのコミット同士を、共通祖先から比較
.build/debug/patchwork diff origin/main --head HEAD --merge-base --path /path/to/MyApp

# AIやスクリプトへ渡す。JSON以外は標準出力に混ぜない
.build/debug/patchwork diff HEAD --path /path/to/MyApp --format json

# サードパーティーや生成コードを除外（ファイル/ディレクトリの相対prefix、globではない）
.build/debug/patchwork diff HEAD --path /path/to/MyApp --exclude Vendor --exclude Sources/Generated
```

Gitモードでは `--path` 内のリポジトリ全体を解析します。作業ツリー側は追跡済みファイルとGitで無視されていない未追跡ファイルを対象にし、削除・ステージ済み・未ステージの変更を含みます。`--head` を指定すると作業ツリーを読みません。Git checkoutや対象プロジェクトのスクリプト実行はしません。

scanとディレクトリ比較は指定ディレクトリ配下を読み、`.gitignore` は解釈しません。全モードでシンボリックリンクをスキップし、`.build`, `.swiftpm`, `.git`, `Pods`, `Carthage`, `DerivedData` を除外します。テストコードもデフォルトで含まれます。

## 初版で取る事実

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

まずは通知のみの運用を想定しています。GitHub Actionsのログに表示できる `--format github` を実装しています（実GitHub上での表示は未検証）。通常は観測があっても終了コード0。明示的に `--fail-on-findings` を付けると1になります。解析失敗は常に2です。

Patchworkバイナリが配置され、比較元の履歴を取得済みのrunnerで:

```sh
patchwork diff origin/main --head HEAD --merge-base --format github
```

PRでは「baseブランチ先端との差」より共通祖先からの比較が適します。shallow cloneでは必要な履歴を取得してください。リポジトリ公開・配布方法・実際のworkflowは、使い勝手を確かめてから決めます。

## 開発

```sh
swift test
python3 Scripts/smoke.py .build/debug/patchwork
```

設計・今後の候補は [docs/ideas.md](docs/ideas.md)、参考OSSと採用した考え方は [docs/references.md](docs/references.md) に記録しています。公開ライセンスはまだ決めていません。
