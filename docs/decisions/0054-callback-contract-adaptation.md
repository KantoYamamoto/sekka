# 0054: 中継の深さから、共有callback契約の適応へ観測単位を変える

**方針：中継API増加の実負担を得られず、共有契約の拡大が不要値を捨てる既存利用側へ波及している場合は、その適応とAPI境界の比較を一単位で試す。**

- 記録日：2026-10-08
- 状態：PR #125完了・固定実根拠/根拠整理の補助まで。限定試用へ進むかのプロダクト判断待ち、本番保留
- 経緯：[0053](0053-stored-callback-relay.md)の経路取得は保存、#122の中継契約増加は実装せず終了。[#124](https://github.com/KantoYamamoto/sekka/issues/124)へ単位を置換

## 目的・What

局所追加をそのまま受け入れる前に、共有callbackの境界をどう進化させるかを考える材料を示す。APIに追加された値を捨てる既存closureの適応をまとめ、positional callbackを維持する案、単一event payload、旧入口を保つ専用入口/adapterを比較する。設計の修正命令や一般graphではない。

## Why

#122は最大二Swift候補で「純中継の既存二型の契約増加」を確認できなかった。Maple #3740では、同じPhotoGrid.onTapの拡大に対して五既存closureが追加slotを捨てた。新geometryを利用しない側へもarity適応が及んだ事実は、深さや規模よりAPI境界の問いへ近い。[位置・実装前の期待出力](../validation/callback-contract-cost.md)。独立sourceレビューも元条件不成立/五body比較を照合し、限定試作は妥当とした。通常diffからも読めるため利益の純増は未支持。

## Why not

callback-probeにgeneric/custom init/transform対応を広げても、元仮説の純中継負担は得られない。自作合格で延命しない。payload化も初回のcaller移行が必要で、一度だけの追加なら現在の単純なAPIが妥当。adapterは旧契約を保てるが二つの入口/通知契約を増やす。どちらも唯一の正解としない。設定ファイルへAPI意図を書かせる案は、まず設定なしの根拠で比較できるかを確認するため採らない。

## How

同じSwiftSyntax実験packageのsource reader/hash/失敗境界を共有する。contract-probeは一意な記載struct・明示initのcallback型の末尾引数追加を前後比較し、同じfile/字句ownerとcallback以外の引数tokenが一意に対応するcall候補を読む。追加slotが `_`、旧引数参照の正規化後にbody tokenが同じ、旧bodyが元引数を使っていた場合をまとめる。callee/型の意味は解決しない。

前後のsource位置・inventory/hash・除外と不明を出す。shadow/条件付きscope/macro/同名/複数init/対応曖昧は比較の保証外。direct function referenceからclosureへの変換はbody比較対象外。source read/parse失敗は部分結果を返さない。

## 制約・見直す条件

event payloadの期待は、同じevent型へ今後metadataを追加するときにclosure arityの適応を切り離せること。生成側/初期化契約/利用する側の変更は残る。取得時点・座標系・所有/Sendableや将来要求は人間が確認する。token同一を挙動同値、適応箇所数を変更工数と呼ばない。

一件の取得/少数対照が合格しても本番統合しない。初読reviewerの通常資料との比較で、境界を見直す問い/反対理由への寄与を点検する。寄与が弱ければ未対応構文や別素材を探し続けず、投資判断を整理する。

## 根拠・確認

[検証記録](../validation/callback-contract-cost.md)。固定実source五caller取得、少数対照、独立指摘修正/再確認と初読比較まで。通常資料も同じ問い/専用入口案へ到達し、支持は根拠整理の補助に限る。自己利用/最終Actions/実Bot/18成果物までPR #125で完了。元目的の一般有用性は未確立なので、次の機能追加へ自動継続しない。
