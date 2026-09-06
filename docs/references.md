# 参考にしたOSS

調査日: 2026-09-06。公開READMEと公式説明から設計の参考にした。以下のツールのルール実装をコピーしていない。

| OSS | 参考にした点 | Sekkaでの扱い |
| --- | --- | --- |
| [SwiftLint](https://github.com/realm/SwiftLint) | 構文中心の通常lintと、ビルド情報を使うanalyzeの区別。ルールID・位置付きの診断・CI出力 | 初版は構文解析に限定。観測にはIDとソース位置を付ける。成功/観測/解析失敗を区別 |
| [Periphery](https://github.com/peripheryapp/periphery) | ビルドが生成するindexを使う解析と、未使用宣言を追う参照情報の重要性 | 正確な参照解析には追加情報が必要と認識し、初版の型名記述を解決済みの依存と呼ばない |
| [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) | CLIとして実行でき、lint用途にも使える構成 | 解析対象のビルドを要求せず、ローカルとCIで同じCLIを使う |
| [swift-format](https://github.com/swiftlang/swift-format) | ファイル/構文木から動く整形・lintの分離 | ソースの構文を直接扱い、ターゲットのビルドとツールのビルドを分ける |
| [SwiftSyntax](https://github.com/swiftlang/swift-syntax) | source-accurateな構文木とvisitor API | 唯一の直接外部依存としてSwiftParser/SwiftSyntaxを使用。文字列・コメントを正規表現で構造と誤認しない |

SwiftSyntaxは通常のSwiftPM依存として利用し、コードをvendorしていない。依存のライセンスは[公式LICENSE](https://github.com/swiftlang/swift-syntax/blob/603.0.1/LICENSE.txt)を参照。バイナリ配布時の必要なライセンス同梱は配布工程で確認する。

競合が存在しない・独自性が確立したとは判断していない。今回はプロトタイプの入力・解析の誠実さ・出力設計を考えるための参考調査。
