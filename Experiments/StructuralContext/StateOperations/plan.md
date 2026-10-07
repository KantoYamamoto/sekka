# #111: 操作と記載データを入口にする最小試作

2026-10-07。入力は#109の固定packetの同じ既読GRDB1881。これは原因診断/表現可能性の試作であり、未見の有用性比較ではない。現同形switch評価器、元比較の結果/素材/レビューは変更しない。新しい外部sourceの取得や便利なPRへの差し替えをしない。

**新方式の方が必要な関係を表現する根拠がある場合は、利益未支持の旧実験を細部だけ続けず最小試作を選ぶ。** 旧code契約は重複実装/既知の失敗を避ける参考にする。旧方式の再build/追加実験は着手条件にしない。

## 問いと固定する確認先

元のBによる限定的な問いは、専用insertを追加する案と、既存の汎用領域合成を改善する案を比較すること。Aは追加の構造再配置を必要とせず、Bも現配置を支持する。機械がこの問いを発見したものではない。未実行の性能/正しさを保証しない。

固定位置: after GRDB/Core/DatabaseRegion.swift のinsert174/181とTableRegion397/402、既存union144、formUnion169（body170–171はdiff context）、TableRegion.union377、差分外canonicalTables205/211とstatic union494/500。新insertは通常diffに既出、union/既存利用宣言は差分外。元review hash/全source manifest/diff bindingは#109のmetadataへboundする。field宣言45などは新試作のcandidate材料であり、元reviewが必要先と分類したという帰属をしない。

## 最小の仮説

SwiftSyntaxから直接の字句ownerにあるpropertyと関数/initializer/computed-property本文を読む。追加/変更された操作の記載参照名と、同じowner内のproperty宣言候補、既存の操作の参照位置、既存のcall表記を並べる。複数switchの同じ形変化、未変更target一件への解決を必須条件にしない。変更された既存helperも含める。

根拠は記載名/位置/header/条件/前後tokenの対応。unqualified参照、parameter/local/closure shadowing、任意receiver、同名宣言、extensionのowner対応、条件コンパイル、computed propertyは意味解決しない。candidateと反対材料/不明を表示し、「同じstorage」「依存解決済み」「共通化必須」「負債」と呼ばない。実calleeや役割が同じことを警告する試作にしない。

## 先に置く対照と終了判断

1. 既存fieldを使う追加操作と未変更の既存操作/利用側が離れている入力。
2. 同じ名前の別owner、nested local type、任意receiverのmember表記を区別。
3. parameter/local/closure shadowingはfield binding確定にしない。
4. 正当な専用操作/既存の共有済み操作は、同名参照があっても再配置警告なし。
5. stored/observed/computed propertyを区別してstorageを推測しない。
6. 字句条件/extension/overload/header対応の曖昧さはunknownと位置を保持。
7. literal UTF-8の非正規化、コメント/空白変更とtoken変更、物理位置を照合。
8. 正常0とparser/read/UTF-8/symlink失敗を分離、部分出力なし、同じ入力はprocess bytes一致。

成功はまず必要な差分外関係を事実として表現できるか。candidateの多さ、出力縮小、既知到達は有用性合格ではない。無関係/曖昧候補の量と、専用経路を支持する反対理由も残す。最小試作の結果で、新しい別固定入力の比較へ進むか、仮説を捨てるかを選ぶ。根拠のない旧方式継続やruleの追加を正当化しない。

外部OSSはread only、対象code/build/test/script/checkout/投稿をしない。自分の解析器と合成対照だけを実行。rawsource/diff/参照名dump/生reviewはignoredへ、公開はown code/位置/count/hash/所見。独立レビューはレビュー時だけ。人間判断待ちなし。
