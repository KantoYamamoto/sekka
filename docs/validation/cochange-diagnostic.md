# 同種の構文変更と既存窓口の診断（#105）

**関係の存在は既読素材で診断し、配置再考への利益は別の未読比較で確かめる。** 2026-10-05。[診断と再現](../../Experiments/StructuralContext/CochangeDiagnostic/README.md) / [判断0048](../decisions/0048-changed-existing-context.md)。通常CLI/libraryは変更なし。本番/M3保留。独立結果点検/最終PR検証は進行中。

## 観測単位を変えた理由

#102のGRDB #1885で、通常sourceからscalar initializerと既存reportへ同種の結果転送変更が入ること、reportを未変更propertyも使うことが確認された。現在の関数索引にはinitializerがなく、既存reportは索引にあっても宣言全体不変の条件で落ちる。二つの境界を分離した。initializerを索引へ足すだけでは後者を解決しないため、switchの前後構文形を別の診断単位とした。既存helperや役割を名前から特定する方式ではない。

## 固定素材での結果

元freeze `574da73`、修正後診断source `8373ace`。素材は#102の成立3件を再使用し、別の未読標本とは扱わない。1,891 entriesの全一覧/byte/blob/SHA照合後、全入力の終了コード/stdout/stderr全bytesが二回一致。analyzerも同じ結果bytes。公開根拠は[results.json](../../Experiments/StructuralContext/CochangeDiagnostic/results.json)。

| 入力 | switch前→後 | 同形変更の関係 | 記載利用候補（前/後） | 対応不明の組 |
| --- | ---: | ---: | ---: | ---: |
| Collections #747 | 37→37 | 0 | 0/0 | 23 |
| GRDB #1885 | 262→262 | 1（2領域） | 1/1 | 4 |
| GRDB #1884 | 262→262 | 0 | 0/0 | 4 |

GRDB #1885の`DatabaseFunction.swift`で、initializerのswitchは101–114→101–116、既存関数のswitchは443–456→445–460。両switchは各snapshotで同じ5case/call表記形を持ち、その形が同じように変わった。引数表記とclosure境界は異なる。before/afterともswitchの各6物理行が通常diffのhunk外にあり、宣言全体ではinitializerの19行、helperの8行がhunk外。新しい変更の発見ではなく、変更された窓口の全体を読む補足である。

既存helperのselectorと同じ表記のcallは391–393→393–395。所属propertyは379–398→381–400でtoken-identical、20行全てhunk外だった。calleeは未解決なので、解決済み依存とはしない。主要規則の新しい共有helper（`StandardLibrary.swift`:661–677）と同じ記載名のcallは4位置で、trailing closureのparameter対応は行わない。これは通常sourceから既に共有された主処理があるという反対材料を読むための位置で、名前だけから共有済みと証明するものではない。

事前固定の引用windowは一部、ASTの末尾より1〜8行広かった。原freezeを訂正していない。`citationWindowCorrections`に正確なAST範囲を併記し、引用範囲がそのまま宣言の境界だという誤解を防ぐ。到達確認は開始行と実AST位置で行った。

## 読解と機械事実を分ける

今回の診断から新たな独立レビュアーへ有用性を比較したわけではない。#102のBは既存reportへ揃える限定的な問いを立て、Aは主要規則が既に共有され追加配置変更の必要性不足と判断した。この差を保持する。同じ構文変更の関係は「局所修正を二箇所へ入れた」という根拠の一部になり得るが、同じ責務・負担の大きさ・共通化の妥当性・性能はsource/要件へ戻る必要がある。一般的なLogger/AnalyticsやSwiftUIの継ぎ足しを検証済みとはしない。

## 検査・自己利用・独立点検

26対照でinitializer/property/accessor、追加削除・重複header/switch、条件コンパイルの未展開case、引数/closure差異、共有済み主処理、異なる目的でも同じ構文、正常0・malformed/invalid UTF8/symlink失敗を検査。全process bytes二回一致。独立code点検の5指摘（trailing closure、外側条件、analyzer照合、guard、subscript所属header）は修正し、再点検に未解消指摘なし。独立syntheticでは権限/欠落入力、Unicode/#sourceLocationの物理位置も確認された。既読入力/有用性はこのcode点検の対象外。

Sekka自己利用の初回は`fe3c1eb→d4be9ff`。新旧評価器のSHA/JSONは同じで、10構造観測/28未比較本体、Swift1ファイルとPython等の入口を表示した。closureラベル/祖先条件/照合器の問題をSekkaが発見したとはしない。通常diffと全body、Python/文書、独立syntheticで分かった。後続Swift修正後の最終自己利用`fe3c1eb→8373ace`も同じ評価器/JSONで、10観測/28未比較本体。通常diff/全bodyを再読し、guard/subscriptの修正範囲を確認した。結果独立点検とActions/実Bot/成果物はPRへ追跡する。

## 次の分岐と撤退

結果点検で位置/関係の事実性が成立した場合のみ、全AST raw dumpへ依存しない最小の実験CLI契約を別PRで作る。次の未読比較は両stage1へ同じPR説明・通常diffを渡す契約を事前固定する。同じcase/引数/名前の表記を正規化して既読例へ寄せない。

範囲拡大と候補数だけで終わる、または意味推測/既読固有ruleなしでは必要関係へ届かない場合は方式を撤去/再設計する。独立比較でも配置再考に寄与せず、別の決定論的根拠もなくなった場合は、用途限定やプロジェクト撤退を人間へ判断事項として通知する。現在はその結論に至っていないが、未達のまま本番へ採用しない。
