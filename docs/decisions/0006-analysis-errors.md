# 0006: 不完全な入力を成功にしない

**方針：入力を正常に読み取れない・構文解析できない場合は、同じ入力から再現できるエラーを返し、部分結果を成功として返さない。**

- 記録日：2026-09-06
- 状態：採用
- 経緯：初版 `691d82e` の実装とテストから遡及記録

## 目的・状況

CIやAIが「観測なし」を利用する際、壊れた入力や誤ったGit refを、構造変化がない結果と混同しないようにする。

## What — 選ぶこと

読み取り・構文解析・Git入力の失敗は終了コード2にする。同じ入力/設定の失敗出力も決定論性の対象にする。本番CLIでdiffの両側にSwiftファイルがない場合は入力を確認するエラーにし、正常な削除や空の片側とは区別する。実験の空の索引を本番と同じ契約へ勝手に変更しない。

## Why — 選ぶ理由

解析不能ファイルを落とした結果だけを成功として出すと、重要な変更がないように見える。原因が分かる失敗の方が、利用側が入力を修正できる。#96で実験CLI/診断のFoundation NSErrorにNSUnderlyingErrorのメモリアドレスが混じることを確認した。成功時だけのbyte一致では不十分なので、#98では入力エラー表示を同じCLI targetのhelperへ統合する。

## Why not — 別案を採らない理由

壊れたファイルをスキップして継続する案は結果を得やすいが、初版の成功/失敗契約では未解析を見逃しやすい。構造観測があるだけで失敗する運用も標準にはせず、`--fail-on-findings` の明示指定に分ける。

Foundationのdescriptionを保存後に正規表現で消す案は、実際の失敗出力の不安定さを隠すため採らない。CLI/診断ごとにrendererを持つ案も同じ境界の修正が分散するため採らない。入力表示のhelperをlibraryの解析APIへ公開する必要はない。

## How — 実現方法

[Inputs.swift](../../Sources/SekkaCore/Inputs.swift)が入力エラーを投げ、[Analyzer.swift](../../Sources/SekkaCore/Analyzer.swift)が構文エラーで停止する。[CLI](../../Sources/sekka/main.swift)は解析完了後に出力し、例外はstderrと終了コード2へ変換する。観測による終了コード1は明示オプション時だけとする。

実験CLIと一時合成したinventory診断は同じ[InputError.swift](../../Experiments/StructuralContext/Sources/context-probe/InputError.swift)を使う。Foundationの入力失敗では理由/domain/codeと、取得できるfile pathだけを表示し、nested userInfo/underlying errorのdescriptionは出さない。UTF8文字列readerはpathがないFoundation code259を返すことがあったため、reader自身がsource pathと読取操作を付ける。code259だけから失敗原因をUTF8と断定しない。pathは引用/escapeして行構造を壊さない。Swiftのparse位置/usage等の既存非Foundationエラーは維持する。本番CLI/検索library/有用性の条件はこの修正で変更しない。

## 制約・見直す条件

1ファイルの構文エラーでも結果全体を返さない。作業途中のコードで部分結果が必要になった場合は、既定動作を黙って変えず、不完全であることを機械可読に示す別モードを検討する。

## 根拠・確認

[解析テスト](../../Tests/SekkaCoreTests/AnalyzerTests.swift)と[CLIチェック](../../Scripts/smoke.py)で構文エラー、無効ref、空入力、終了コードを確認。これは網羅的な設計検証ではなく、入力失敗を隠さない契約の確認である。

実験の[CLI対照](../../Experiments/StructuralContext/verify.py)は欠落directory、非directory、UTF8、parse、symlink、usageを二回実行し、exit/stdout/stderr全bytes一致・部分成功拒否・原因/pathの表示を確認する。診断も同じhelperで既存37対照を確認する。#96の元失敗/旧freezeは書き換えず、#98の実行receiptは別に保存する。
