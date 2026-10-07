# 状態の記載名から既存操作へ進む試作

変更された操作 → 同じ字句ownerにあるproperty名 → その名前を使う既存操作 → 既存操作と同じselectorが書かれた利用箇所、という順で差分外の確認先を示す。既存の構造へ組み込む別案を検討するための候補であり、同じ状態・実callee・共通化の必要性を解決しない。

[実装前の計画](plan.md)・[固定確認先](anchors.json)・[結果](../../../docs/validation/state-operation-entry.md)。#111の既読診断であり、本番Sekkaと旧実験CLIには組み込んでいない。旧同形switch入口は新4PRで利益未支持のため凍結した。

## 実行

Swift 6以降、macOS 13以降、SwiftSyntax 604.0.0。対象のbuild/test/scriptは実行しない。

```sh
swift build --package-path Experiments/StructuralContext/StateOperations/Prototype --scratch-path .build/state-operations
SEKKA_STATE_BIN="$(swift build --package-path Experiments/StructuralContext/StateOperations/Prototype --scratch-path .build/state-operations --show-bin-path)"
"$SEKKA_STATE_BIN/state-probe" BEFORE_DIR AFTER_DIR --text
"$SEKKA_STATE_BIN/state-probe" BEFORE_DIR AFTER_DIR
python3 Experiments/StructuralContext/StateOperations/Prototype/controls.py --binary "$SEKKA_STATE_BIN/state-probe"
```

ディレクトリ配下のSwiftだけを読み、JSONまたは罫線textを返す。`+ usage`は新しい本文参照の式token/出現数、`= existing`は以前から対応のある操作。変更された既存helperも入口に含む。本文tokenが変わっただけで、その状態に関係する式が変わらなければ入口にしない。削除だけの利用は現在選ばない。

field/operationの所属は直接の字句宣言を維持する。incoming callだけは、同じfile内の一意なトップレベル型名と、型引数/修飾なしのextension名を候補として使う。同名nominal/typealias/protocolがあれば加えない。条件と呼出/所属/targetの物理位置・候補数を保持し、最大2段、receiver/callee/extension owner未解決。textは同一call候補を重複表示しない。

## 読むときの境界

parameter/local/closureと同名の参照も未解決候補。stored、observer付き、storage不明のcomputed propertyを区別する。異なる宣言を同じheaderだけで結合せず、前後対応はowner/header/条件が一意な場合だけ。conditionalの有効性、意図、効果、性能は解決しない。cross-file、nested/qualified extension、top-level、macro、非Swift、removed-onlyの変更は網羅しない。

ドット名は読まない。ルート/配下symlink、UTF-8/read/parser失敗は終了2・stdoutなし。正常0は設計の承認でも全変更の確認済みでもない。入力SHAはliteral UTF-8のfile/source pairs、位置は物理行/offset。実行中に入力を書き換えない固定snapshotを前提とする。

## 固定既読例の再実行

#109で検証済みのGRDB1881 packetをignoredへ用意し、`Prototype/replay.py --binary BIN --packet PACKET --inputs Experiments/StructuralContext/DirectRelationsHoldout/inputs.json --output NEW_PRIVATE_DIRECTORY`で再実行する。全341 file entriesのinventory/blob/bytes/SHAを照合し、JSON/textそれぞれ2回のexit/stdout/stderrを比較する。外部source/diff/raw出力をGitへ入れない。[execution.json](execution.json)はhash/countのみ。

41合成対照は事実性・曖昧さ・失敗・二回一致の検査。本番への採用やレビュー利益の合格ではない。Actionsも自作対照のみを実行し、receiptと自作例のtextをartifactへ保存する。次の実用性比較は、このcaseを未見として再利用せず、別入力で行う。
