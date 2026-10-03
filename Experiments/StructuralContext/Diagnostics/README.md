# 必要な確認先へ届かない理由の診断

#91 / [判断0044](../../../docs/decisions/0044-existing-result-producers.md)。本番や実験CLIの新しい検索経路ではなく、#87の既知4PRで次の仮説を選ぶための診断。必要位置を`needs.json`へ先に固定し、既存索引・検索条件と照合する。位置の集合は独立レビューの必要先で、網羅的正解集合ではない。

`inventory-body.swift`は既存`context-probe`のソースreaderの後へ、**自分のpackageの一時コピー内だけ**で組み込む。library/通常CLIを変更しない。関数・property・型・字句scopeの索引、全ASTのcall表記と近傍の関数戻り値にあるIdentifierType名をdumpする。全ASTのdumpと、本来の検索に適格なcallは別物。local関数やspecialized等を含むdumpをそのまま検索成功と呼ばない。`callerBodyOwned`はnearest functionのbodyを祖先に持ち、local型をまたがないcall。試行は索引関数に対応するこのcallだけを使い、parameter default/headerやlocal型のproperty初期値を混ぜない。

```sh
set -e
python3 Experiments/StructuralContext/Diagnostics/verify.py --scratch /tmp/sekka-index-build --output .build/context-diagnostic/checks.json
.build/context-diagnostic/inventory-probe BEFORE_SWIFT_DIRECTORY AFTER_SWIFT_DIRECTORY > .build/context-diagnostic/index.json
```

`verify.py`は自分のtracked packageをarchiveし、同じreaderと診断bodyを合成してビルドする。通常はHEAD。#91の公開結果を再現する場合は`--source-ref a566217dcc1eb15a908a6355dcacabab054b2727`で当時のlibrary/bodyを固定する。最新HEADでの検証と過去結果の再現は区別する。実験本体用と異なるscratchを使い、tuple/genericの表記・位置、JSON/終了コード/stderr二回一致、不正入力の部分出力拒否を合成例で確認する。出力binary/checksをGitへ追加しない。

外部入力は[Holdout](../Holdout/README.md)の固定manifestから再現し、**全ファイル一覧/ハッシュを照合してから**診断する。対象OSSのbuild/test/scriptは実行しない。各caseのbefore/after/sourcePrefixを指定し、index JSONを各二回実行してbyte一致を確認する。各結果は`INDEX_DIRECTORY/<case-id>.json`へ置く。基準のcontextsも同じmanifestから[Reach runner](../Reach/run.py)で再現する。

```sh
python3 Experiments/StructuralContext/Diagnostics/audit.py --index INDEX_DIRECTORY --contexts CONTEXT_DIRECTORY --output .build/context-diagnostic/audit.json
```

`audit.py`の出力は位置・selector・件数などのmetadataだけ。入力indexは第三者のbody/callトークンを含むため、公開Gitへ入れない。公開結果の`results.json`も有用性評価ではない。

- 必要位置と交差する索引宣言を示す。宣言範囲との交差はその契約を解析済みという意味ではない。
- member検索の適格な出現、一致宣言数、前後不変/対応不明/本文なしを分ける。型/property経路の全試行を再実装した検出器ではない。
- 同じ操作表記を使う既存consumer、同じ字句header/名前のfamilyは探索用の別案。既存consumer試行は全文言一致のcallではなく、form/名前/明示ラベル列/trailing closure有無の一致。
- 戻り値名の試行は、両callerの戻り値に表記された名前で、同名の索引内宣言が1件ある、unqualified/nontrailingのcallに絞る。初回のノイズ観察後に選んだ既知入力上の仮説。generic/alias/value shadowや実initializer/戻り値との関係は解決していない。
- 必要先を持つtoken-identical関数だけを既存consumer試行に使う。bodyが同じでも宣言/祖先headerが変わる場合は別状態とする。試行は条件の有効性を判定せず、結果は位置へ戻して確認する。今後の実装では条件表示と既知binding除外が必要。

[結果と解釈](../../../docs/validation/context-miss-audit.md)。この診断の結果に合わせて同じ4PRを未見として採点し直さない。
