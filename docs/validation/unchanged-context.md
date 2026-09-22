# 未変更の関数候補への検索

2026-09-15。M1 #69 / PR単位 #74。[契約0038](../decisions/0038-outside-diff-context.md)、[実装範囲](../../Experiments/StructuralContext/README.md)。本番CLIは変更しない。

## 事実性の結果

既存7例を同じ入力のまま実験CLIへ渡し、JSONの決定論性、型注釈・call・候補宣言の新旧位置、textの集約を確認した。名称や期待に合わせた対象ソースの変更はない。

| 既知対照 | 候補 / 入口 | 観測と未対応 |
| --- | --- | --- |
| dispatch-spread | Logger.record 1 / 3 | 3つの変更関数から未変更Logger.swift:2へ到達 |
| dispatch-growth | Logger.record 1 / 2 | 今回変わった2入口のみ。既存Checkoutの組合せを探す能力は未対応 |
| single-site | Logger.record 1 / 1 | 反復を要求せず案内。分散拡大とは判定しない |
| dispatch-separate-policy | Logger.record 1 / 3 | spreadとJSONが完全一致。コード外の分離要件は判断側へ残す |
| dispatch-contained | 0 | 直前が明示receiver付きcallではない。未変更callerへの逆引きは未対応 |
| consent-separated | 0 | 新規関数が対応外。名前だけでLoggerへ結び付けない |
| natural-model | 0 | 新規method/enum caseだけでは入口を作らない |

合成例で必要だった結び付けを機械化できた結果であり、実PRの配置判断や手間への有用性を測った結果ではない。CLI検証は`verify.py`に統合し、JSON/textをActions成果物にも保存する。

31テスト（索引17、検索14）で、shadow、曖昧な型/overload/macro、receiver型変更、候補宣言変更、同じファイル内の未変更宣言、行移動、無関係な別call、重複文、既存callの引数変更を挿入と呼ばない表記、対象外のnested/try/await、集約/省略/入力順、構文エラーを確認した。CLIではドット除外、Finder属性、symlink拒否、失敗時の部分出力禁止も確認した。

## 既読OSSで見える狭さ

#10で使った固定manifestの入力を再利用した。108ファイルエントリのSHA-256と入力一覧を照合した。これは既読の範囲確認であり、未見評価ではない。

| 入力 | 結果 | 限界 |
| --- | --- | --- |
| Swift Log #390 | 0候補、対応内変更0関数、新側対応外9関数 | 追加実装から既存のmetadata処理へ辿る検索を持たない |
| Alamofire #4051 | 0候補、対応内変更4関数すべてscope対象外、新側対応外4関数 | protocol/継承/generic/属性などを除く現在の索引では届かない |

0件から設計の良否を判断しない。既存Logger例での成功と、実際のSwiftコードへの適用範囲の狭さは両方残す。条件を満たす実例だけ選んで「有用」とする評価には進めない。

## 再現と残る検証

実行方法は[実験README](../../Experiments/StructuralContext/README.md)。ローカル生出力はGit管理外の`.build/unchanged-context/checks.json` / `checks.text`。独立コードレビューでは、既存callの引数変更も「追加call」と表示する点を指摘された。JSONを`newOrChangedCall`、textを「旧版に同じ文なし」へ統合して回帰テストを追加した。位置・候補の対応に追加の必須修正はなかった。[PR #76](https://github.com/KantoYamamoto/sekka/pull/76)は最終head `d048bd65c1cf26251f050a89f1f2b90ec97fc075` の[Actions](https://github.com/KantoYamamoto/sekka/actions/runs/35743959825)が成功。10成果物のhead、8CLI対照（境界1+既知7）の表示、[実コメント](https://github.com/KantoYamamoto/sekka/pull/76#issuecomment-5778831425)とsummaryの一致を確認しマージした。M1の事実性を完了とし、M2 #77へ進む。

M1の次の判断は、最低限の事実性が成立した評価器を固定し、M2で事前選定した実変更への到達範囲から確認すること。候補がほぼ出ない場合にA/Bレビューの形式だけを繰り返さず、対象外理由を見て検索範囲/方式へ戻す。候補が出た場合も、必要な未変更箇所への案内と配置を再検討する問いへの寄与を別に評価する。

## 自己利用

base `18cfa414eab30582e083688d0d4b9e986507770e` → 実装 `b23a44e707ca4baf76bb9198b3fb81e165780e33`。本番Sekkaは14変更path/7 Swift/23観測/19本体未比較を表示し、試作の削除・追加とAPI変更の入口になった。CLI接続や新規テストはfile diffでの確認が必要だった。新旧の本番評価器は未変更で、SHA-256 `e43a9ae5edfbeb5cd0958bb29546958e44b027e7654be7fab9747c119ab535d4`、完全JSONも一致した。

新試作自身にも両版の`Sources`と`Experiments/StructuralContext/Sources`の19 Swiftファイルを渡した。0候補、対応内変更1関数はscope対象外、対応外はbefore 15 / after 2関数。独立レビューの表記問題を発見する助けにはならなかった。今回の自己利用は構造の入口と限界の確認であり、新検索の有用性の証拠にはしない。生出力は`.build/self-review/unchanged-context`と`.build/unchanged-context/self.*`へ保存。
