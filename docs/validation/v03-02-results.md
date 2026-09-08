# V03-02: 削除レビューの独立A/B結果

**方針：先読みで確認先を得ても、通常diff側も同じ場所へ到達した場合は、固有のレビュー利益が実証されたとは扱わない。**

2026-09-09記録。実施は2026-09-08 UTC。[固定条件](v03-02-plan.md)、[Issue #50](https://github.com/KantoYamamoto/sekka/issues/50)。公開Nuke #963の固定base/headを用い、対象をビルド・実行せず比較した。調整担当は両結果の受領後に通常diff・固定ソースを照合した。PRの議論や他人のレビューは根拠にしていない。

## 結果

BはSekkaだけで削除型・設定・診断・テスト・文書の確認候補を作れた。しかしAも通常diffからほぼ同じ論点へ到達した。今回もSekka固有の見落とし削減・検索削減は確認できない。利用上限の中断で速度は判定不能。2件で全用途の無効性を結論しないが、案内の改善を続ければ元の設計上の目的に届く、とも結論しない。

| 確認対象 | A: 通常diff | B: Sekka先読み→diff | 調整担当の照合 |
| --- | --- | --- | --- |
| 開始頻度と残るキュー | 100件/秒・burst25の削除と同時実行6の違いを確認 | 削除型とstartの変化を入口に、diffで同じ違いを確認 | 頻度と同時実行数は別。性能の回帰は未検証 |
| キャンセル | 残る入口・delegate待機後のguardと既存テストを確認 | 同じ残存guard・テストを確認 | guard削除を欠陥とする候補は両者とも退けた |
| 設定廃止 | deprecated getter=false/setter=no-opを確認 | 宣言移設の可能性を先読みし、実際の契約はdiffで確認 | 外部利用者のread-back要件は不明 |
| 診断・集計・表示 | unknownへのdecodeと再保存の意味まで読んだ | producer/consumer削除と残るキュー表示を確認。decode本体は未読 | Aの方がこの論点の周辺確認は深い。旧記録の存在・互換要件は未確認 |
| 残存デモ説明 | 候補なし | 未変更Demoの機能説明との不整合を発見 | B固有だが、出所は通常diff後のgrep/show。Sekkaはこの未変更ファイルを示していない |

Aは4群、Bは5群にまとめたが、Bはテストを別項目にしている。件数の大小を品質差にしない。基準は全バグの正解集合でもない。

## 根拠の固定位置

以下はhead `9ee5994d613854c03acec20a4baf4715f34f5a49`（削除元だけbase `bbbb53475d1b48e1d64891ccfd632ac85fc61c5c`）。公開ソースの要約であり、対象プロジェクトへの修正要求ではない。

- `Sources/Nuke/Tasks/TaskFetchOriginalData.swift:48–71,95–111`：直接loadDataへ進む一方、通常キュー/skip経路と2つのisDisposed確認が残る。`Pipeline/ImagePipeline+Configuration.swift:188–189`は同時実行6。base `Internal/RateLimiter.swift`のtoken bucketが開始頻度を制御していた。
- `Sources/Nuke/Pipeline/Deprecated.swift:9–18`：廃止設定のget/setと警告。変更されたCHANGELOGもno-opを説明する。
- `Sources/Nuke/Diagnostics/ImagePipeline+Diagnostics.swift:438–453`：未知文字列をunknownへ復号しrawValueで再符号化。`ImageTask+Metrics.swift:319–327`はunknownをotherへ分類する。
- `Tests/NukeTests/ImagePipelineTests/ImagePipelineDelegateTests.swift:202–228`：skipの両値で、delegate待機中キャンセル後のloader作成0件とキュー解放を期待する。テスト実行の合格とは区別する。
- `Demo/Performance/StressTestDemo.swift:13–15,32,48–55`と`Demo/App/DemoMenu.swift:98`：削除されたrate limiterを現役の機能として紹介している。Bの指摘を固定headで確認した。将来の修正予定・配布時期は調べていない。

## 読む負担と手順の限界

| 資料・操作 | 実測・記録 |
| --- | --- |
| 通常Swift diff | 408行 / 17,171 bytes |
| その他diff | 40行 / 2,773 bytes。Swift diffとのパス重複なし |
| Sekka text | 433行 / 46,929 bytes。Swift diffの約2.73倍のbytes（その他diffも含めた19,944 bytesの約2.35倍） |
| 追加Git操作 | A: grep2 + show8。B: grep3 + show7（うちshow1回失敗） |
| Bの先読み | text初回表示が打ち切られ、220–310行を補読してからcheckpoint保存 |
| その他 | Bはcompact/full JSON・バイナリによる移動を使っていない |

textは133のnot-compared記録を含む。これは133箇所の変更や不具合という意味ではなく、曖昧な同名型で前後を対応付けない記録などを含む。特にMetrics/Format/Deprecatedでは同じ理由と前後の位置が反復される。誤った対応付けを避ける0024の境界は維持すべきだが、詳細を標準textで全部読む負担は残った。単に警告を消して比較済みに見せる修正はしない。

Aの原記録には文書diffを重複して読んだという記述があるが、調整担当のファイル検査ではordinary.diffはSwift12パス、documents.diffは別の3パスで重複がない。同一コマンドの連続出力の認識と、入力ファイルの重複を区別し、重複入力として集計しない。

Aの開始09:51:15→候補完成14:53:14 UTC、Bの開始09:51:28→checkpoint14:53:22→完成14:55:55 UTC。利用上限エラー・再開が混ざり、実作業時間を分離できない。後半だけを抜き出して速度差を主張することもしない。token費用・正確なモデルIDは未測定。

配布後のSHA256をA4ファイル・B8ファイルすべて再照合し一致。両者の入力metadata・2つのdiffも一致した。生出力・checkpoint・結果はGit管理外の`.build/independent-review/nuke-963/`へ保存。公開記録は本書へ要約する。

## 次の判断

#50の1検証は完了。#10の追加・分割全般やM2全体は未完了。[前回API比較](v03-01-results.md)と合わせても、汎用のPR索引を整えることから設計の検討支援へ届く利益は未実証である。

#12を4ケース完了待ちから前倒しし、次に検証する仮説を利用者と選ぶ。候補は[0030](../decisions/0030-next-hypothesis.md)。配布、Mermaid生成、同じ条件での追加比較を自動的には始めない。既存役割の明示入力は未採用で、今回の結果から必要性が証明されたわけではない。
