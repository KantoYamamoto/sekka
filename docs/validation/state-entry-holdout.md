# #113: 状態・操作入口の未見比較

2026-10-07。新入口の限定2変更の比較。既読GRDB1881の候補到達を利益へ読み替えず、通常diffの外にある関係が構造の比較へ実使用されたかを点検する。本番/M3保留。

## 条件と根拠の出所

[protocol/評価器](../../Experiments/StructuralContext/StateEntryHoldout/plan.md)を`0eabdb7`、[選択](../../Experiments/StructuralContext/StateEntryHoldout/selection.json)を`171d585`でsource/diff取得前に固定した。新しい2repositoryのmetadata順で各1件。サイズ/タイトル/機械候補では選ばず、差し替えなし。

両stage1は同じPR説明とSwift diff、Bだけtext。両checkpoint保存/hash固定後に同じcaseのsourceを開放、同じ担当が継続した。レビューは通常file読取/検索だけで、他担当/他case/開発経緯は閲覧禁止。指示による分離でありOS隔離ではない。両側production Swift＋全変更fileが検索可能。未変更非Swift文書/設定、production外sourceは不足する。IceはLICENSEを含むがKeyboardShortcutsには取得規則に該当するLICENSEがなく、素材一覧にも存在しない。この欠落をAの最終レビューが記録した。対象build/test/script/checkoutや先方への投稿なし。

## 入力と機械実行

| 固定変更 | 変更file / 全Swift diff | 解析Swift file（前→後） | group | B text | JSON |
| --- | --- | --- | --- | --- | --- |
| [Ice #528](https://github.com/jordanbaird/Ice/pull/528) | 4 / 3,659 bytes | 118→118 | 1 | 2,089 bytes / 15行 | 10,221 bytes |
| [KeyboardShortcuts #216](https://github.com/sindresorhus/KeyboardShortcuts/pull/216) | 1 / 1,078 bytes | 10→10 | 3 | 4,640 bytes / 40行 | 16,329 bytes |

全258 source entriesのinventory/blob/mode/size/SHAと通常diffの全hunk/gap/tailを照合。[入力](../../Experiments/StructuralContext/StateEntryHoldout/inputs.json)、[diff照合](../../Experiments/StructuralContext/StateEntryHoldout/input-validation.json)、[実行](../../Experiments/StructuralContext/StateEntryHoldout/execution.json)へmetadataを残す。JSON/textを各二回、exit/stdout/stderr全bytes一致、両入力成功。debug process時間はIce約6秒、Keyboard約0.75秒で、レビュー時間/旧方式/release性能との比較ではない。JSONは事実点検用だけで、Bへ渡していない。

## Ice: UI比較へ実使用、中心の配置比較は通常source由来

A/Bとも、右クリックとControlクリックが既存の共通handlerへ集まることをsourceから確認し、guardの現配置を支持した。必要なhunk外の関係はafter `Ice/Events/EventManager.swift:21/148/256`、`Ice/MenuBar/MenuBarManager.swift:329`、`Ice/MenuBar/ControlItem/ControlItem.swift:390/419`。保存の反復は変更された既存`AdvancedSettingsManager.swift:54/65`のhunk外部分が材料で、Aは保存登録helperの成立条件と現方式の読みやすさを比較、Bは抽出を要求しない。機会がない変更ではない。

Bのtextは`AdvancedSettingsPane.manager`と既存property-body一覧を追加した。checkpointからmanager accessor16の確認へ進み、同じmanager/bindingへの接続を確認。既存の単純Toggle（text137、実宣言138/式139）との比較では、既に分割されたViewと共有bindingを維持する材料へ実使用した。Toggle式139は通常diff contextにも出るため、toolだけの発見としない。他のannotation/Slider等は主に便利文脈・不要/重複候補。表示件数から統合負担を認定していない。

イベント共通入口、保存登録、BindingExposable、General側の既存説明はtextにない。Bが指摘した新設定と既存案内の不整合（after `GeneralSettingsPane.swift:119–120`）もsource探索由来で、toolに帰属しない。A/Bの最終指摘差を案内の効果や時間短縮の証明にしない。Bはstage1の`loadInitialState()`名をdiff由来と書いたが実際は推定だったと訂正し、checkpointは不変。

## KeyboardShortcuts: 既存集合を比較に使用、核心helperは未提示

A/Bとも、同じ実ショートカットを使う別名のlegacyハンドラが残るとき、新規個別削除が共有登録まで解除する静的P2を記録した。対象OSSへ報告/修正はしない。未実行の静的追跡であり実環境の再現保証ではない。構造比較の問いは、名前別の辞書削除後の解除可否を既存helperへ委ねられるか。新規after `Sources/KeyboardShortcuts/KeyboardShortcuts.swift:193`に対し、既存124/135が全利用者の残存を調べ、既存stream終了550/571が同じhelperを使う。具体的な負担は、同じ解除判断を局所的に再実装し、streamのみを保護する規則と全利用者を保護する規則が食い違うこと。全件削除173では全legacyを消すためstreamとの差集合が成立し、同じ条件を個別削除へ写せない。この反対理由も比較した。広い登録寿命の再設計や他の既存問題は今回へ混ぜない。

Bはstage1のtextで16/32のproperty-body、173の全件削除、362/388の配送、435/461の登録を追加確認先にした。sourceで16がlegacy集合、32が両方式のunionと分かり、これらと173を構造比較へ実使用した。property-bodyというラベルだけでは名称/処理は分からず、本文を読む必要がある。10/11/24のproperty、登録/配送は主に挙動確認の入口。group間の16/173重複を複数成果に数えない。

核心の124/135、既存利用550/571、登録の重複排除91、getter/Carbon解除はtextにない。Bはこれらを通常sourceから追加した。Aもdiff段階で他名共有の懸念と解除規則の一元化を問い、sourceから同じhelperを比較した。したがって、問い/不具合の独自発見や確認時間短縮は支持しない。一方、textが示したhunk外の既存集合/bulk処理がBの構造比較に使われたという限定的な寄与は保存する。

## 結論と投資の境界

両変更に具体的な比較機会があり、機会なしの標本ではない。Iceは既存UIとの整合確認、Keyboardは集合/bulk規則の比較にtextが使われた。目的に近い材料を提示できる一例は得たが、核心の既存窓口が未提示で、通常sourceと同じ結論への到達以上の利益は未測定。本番/M3や全PR常設の合格とはしない。

この評価器を固定した2件の比較はここで終える。入力追加、当該2件に合わせた閾値や例外、旧switch方式の延命は行わない。次の根拠は、状態名を使う操作の一覧だけでなく「既存の状態集約→既存判断→利用」という関係が必要だったこと。新しい方式を試すなら、この差分外の関係を位置/不明と一緒に表せるか、既読診断として小さく検討する。未知の設計意図/副作用を推測する案、全関係を広げるだけの案は採らない。この具体的な根拠が表現できなければ、同じ一覧の細部調整へ戻らず投資判断を通知する。

## 点検と限界

[audit_receipts.py](../../Experiments/StructuralContext/StateEntryHoldout/audit_receipts.py)は全258entries、source/依存/binary/runner hash、全diff、実行JSON/text、text-only Bの同一共通資料、全4checkpoint不変を照合した。[receipt](../../Experiments/StructuralContext/StateEntryHoldout/receipt-audit.json)。保存receiptとの整合であり、実行の署名証明ではない。

生レビュー/通常source/機械出力はignored。公開は位置・数・hash・自作の所見だけ。独立事実点検で全25 group別候補位置・全4checkpoint/final hashを照合し、残るP1/P2なし。[metadata](../../Experiments/StructuralContext/StateEntryHoldout/independent-audit.json)。PR #114/最終Actions/実Bot/成果物確認は作業中。事実点検で露出表記を補正した。Keyboardの全件削除173では180はhunk外、181だけcontext（Aの180–181表記は誤り）。新規メソッド以外の既存メソッド本体は不変だが、外側enum宣言全体には追加があり変更されている（Bの「既存宣言変更なし」はメソッド単位に限定する）。Bの補助文脈の`.on`表記もliteral APIではなく、実際のViewModifiersは`onKeyboardShortcut`/`onGlobalKeyboardShortcut`からeventsへ接続する。stage2 promptのLICENSEを含むという一般記述はKeyboardで不成立で、素材一覧/本文の欠落を正とする。rawレビュー/promptは書き換えず、これらとBのIce stage1帰属訂正を残す。この2件を一般効果/盲検効果量の推定として扱わない。外部OSSはGET/readのみ、対象実行や先方に影響する操作なし。
