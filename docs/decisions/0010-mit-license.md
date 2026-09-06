# 0010: MITライセンスを採用する

**方針：Sekkaを再利用・配布する場合はMITの表示条件を守り、第三者のコードには元のライセンスを適用する。**

- 記録日：2026-09-06
- 状態：採用
- 経緯：ユーザーが「MITでOK」と指定。[0009](0009-sekka.md)のライセンス未設定を解消。

## 目的・状況

公開済みの試作を、他の開発者が利用・改変・再配布できるように条件を明示する。ライセンスの選択はユーザーの指示であり、実装側が権利者の意思を推測して選んだものではない。

## What — 選ぶこと

Sekkaのコード・文書に標準MIT Licenseを適用する。著作権表示は公開GitHub名に合わせて`Copyright (c) 2026 KantoYamamoto`とする。依存ライブラリはそれぞれのライセンスを維持する。

## Why — 選ぶ理由

ユーザーが選択したMITは、著作権・許諾表示の保持を条件に利用・改変・再配布・販売などを広く許す。独自の追加条件を入れず、利用者が標準の条件を確認できるようにする。

## Why not — 別案を採らない理由

未設定のままでは一般的な再利用の許諾が明確にならない。商用利用禁止や改変公開義務は追加しない。他ライセンスとの網羅的な比較は行っていない。

## How — 実現方法

GitHubのLicenses APIから標準本文を取得し、年・著作権者だけを置き換えてルートの[LICENSE](../../LICENSE)に保存する。[README](../../README.md)からリンクする。依存するSwiftSyntax 603.0.1のApache 2.0とRuntime Library Exceptionを確認し、[参考資料](../references.md)の配布時確認を維持する。MITを追加しても依存のライセンスは変更しない。

## 制約・見直す条件

他者のソースや素材を取り込む場合は、取り込む権利と元の表示条件を確認する。バイナリ配布時は依存・同梱物のLICENSE/NOTICE等を確認する。MITは無保証・責任制限の条項を持つが、あらゆる法的責任が必ず免除されるとの説明はしない。ライセンス選定だけで各ファイルの権利関係を法的に検証したことにはならない。

## 根拠・確認

- [OSIのMIT本文](https://opensource.org/license/mit)とGitHub Licenses APIのテンプレートを確認。
- [GitHubの公開ライセンス説明](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)を参照。
- [SwiftSyntax 603.0.1 LICENSE](https://github.com/swiftlang/swift-syntax/blob/603.0.1/LICENSE.txt)で依存側の条件を確認。
- 標準本文との一致・文書リンク・diffの空白を確認する。コード変更はなく、解析テストの再実行は行わない。
