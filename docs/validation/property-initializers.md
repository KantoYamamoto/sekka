# 初期化式変更の案内

**観測のあるファイルで変更箇所が埋もれる場合は、再現入力で個別案内とdiff到達を確認する。**

Issue #22 / 実装 `52d5894`。比較元 `f60a71a`。判断は[0020](../decisions/0020-property-initializers.md)。

## 確認結果

- Swift 49テスト・CLI/Git 27チェック・Python 10テスト成功。
- 固定15probe成功。stored-thresholdは初期値変更1件、mixed-initializerはメンバー追加と初期値変更の両方を出す。残るtop-level等を網羅したとはしない。
- 初期化式の追加・削除、複数binding、コメント/整形、UTF-8の綴り、クロージャ、重複・改名・型追加削除の非対応をテスト。
- 長い複数行の初期化式は、案内した宣言行を`--at after:LINE`に指定して変更hunkへ到達できた。

## 自己利用

保存した旧バイナリと新バイナリで同じ実装差分を解析し、通常のSwift diff全文も読んだ。Analyzerの引数追加と本体変更、Differ/Renderer、Memberの変更が入口になった。Coverage.swiftのアクセス変更とトップレベルのテスト追加はファイル単位でのみ案内された（Issue #18）。

この実装差分のtextは新旧同一。既存プロパティの初期値変更を含まないためで、新ルールの改善は固定probeとテストで確認した。実装者が内容を知った状態での自己レビューであり、独立した効率比較ではない。raw bundleは`.build/self-review/property-initializers`に保持し公開しない。

PR上のActions・コメントの最終確認はPR本文に記録する。
