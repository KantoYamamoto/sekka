# V03-01: Nuke PR #953の独立A/B比較

2026-09-08。[実施計画](v03-01-plan.md)の最初の比較。**この1件では、Sekka固有の有用な確認先や検索削減を確認できなかった。速度比較は判定不能。** M2全体の完了や、すべての用途で価値がないという結論にはしない。

## 入力と実施条件

公開[Nuke PR #953](https://github.com/kean/Nuke/pull/953)。base `e90e9f2daf1a089b4c88eb07fe50f38460bd08cb`、head `d66af7a929c09f69d260c3a8a5ece26fabc6bed6`。Swift 4ファイル・文書2ファイル。A/Bの同じdiffと資料manifestのSHA256を照合済み。Bの評価器hashは `3b93eb364f876ed9d4a7392b9c1c91cf2bbef14acb3274e33e7842df88bd86c7`（PR #33後、今回の改善前）。

開発会話を渡さず独立したAI担当2件に同じ課題を渡した。モデル・推論設定の上書きはしていないが、厳密な実行ID・token数は取得できていない。対象のビルド・テスト・外部レビュー閲覧は行っていない。開発担当は両結果が揃った後に通常diff・文書diff・固定headの周辺コード・Sekka出力を読んだ。

前回の起動は利用上限で完了できなかった。Aは中断前に固定diffを読み、再開時に記憶を保持していた。Bの記録は再開後の読取り。さらにAの固定SHAへのgit grepはpromisor objectの取得失敗で未完了、周辺コード1パスも存在せず失敗した。同一repoを共有するpartial cloneでは取得状態・通信待ちも影響し得るため、時間や検索成功率をツールの効果に帰属させない。

## 結果と根拠の照合

| 確認先 | A | B | 開発担当が照合した根拠 |
| --- | --- | --- | --- |
| API移行・参照型から値型への変更 | あり | あり | 旧ObservableObjectと新ImageTask.Progressのstruct、deprecated alias、移行ガイド |
| 読取り後の通知参加の寿命 | あり | あり | getterでtrue、resetにfalseへの復帰がない |
| 所有元の通知とViewの再読取り | あり | あり | willSetの通知、LazyImageのStateObject・contentへの受渡し、通知数のテスト |
| 完了・cancel・reset・再loadの値 | あり | あり | clearLoadingState、handle(result)、cancel、cache経路を確認 |
| callback境界と共通fractionテスト | なし | あり | Pipeline/Deprecated.swiftのイベント分岐・cancel抑止、既存ImageTaskProgressTests |

確認先はいずれも固定コードに根拠がある。両担当とも明確な回帰を断定せず、外部利用側の期待や実行時検証が不明と記録した。Bの5件目は追加の周辺検索で得られており、Sekka固有の誘導を示す根拠はない。

Bに事後の寄与を確認すると、通常diff・文書を先に読み、次にcandidate.textを読んでいた。JSON・ナビゲーションは未使用。確認先は通常diffでも説明でき、型表記の再掲が具体的な検索を生んだ記憶はないとの回答だった。自己申告と読取り順の影響があり、Sekkaを先に読む索引用途の効果はこの比較では分離できない。

## 読む負担と新たな問題

- 入力Swift diffは203行・7,497 bytes、文書diffは59行・3,461 bytes。Sekka textは149行・13,233 bytes。行数は減るがSwift diffよりbytesは増える。token数の代用にはしない。
- textにはNOTEが36行あり、共通条件コンパイル注意と前後の重複宣言注意が含まれる。#38で共通制約・変更に関係する注意・全解析の注意を分ける検証の実例になる。
- Aは追加検索1回（未完了）、周辺展開6回（5成功）。Bは追加検索1回、周辺展開10回。調査範囲が違い、検索削減の証拠にはならない。
- 開発担当の照合で、Deprecated.swiftへの同名extensionの先頭追加を、既存loadメソッドの削除と次のextensionの追加のように表示する問題を確認した。本体は曖昧として比較を省略する一方、構造は順序で対応している。[#41](https://github.com/KantoYamamoto/sekka/issues/41)で扱う。これはA/Bのレビュアーが見つけた効果とは数えない。

## 判断と次の検証

全PRへの推奨や機能拡大を裏付ける結果ではない。#34の対象範囲と#41の曖昧な構造対応を先に直し、#35/#38で読む負担を整理する。元の「既存構造との整合を考える入口」という目的を撤回する根拠にもまだ足りない。

次の独立比較は、未読入力を新たに固定し、Gitオブジェクトの事前取得を検証した独立コピーを各担当へ渡す。BはSekkaを先に読み、周辺検索前に確認候補を一度保存してから通常diffで検証する。後から都合よく今回の条件を変更したり、このPRの再読を時間改善の証拠にしない。#9〜#11は修正後に課題を選び直す。

## 記録の所在

Git管理外の `.build/independent-review/nuke-953/{A,B}/result.md` と `B/attribution.md` に各担当の生の記録を保持。入力repoのソース全文は公開文書へ複製しない。

- A結果SHA256: `98657c1fa7ba8f566f9cc5cfbf864809d2bb9ace7d919ac31be793c27f759e60`
- B結果SHA256: `5aabfa62662f8afbf3470ad9003f885be615c7521ea83ff6c0d49d8d56b37895`
