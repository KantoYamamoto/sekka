# 0045: 戻り値名とcall表記から既存producerを比較する

**変更側と同じ戻り値名/call表記を持つ未変更の実装がある場合は、両位置と記載条件を並べる。表記の接点を同じ型・責務や共通化の必要性と呼ばない。**

- 記録日: 2026-10-04
- 状態: #93のM2実験。本番統合と有用性判断は保留
- 経緯: [0044](0044-existing-result-producers.md)の限定仮説を実装する

## What / 目的

局所追加を既存構造へどう組み込むか再検討する材料として、呼び出し先だけでなく、結果表記を扱う既存処理へ辿る。変更関数と未変更関数の明示戻り値に同じunqualified名があり、本文の同名unqualified call/明示ラベル列が一致し、after索引に同名の非alias nominal宣言が1件ある場合を比較先にする。callと戻り値のデータフロー、実constructorや型の一致は証明しない。

## Why

#91の既知GRDB1858の診断では、既存insert executorが通常レビューの共有先例だったが、変更側はその関数を直接呼んでいなかった。`InsertionSuccess`の記載上の接点ならそこへ届く。SQL helperを示すだけでは得られない、同じ層で既にどう実行しているかを比較する入口になるという仮説。

この仮説は既知入力を見て選んだ。到達しても独自発見・レビュー改善・未見の有用性とはしない。

## Why not

無条件の共有callはassert/precondition等へ広がった。戻り値表記と索引内名を足して狭めるが、scoreで似ている度合いを判定しない。API familyや本文だけ不変の宣言を同時に採らず、結果をこの一仮説へ戻せるようにする。

別の走査・一覧・上限を継ぎ足すと対応と省略の意味が分裂するため、member/unqualified callのvisitorとcaller適格性/target不変を共有し、既存contextsへ統合する。互換性のための旧call索引は保持しない。過去診断の再現だけは固定refと旧JSONの読取りを明示する。

## How

`WrittenCalls`は関数bodyのみを歩き、control block/closure内の表記も読む。parameter default/header、local関数・local型本文、trailing/qualified/specialized/implicit形式は対象外。`WrittenCallSearch`は変更fileかつ旧file関数索引に宣言トークンがないcallerを入口にし、一意な旧対応があれば旧bodyに同じcallトークンがない出現だけを選ぶ。対応不明なら新規callとは呼ばない。

戻り値名は既存TypeNames readerで位置とともに保持する。既知generic/associated/Selfと、parameter/local/closure captureを除外する。direct scopeのfunction名・variable pattern名・enum case名も保持し、file全体・字句nominal/extensionと、単純な記載owner名が一致するextensionからの値bindingを保守的に除外する。記載owner比較は除外にのみ使い、型解決へ昇格させない。位置・条件の前後を問わず除外するため偽陰性を許容する。継承、qualified extension/SDK/生成/未索引bindingは不明。

比較先はbodyあり、旧新の完全な宣言キーが一意、全字句祖先headerと宣言トークンが一致する関数。入口/既存のcall条件は別々に集約し、異条件は別根拠。同条件の同じselectorは最初の位置と件数にまとめ、引数値や挙動は未比較と表示する。共通functionキー、最大8候補/各8根拠と省略数を使う。

## 制約・見直す条件

既知一件に届くことと、未知の変更で配置比較に必要な先例へ届くことは別。一般的な結果名に多数の無関係候補が出る、必要先が依然として外れる、通常diffだけで十分なら、用途限定/別の関係単位/保留へ戻る。#724の寿命や#1864のhook境界を解決したふりはしない。対象OSSは読み取りのみ、runtime LLMなし/決定論的を維持する。

## 根拠・確認

[検証記録](../validation/result-spelling-context.md)に合成対照、同じ3,026入力での回帰、独立レビュー、自己利用、Actions/実成果物の確認状態をまとめる。未完了の確認は完了扱いしない。
