# Sekka — Swiftの変更を、既存の構造と照らして見る

Sekka（セッカ）は、Swiftの変更を受け入れる前に「既存の構造へどう組み込むか」を考えるための、実験段階のCLIです。継ぎ足しのたびに見落としやすい、型・メンバー・明示的な型参照・本体の変化を整理します。

目指すのは、例えば新しい窓口を作るときに既存の役割分担を見直したり、SwiftUIへ状態や表示を追加するときに所有者や分割境界を考え直したりする入口です。**現在できるのは構文上の変更と確認先の案内です。役割の重複や妥当な分割を自動で見つける機能はありません。**

対象はSwift 6以降。解析時にLLM・対象アプリのビルド・Xcodeプロジェクトの読み込みは不要です。観測事実と不明な範囲を示し、設計の判断は人間やAIに委ねます。観測がないことは「問題なし」を意味しません。

## まず試す

開発・動作確認環境はmacOS / Swift 6.3.3、SwiftSyntax 603.0.1です。古いSwift 6.xツールチェーンでのビルド互換性は未検証です。Gitが必要です。

```sh
git clone https://github.com/KantoYamamoto/sekka.git
cd sekka
swift build
.build/debug/sekka diff --before Examples/before --after Examples/after
```

初回はSekkaと依存ライブラリをビルドします。依存取得にはネットワークが必要ですが、以降の解析はローカルで完結します。同梱例ではenum case・型参照・SwiftUIの状態や分岐・単純転送の追加を確認できます。対象例自体のビルドは不要です。

## PRのレビューで使う

```sh
.build/debug/sekka diff origin/main --head HEAD --merge-base --path /path/to/MyApp
```

1. 型ごとの変更と、観測のない変更ファイルを見て、確認する場所を選びます。
2. その変更が既存の役割・状態・依存の配置にどう関わるかを、周辺コードと照らして考えます。
3. 案内の位置から通常diffへ進みます。本体を比較できなかった箇所や、案内に出ない変更も確認します。

引数は追加・削除を要約し、初期化式は変更事実と位置を示します。本体のトークン比較は処理の正しさを証明しません。型参照は構文上の記述であり、解決済みの依存関係ではありません。型表記が変わった箇所には、同じままの表記も少量添え、既存の構造と照らす手掛かりにします。

JSONが必要なら`--format json`、完全な前後一覧が必要なら`--json-detail full`を指定します。作業ツリーとの比較、除外設定、`--show-diff`、JSONの契約は[CLIと出力の仕様](docs/cli.md)にまとめています。

## GitHub Actionsで使う

このリポジトリでは、PRごとにテストとSekkaの解析を実行し、botコメント1件を更新します。コメントには確認ファイルへのリンク、折りたたみ可能な構造案内、比較SHAと解析限界を表示します。詳細では`├─`・`└─`・`│`で階層を表します。

通常diff・text・JSONはActionsのartifactに14日間保存します。解析と投稿の権限を分け、PRのコードに投稿用tokenを渡しません。これはSekka自身での運用であり、他のリポジトリへそのまま導入できる配布用Actionではありません。[仕組みと導入上の前提](docs/ci.md)を参照してください。

## 現在の段階

複数ファイルのSwift差分から読む場所を選ぶ用途で試用しています。表示・diffへの導線・PR投稿は検証済みですが、通常diffのみのレビューより手間や見落としが減るか、構造を見直す助けになるかは確立していません。

[ROADMAP](ROADMAP.md)に現在位置と次の検証、[目的と候補](docs/ideas.md)に将来案、[試用意見](docs/feedback-summary.md)に根拠をまとめています。対応構文の数だけを増やすことは開発目標にしません。

## 開発に参加する

[開発手順](docs/development.md)では、局所の変更とプロジェクト全体の目的の両方を確認します。実装方針と選択理由は[判断記録](docs/decisions/README.md)、検証結果は[検証手順と記録](docs/validation/protocol.md)から追えます。

```sh
swift test
python3 Scripts/smoke.py .build/debug/sekka
python3 -m unittest discover -s Scripts -p 'test_*.py'
```

## ライセンス

コードと文書は[MIT License](LICENSE)です。Copyright (c) 2026 KantoYamamoto。SwiftSyntaxにはApache License 2.0（Runtime Library Exception付き）が適用されます。[依存とOSSの参考資料](docs/references.md)を参照してください。
