# 再掲文脈と条件コンパイル位置: #38

[PR #49](https://github.com/KantoYamamoto/sekka/pull/49)マージ済み。最終head `eea9291` のActions `34211864954` が成功。8成果物でcompact notices 0・省略22・full notices 22を照合し、実コメント `5583050995` のheadとfull位置への案内を確認した。

2026-09-08。既存の設計6ケース、`struct Report { let finding: Finding }`へ`let location: Location`を追加する合成例、Sekka PR #33を使った編集比較。rawはignoredの`.build/context-noise`。独立レビューではなく既読入力の比較である。

| 比較 | 結果と判断 |
| --- | --- |
| 共通型表記を常時表示 / 省略 | Loggerは62 bytes、Finding例は63 bytes、Int例は59 bytes減る。同時に既存窓口の手掛かりも消える |
| 要求時のみ表示 | 通常出力は省略案と同じだが、確認先を選ぶ前に追加操作が必要。今回は新フラグを作らない |
| PR #33の共通型表記を省略 | 9表記を省くと12,743→12,400 bytes。ただし関連しそうなFinding等とString等の両方を消す |
| 未変更ファイルの条件位置を省略 | PR #33の22件すべてが未変更ファイルの#if位置。共通制約とfullの位置を保持してcompactを短くできる |

表の文脈比較は同じPython整形によるUTF-8 bytesで、Swift生成JSONそのもののサイズやtoken数ではない。PR #33の固定入力は`e76a56411feb18a811185ba263868947d3778f36` → `506e006a65e1659bd5714e45dd99dbc7d70bce73`。

実装は条件位置の省略に絞った。型表記は暫定表示を維持し、未読入力の比較で、元のLogger例のように既存の配置を見直す助けになったかを問う。現段階では利益を確定していない。

Swift 65テストが通過。未変更fixtureの条件位置だけを省き、変更ファイルの条件・未変更ファイルの重複型注意・全分岐解析の制約・full JSONの全位置を保持する。コメントだけの変更も変更ファイルとして位置を残す。

CLI/Git 39チェックも通過。PR #33の実際のSwift生成compact JSONは13,024→8,346 bytes、noticesは22→0件、省略数22を明示した。noticesと省略数以外のcompact内容は一致し、full JSONはバイト一致した。共通制約はlimitationsに残る。この短縮をtoken数やレビュー時間の短縮とは呼ばない。

`b25e90b`対親`268fe91`を新旧評価器で自己利用し、通常Swift diff全体と出力を読んだ。full JSONは一致し、集計メンバーとフィルタ処理の入口が見えた。分類の保持と省略条件は通常diff・境界テストで確認した。独立した実装レビュアーも重要な指摘なし。追加/削除ファイルの条件位置保持を実CLIで確認したとの報告がある。これは未読のPRレビュー利益比較ではない。
