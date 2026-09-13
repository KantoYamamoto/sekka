# 変更宣言から既存実装の接点を検索する実験

2026-09-13、[#63](https://github.com/KantoYamamoto/sekka/issues/63)、[判断0036](../decisions/0036-change-context-retrieval.md)。本番未採用。#62で継承中心の抽出が届かなかった2入力を、以後は既知材料として使う。

## 方式の置換

class/空hook/兄弟overrideという固定形から、関数とproperty bindingが持つ呼び出し表記の索引へ作り直した。同じ実験package/入力境界を使い、旧class抽出の常設コードとテストを撤去。旧版は#61の固定commitから再現する。本番のSekka CLI/schemaへは追加していない。

変更後の宣言と複数の明示的な呼び出し表記を共有する既存宣言、同じ名前/引数ラベルの使用位置を前後で出す。型やcalleeは解決しない。同selectorの使用位置は一つのグループに集約し、署名でoverloadを区別できる。JSONと`--text`の罫線は同じ材料を使う。

## 既知材料で得られた接点

| 入力 | 接点 | 問いと反対根拠への寄与 |
| --- | --- | --- |
| WordPress #25624 | 新しいStockPhotosPickerSheet.body:9と既存MediaPickerMenu.showStockPhotosPicker:19がservice/data source/welcomeの3表記を共有 | picker構築をどこまで共有するかの入口。V1/V2の結果型・UI寿命の違いはソースで確認が必要 |
| Nuke #879 | AsyncPipelineTask.decode:44と同じselectorの使用が、既存network側:57・disk側:36に前後ともある | 既に共通入口へ組み込まれている根拠の候補。queue/operation所有と互換要件はソース/PR本文で判断 |
| Nuke #879 | 新makeImageResponseの表記が既存decodeのbeforeにはあり、afterの同宣言にはない | 既に抽出した処理を残存重複と読まない。表記の差であってコード移動を証明するものではない |

位置は[#62の固定SHA/manifest](context-holdout.md)に対するもの。外部OSSはGETで取得済みの選択入力を読むだけで、対象コードは実行せず、先方への変更も一切行っていない。

## 試験とレビューからの修正

27単体テストとCLI境界/既知入力検証が成功。順序変更・コメント/空白、overload/局所shadow、同selectorの集約、再帰的な使用、nested/local scope、条件式の除外、本文/使用位置の省略数、制御文字を含むパス、部分出力しない構文エラー/symlink拒否を確認した。

- 単純なselector一致は異なるreceiverの一般処理も近く見せた。共通表記の検索はreceiverを含む明示的な表記へ変え、暗黙の`.success/.failure`は外した。同じ名前/ラベルの使用位置は別の候補グループであり、callee解決とはしない。
- 同selectorの使用位置を各overloadへ再掲して出力が増えたため、1グループへ統合した。関係のない未変更overloadを曖昧一覧へ再掲する処理もやめた。
- 独立実装レビューの4件を合成入力で固定。行の包含は同一行の別宣言を消したためUTF-8範囲へ変更。observer付きpropertyはbinding全体を訪問。local関数のownerへproperty/accessor等を含める。local型のpropertyとdeinitのlocal変数は近いscopeから区別する。
- 材料レビューではbeforeだけの共通表記の下にafter位置が並び、現在も重複して見えた。各sideの共通表記を計算し直し、afterで表記が消えた場合も表示する。単なる注意書きの追記にはしない。

初回の材料レビューは以前の2入力を知っている担当による修正評価。WordPressの構築共通表記とNukeのnetwork/disk使用位置が、既知の配置の問いと現配置を支持する根拠へ結びついた。未見の発見率・速度改善の証明ではない。利用枠の中断/待機も評価時間には使わない。

## 残る限界と次

汎用の実行helperやテストの類似も出る。引数・receiverの表記が一致しても同じ責務や同じcalleeとは分からない。WordPressのimporter契約は入力外で、名前の最終方針・ファイル寿命は未確認。Nukeでもqueue所有や同期互換を確認せず共通化を勧めることはできない。

今回の材料は本番へ自動採用しない。新しい入口が既知の問いへ届くことと、未知の変更で読む手間を減らし不要な改修へ誘導しないことを分ける。次は抽出器と読む範囲を固定した別入力で、この利益と負担を比較する。出力の件数増加を成功条件にしない。

再現は[実験README](../../Experiments/StructuralContext/README.md)。ローカルの段階別出力/試験/生レビューは`.build/change-context`。実装の自己利用は`8cfde4d`→`c0eb0b3`で行い、新旧本番評価器のSHA-256とfull JSONは同一だった。12パス/Swift6/28観測/31本体未比較は置換の入口を示すが、4件の不備と前後の誤誘導は通常diff・合成検証・独立レビューから分かった。再レビューで4件と前後表示の解消を確認。実装後の文書/Actions成果物追加ではSwiftを変えず、同じ自己利用を再実行していない。

最終の出力はWordPressが材料7宣言/5selector group、JSON 23,283 bytes、text 13,895 bytes/95行。Nukeは材料10宣言/4group、JSON 31,704 bytes、text 16,077 bytes/145行。署名・前後の事実を増やした代償であり、省トークン化の成果とは呼ばない。PRのActionsには合成材料のJSONに加えて罫線textも成果物として保存する。最終PR/CIのreceiptは対応Issueに残す。
