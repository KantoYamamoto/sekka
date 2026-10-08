# Sekka — Swiftの変更を、既存の構造と照らして見る

Sekka（セッカ）は、Swiftの変更を受け入れる前に「既存の構造へどう組み込むか」を考えるための、実験段階のCLIです。局所的には成立する追加でも、同じ調整処理が呼び出し側へ広がるなど、既存の配置から見直した方がよい場合に気づくことを目指しています。

通常diffと併用し、変更の判断に必要な周辺の実装を、関連する根拠と一緒に示すことを目指しています。例えば、新しい処理を追加した場所が既に使っている窓口の実装を照らし、責務の置き場所を考え直す入口にします。**構造差分の案内に加え、共有callbackの引数追加が、追加値を捨てる既存closureへ波及する場合のAPI境界比較を限定試行しています。役割の重複や妥当な分割を一般に見つける機能はありません。**

対象はSwift 6以降。解析時にLLM・対象アプリのビルド・Xcodeプロジェクトの読み込みは不要です。観測事実と不明な範囲を示し、設計の判断は人間やAIに委ねます。観測がないことは「問題なし」を意味しません。

## まず試す

開発・動作確認環境はmacOS / Swift 6.3.3・6.4、SwiftSyntax 603.0.1です。古いSwift 6.xツールチェーンでのビルド互換性は未検証です。Gitが必要です。

```sh
git clone https://github.com/KantoYamamoto/sekka.git
cd sekka
swift build
SEKKA_BIN="$(swift build --show-bin-path)/sekka"
"$SEKKA_BIN" diff --before Examples/before --after Examples/after
```

初回はSekkaと依存ライブラリをビルドします。依存取得にはネットワークが必要ですが、以降の解析はローカルで完結します。同梱例ではenum case・型参照・SwiftUIの状態や分岐・単純転送の追加を確認できます。対象例自体のビルドは不要です。

## PRのレビューで使う

```sh
"$SEKKA_BIN" diff origin/main --head HEAD --merge-base --path /path/to/MyApp
```

1. 型ごとの変更と、観測のない変更ファイルを見て、確認する場所を選びます。
2. その変更が既存の役割・状態・依存の配置にどう関わるかを、周辺コードと照らして考えます。
3. 案内の位置から通常diffへ進みます。本体を比較できなかった箇所や、案内に出ない変更も確認します。

引数は追加・削除を要約し、初期化式は変更事実と位置を示します。本体のトークン比較は処理の正しさを証明しません。型参照は構文上の記述であり、解決済みの依存関係ではありません。型表記が変わった箇所には、同じままの表記も少量添え、既存の構造と照らす手掛かりにします。

JSONが必要なら`--format json`、完全な前後一覧が必要なら`--json-detail full`を指定します。作業ツリーとの比較、除外設定、`--show-diff`、JSONの契約は[CLIと出力の仕様](docs/cli.md)にまとめています。

## API境界を比較する限定試行

```sh
"$SEKKA_BIN" review origin/main --head HEAD --merge-base --path /path/to/MyApp
# 自作例: callbackへcontextを足すと、使わない側もclosure引数を合わせる必要がある
"$SEKKA_BIN" review --before Experiments/DependencyRelay/ContractFixtures/before --after Experiments/DependencyRelay/ContractFixtures/after
```

一意なstructの明示initializerでcallbackの末尾引数が増え、既存closureがその値を捨て、元の引数参照を揃えるとbody tokenが同じ場合をまとめます。API/callerの前後位置を示し、「現APIを維持」「単一event payload」「旧入口を保つ専用入口/adapter」を条件付きで比較します。これにより、使わない値のために利用側を直す境界を維持すべきか考えます。変更箇所の数を負債や欠陥の判定には使いません。

`--format json`で位置・入力hash・不明な範囲も取得できます。trailing closureや生成initializerなどは比較対象外。callee/型の意味や実行結果は解決せず、0件も設計の承認ではありません。入力は片側128 Swiftファイル・4MB/ファイル・20MB/側に限定します。[仕様と限界](docs/cli.md#api境界の限定試行review)。通常の`diff`出力とは別の試行です。

## GitHub Actionsで使う

このリポジトリでは、PRごとにテストとSekkaの解析を実行し、botコメント1件を更新します。コメントには確認ファイルへのリンク、折りたたみ可能な構造案内、API境界の限定試行、比較SHAと解析限界を表示します。実PRのapi-review成果物と、自作対照のcallback-contract成果物は分けます。これはSekka自身での表示検証であり、全PRへの常設を推奨する根拠ではありません。

## 現在の段階

本番CLIは型・メンバー・明示的な型参照・本体の変化を整理します。表示・diffへの導線・PR投稿は検証済みですが、それだけで元の目的を達成したとは扱いません。成功条件は「変更と既存構造の関係を根拠に、局所修正を続ける案と配置を見直す案を比較できること」です。

共有callback契約の試行は、[固定実source](docs/validation/callback-contract-cost.md)で五つの既存closureの適応を取得しました。ただし通常資料だけの独立レビューも同じ問いと専用入口案へ到達しています。支持は根拠整理・照合の補助に限り、独自の問題発見やレビュー時間短縮、未見PRでの有用性は未確立です。旧構造索引/状態入口/純中継の試作は採用せず、履歴と根拠を保存しています。
[ROADMAP](ROADMAP.md)に現在位置と次の検証、[目的と候補](docs/ideas.md)に将来案、[試用意見](docs/feedback-summary.md)に根拠をまとめています。対応構文の数だけを増やすことは開発目標にしません。

## ライセンス

コードと文書は[MIT License](LICENSE)です。Copyright (c) 2026 KantoYamamoto。SwiftSyntaxにはApache License 2.0（Runtime Library Exception付き）が適用されます。[依存とOSSの参考資料](docs/references.md)を参照してください。
