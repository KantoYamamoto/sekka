# #107: 関係を直接出す実験CLI

**変更された既存窓口を読む必要がある場合は、未変更target検索へ継ぎ足さず、同形変更・所属領域・利用表記を直接示す。** 目的と別案は[0049](../decisions/0049-direct-written-relations.md)、実行契約は[実験README](../../Experiments/StructuralContext/README.md)。本番CLI/M3は保留、未読利益は未確立。

## 現在の根拠

旧索引/4検索経路/テストを現行packageから撤去し、#105で点検した領域readerを再利用。Swift内部で関係を作り、JSON/罫線textへ必要な形と全位置を直接出す。parser/read error境界を維持する。旧runtimeの再現は固定commit `5177d21c476728e7fd4f3bbadba53cce9c181cfc`へ残し、常設CIは現行契約の対照へ整理。

code source `58d85d1`は13 Swiftテスト/31 CLI対照（BOMの識別/物理offsetを含む）を通過。条件/header変更、曖昧owner/switch、追加/削除、共有済み規則、異なる引数/closureラベル、Unicode bytes、コメント/空白、形詳細省略と全位置、parse/read失敗と正常0を分ける。CLIはJSON/text/allの終了コード/stdout/stderr全bytesを二回照合する。独立codeレビューでBOM除去のP2を修正し、不正UTF-8各種/11関係の詳細上限/同名候補等も別合成入力で確認。既読fact/限定text点検も完了。未解消P1/P2/P3なし。

同じ既読3入力の最終評価器の再生は全1,891 entriesのinventory/size/blob/SHAを照合し、JSON/textを各二回実行。#105との関係・owner・users・unknown全位置と差異flagが一致。選ばれたswitch内の新しい共通call表記の全位置とsame-basename宣言候補は実calleeへ解決せず反対材料へ進む入口として出す。

| 既読入力 | 関係 / before+after利用表記 / unknown group | JSON / text bytes（58d85d1） |
| --- | --- | --- |
| swift-collections #747 | 0 / 0 / 23 | 8,120 / 4,102 |
| GRDB #1885 | 1 / 2 / 4 | 14,394 / 5,437 |
| GRDB #1884 | 0 / 0 / 4 | 3,564 / 2,141 |

これらは同じ素材の再検証で、未読PRの利益ではない。59MB等の診断dumpを常設要約pipelineへ持ち込まず直接出力できたことと、配置を考え直す判断へ寄与することは分ける。

## 再現と未完了

入力manifestは[#102の固定素材](../../Experiments/StructuralContext/BothSideHoldout/inputs.json)。取得済みprivate packetを使い、対象checkout/build/test/script/外部投稿は行わない。runnerは全packetと対照binary SHAを検証し、出力先を上書きしない。

```sh
# 新規の作業場所で、先に実験READMEのswift testを実行する。
# 既存のfreezeを再利用する場合はcp/verifyを省略し、保存済みreceiptを使う。
mkdir -p .build/direct-relations
cp .build/structural-context/debug/context-probe .build/direct-relations/relations-probe-text-state
python3 Experiments/StructuralContext/verify.py \
  --binary .build/direct-relations/relations-probe-text-state \
  --output .build/direct-relations/checks-text-state.json \
  --text-output .build/direct-relations/controls-text-state.text
python3 Experiments/StructuralContext/DirectRelations/replay.py \
  --packet .build/both-side-comparison/packet \
  --inputs Experiments/StructuralContext/BothSideHoldout/inputs.json \
  --binary .build/direct-relations/relations-probe-text-state \
  --checks .build/direct-relations/checks-text-state.json \
  --output .build/direct-relations/replay-new
```

第三者source/diff/形の生出力はignored。公開記録は位置/count/hashとown code。全3入力の最終再生・旧位置とのparity・自己利用は完了。公開[結果metadata](../../Experiments/StructuralContext/DirectRelations/results.json)まで独立fact点検済み。初回PR #108のActions 37461184028は成功、実Botと10成果物/manifest head/base/diff SHA/31対照も一致。最終headのPR点検は[PR #108の完了receipt](https://github.com/KantoYamamoto/sekka/pull/108)で管理する（初回成功を最終成功へ換算しない）。ローカルの再buildでは生成test bundleのFinder metadataによる署名エラーが出たため、own `/tmp` scratch/native buildで13テストを通過。解析対象の問題と混同しない。未完了を正常成功としない。

P3のtext owner状態欠落と再現commandの旧freeze参照も修正。全3入力JSONは前版9cbede1と全bytes同一、textは選んだmember2行へ状態を足しただけ。matcher/reader/modelは変更していない。

自己利用は本番評価器のbaseline/candidate全text/compact/full bytes一致。旧索引撤去と新model一覧は読む順の入口になったが、macro方針整合とmatcher正しさは通常diff/文書/独立対照で判断。BOM不具合はSekka/root自己利用ではなく独立code点検から見つかった。用途価値やレビュー時間の改善と同一視しない。

次は固定評価器を使った未読比較。両stage1に同じPR説明/通常diffを先渡しし、commonsource前のcheckpointを保存する。既読到達/圧縮率は合格条件にしない。配置再考へ寄与せず別の決定論的根拠もなくなれば、用途限定/撤退の判断を人間へ通知する。
