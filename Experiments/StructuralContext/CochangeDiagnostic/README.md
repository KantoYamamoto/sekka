# 変更された既存窓口を含む観測単位の診断

**同じswitch構文形の変更が複数領域へ入る場合は、処理全体・所属宣言・記載上の利用候補を位置付きで示し、配置を再考する判断と分ける。** #105 / [判断0048](../../../docs/decisions/0048-changed-existing-context.md)。通常CLI/libraryの検索契約は変更していない。

`plan.md` / `needs.json`は実装前の`574da73`で固定。#102の通常sourceレビューで必要だった関係を診断する既読実験であり、未見の利益ではない。必要性についてA/Bは異なる。引用windowの末尾はAST範囲より1〜8行広い箇所があり、原freezeを保持して`results.json`へ実AST位置を別記した。

## 何を読むか

`region-body.swift`を、自分のpackageの一時コピーで通常readerの後へ組み込む。関数・initializer・property/accessor・binding等の領域、switch caseとcall表記、字句header/条件を読む。対応は前後それぞれ一意なheader・条件・switch式で限定し、重複を位置順で対応させない。条件コンパイル内のcase一覧は展開せず不明へ残す。

`analyze.py`はcaseラベル、called expression、明示ラベル列と追加trailing closureラベル、call表記のsource順が同じ形へ変わった複数領域を集約する。引数/closure本文の表記差と外側条件差は別に表示する。二つ以上のcaseは今回の構文範囲で、危険度ではない。記載順は実行順、同じ形は同じ挙動、同じselectorは解決済みの利用関係ではない。guard後の支配条件やmacro展開、値・receiver型・callee・性能・意図は解決しない。

通常diffにString分岐の変更は既に見える。補足できたのは、両switchの残るcase全体、変更された既存helperの全体と、hunk外の未変更property内の利用表記である。主処理が既に別helperへ共有されたことも反対材料として残す。本文の似方から共通化必須とは返さない。

## 検証と再生

```sh
python3 Experiments/StructuralContext/CochangeDiagnostic/verify.py \
  --scratch .build/cochange-diagnostic-build \
  --output .build/cochange-diagnostic/checks.json
python3 Experiments/StructuralContext/CochangeDiagnostic/replay.py \
  --packet .build/both-side-comparison/packet \
  --inputs Experiments/StructuralContext/BothSideHoldout/inputs.json \
  --binary .build/cochange-diagnostic/region-probe \
  --checks .build/cochange-diagnostic/checks.json \
  --output .build/cochange-diagnostic/replay-new
```

`verify.py`は自分のtracked sourceをarchiveし、26対照の終了コード/stdout/stderr全bytesを二回照合する。`--source-ref`で過去sourceを固定できるが、analyzer/controlの作業ファイルも該当commitと揃えて使う。`replay.py`は前段で取得・diff全体も検証した固定packetを必要とし、再取得はしない。全1,891 entriesの一覧/byte/blob/SHA、control binary/analyzer SHAを照合してから全3入力を再生する。前後入力エラーを正常0へ変換せず、部分結果を拒否する。出力先は上書きしない。

raw dumpはsource tokenを含む大きな診断データで、製品出力の候補ではない。publicは`results.json`の位置/count/hashとown codeだけ。対応不明の位置も全件残し、fact上限による位置省略はない。外部OSSのbuild/test/script/checkoutや先方への投稿は行わない。

[結果と限界](../../../docs/validation/cochange-diagnostic.md)。独立code/fact/文書点検と自己利用は完了、最終PR検証は進行中。本番/M3は保留。次の実験CLIと未読比較は、結果点検後にだけ分解する。
