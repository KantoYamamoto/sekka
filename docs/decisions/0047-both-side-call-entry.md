# 0047: call入口を前後両側の共有索引へ組み直す

**方針：追加後のcallだけでは既存窓口を落とす場合は、前後の利用索引と宣言対応を共有し、減った表記も同じ確認先の根拠にする。**

- 記録日：2026-10-04
- 状態：M2実装中、本番/M3は保留
- 経緯：[0046](0046-withdrawn-entry-context.md)の既読診断から選択。[Issue #100](https://github.com/KantoYamamoto/sekka/issues/100)

## 目的・観測

#96では通常diff担当がcopy責務の問いに使った未変更helperへ、旧版の利用4→0から届いた。after専用の入口ではこの材料を落とす。これは既読入力の原因診断であり、レビュー利益の新しい証明ではない。同じ減少条件でSDK等の同名不要先も残った。

## What / Why

WrittenCallSearchに前後のselector別利用索引・caller対応・残る宣言の不変判定をまとめる。既存のmember表記経路をcall表記経路に組み直し、「変更後のcall本文」と「前後のselector総数減少」を区別するevidenceにする。二つとも同じUnchangedTargetの集約と省略契約を使う。result経路も共有するafter入口/不変判定を維持する。

減少は索引内bodyのmember/unqualified nontrailing表記の総数で判断する。before/afterそれぞれに同形宣言が1件、同じ一意な対応・字句header・宣言token・本文ありの場合だけ確認先にする。前後の全記載位置と各callerの対応状態を示す。どのcallが意味上消失したか、callerが削除/移動/renameしたか、実calleeが同じかは断定しない。

## Why not

診断Pythonを第五の独立検出器としてruntimeへ積むと、索引・対応・安定判定・候補一覧が二重になるため採らない。after検索を反転するだけではcallerの一意対応を要求して削除された入口を再び落とす。旧callerが一意対応しなくてもselector全体の減少は観測できるため、対応不明を根拠に残す。

beforeの全callを無条件に繋げる案は、移動だけで総数が同じ場合も候補を増やす。減少という狭い条件を維持し、score/API family/receiver型解決/result条件緩和は一緒に足さない。同名SDKの不明はこの条件だけでは解決しない。

## How / 限界

call表記evidenceをintroduced/decreasedに分け、旧版の位置はbeforeと明示する。introducedのgroupはこれまでのcaller・receiver・selector・条件別、decreasedはselector別に全位置を保持する。8 target/8 evidenceの共通capは維持し、省略を数える。group内位置を黙って省略しない。

既存経路の事実性・全削除/移動/署名/条件/同名SDK/本文なし/曖昧・失敗/全bytes一致を対照で確認し、#96の同じ4caseの候補と必要先/不要先を照合する。通常diff・自己利用・独立レビュー・Actions/実表示まで確認する。利益はその後の別入力で測る。必要先に届くことと設計を見直す理由が成立することを分け、根拠が弱ければM3へ進めない。
