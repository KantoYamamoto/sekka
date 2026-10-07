# 0052: 設定なしの一課題を、欲しい成果から選ぶ

**方針：未知の構造問題への気づきを助ける場合は、設計方針の設定を前提にせず、一つの具体的な負担と別配置を示せるかを実装前に確かめる。**

- 記録日：2026-10-07
- 状態：設定なしを採用。最初の対象と出力の利用価値は確認前。解析実装は未着手
- 関連：[#115](https://github.com/KantoYamamoto/sekka/issues/115)。[0051](0051-state-context-investment.md)の次実装案は採用しない

## 問題 / 選ぶ理由

局所的には自然な機能追加を繰り返すうちに、同じ機能のための修正・配線・判断が各所へ散る。変更行や関連メソッドを列挙しても、なぜ配置を見直す余地があるかは分からない。最初は「新しい依存を渡すためだけに中間の型も変える」を対象候補にする。これはユーザーが挙げたバケツリレーに対応し、責務の意味分類より明示的な引数の使い方を根拠にできる可能性がある。

設定されたルールの違反検査は、既に認識した方針を守る用途であり、未知の問題や既存方針自体の見直しを代替しない。Logger/Analyticsの責務一致やSwiftUIの適切な所有者は、この最小課題で解けるとは扱わない。

## 自作の対比例

Repository/EventSinkは同じAPIを持つ依存として省略した架空の例。実行結果や実OSSの証拠ではなく、欲しい成果を決めるための見本。

### 変更前

```swift
struct CheckoutScreen {
    let model: CheckoutModel
    init(repository: Repository) {
        model = CheckoutModel(repository: repository)
    }
}
struct CheckoutModel {
    let checkout: Checkout
    init(repository: Repository) {
        checkout = Checkout(repository: repository)
    }
}
struct Checkout {
    let repository: Repository
    func buy() { repository.save() }
}
```

### 局所追加の案

```swift
struct CheckoutScreen {
    let model: CheckoutModel
    init(repository: Repository, events: EventSink) {
        model = CheckoutModel(repository: repository, events: events)
    }
}
struct CheckoutModel {
    let checkout: Checkout
    init(repository: Repository, events: EventSink) {
        checkout = Checkout(repository: repository, events: events)
    }
}
struct Checkout {
    let repository: Repository
    let events: EventSink
    func buy() {
        repository.save()
        events.record("purchase")
    }
}
```

### 比較する配置

```swift
struct CheckoutScreen { let model: CheckoutModel }
struct CheckoutModel { let checkout: Checkout }

// Checkoutの実装は局所追加案と同じ。呼出側で組み立てる。
let checkout = Checkout(repository: repository, events: events)
let screen = CheckoutScreen(model: CheckoutModel(checkout: checkout))
```

Screen/Modelは既に持っている子オブジェクトを受け取る。この見本で今後Checkoutに別の依存を追加する場合、Checkoutと組み立て側の変更で済み、Screen/Modelの引数を増やす必要がない。今回のPRの行数が減るとは限らず、構築責務を移す初回の費用、呼出側が子の構築を知る費用がある。生成時期・所有・他の呼出側の契約を保てるかは別途確認が必要。

## 欲しい出力（手書き。実装結果ではない）

```text
新しい依存を渡すためだけに、2つの中間型が変更されています
├─ CheckoutScreen.init(events:) → CheckoutModel.init(events:)
│  追加引数eventsは子の構築へ渡すだけ
├─ CheckoutModel.init(events:) → Checkout.init(events:)
│  追加引数eventsは子の構築へ渡すだけ
└─ Checkoutでeventsを保持し、buyから参照

比較する案
  Checkoutを呼出側で組み立てる
  CheckoutModelはCheckout、CheckoutScreenはCheckoutModelを受け取る
  → Checkoutの依存追加を、2つの中間型のAPI変更から切り離せる

成立条件
  子の生成時期・所有を移してもよいこと
  中間層にこの依存を使う別の処理がないこと
  子の構築を呼出側へ公開しても、既存APIの境界を保てること
```

実際の出力には完全なselectorとソース位置を添える。上の`init(events:)`は新引数を説明する略記で、実際の宣言selectorは`init(repository:events:)`。利用価値が合意されるまで、これを実装済みの検出仕様や実測利益にしない。

## 反例と不明

| 対照 | 期待する扱い | 理由 |
| --- | --- | --- |
| Modelもevents.recordを呼ぶ | 2型とも渡すだけ、と出さない | Model自身にも明示的な利用がある。Screenだけの比較余地とは分ける |
| Modelが生成するclosureへeventsをcapture | 単純中継とは扱わない | 遅延利用や所有が変わり得る |
| initで検証・変換・条件分岐を行う | 単純な生成移設の提案を出さない | 中間層に構築上の処理がある |
| 名前の異なる引数、shadowing、overload、macro等で対応が不明 | 解決済みの経路として結ばない | 名前/型表記の一致だけでは同じ値・calleeを証明できない |
| 子のinitがprivate、または構築方法を隠すAPI契約がある | 無条件の移設案を出さない | アクセス制御の変更や呼出側の知識増加が必要になり得る |
| 既に子オブジェクトを受け取る配置へ追加 | 中間APIの連鎖変更として出さない | 新しい依存を知る場所が既に限定されている |
| 同じコードでも中間層が生成時期を所有する要求がある | 現配置も選択肢として残す | 要求は設定なしの構文から判定できない。自動修正/悪い設計との断定はしない |

## 合否 / 作業上限

1. **利用価値:** 読み手が、変更された中間層・その具体的負担・別配置・成立条件を短い出力から説明できる。件数や経路だけなら不合格。まずこの段階を人間と確認する。
2. **取得可能性:** 上の根拠を、設定なし/LLMなしで取れる入力と処理へ落とせる。意味解決が不明なら対象を捏造せず、最小範囲の不足を明示する。
3. **最小試作:** 利用価値を確認後に一仮説・一試作。自作の局所追加/利用あり/組立済みを区別できるかを確認する。実OSSはそれから読み取り専用で一例を調べる。

既存の単一関数`direct-forwarding-shape`は複数型の新依存伝搬と別配置を示さないため、その出力整形だけではこの課題を満たさない。既存解析を採用するのは上の必要根拠に合う場合だけ。一般graph、広いparser対応、配布、追加A/B、網羅的監査を先行させない。第一段階で役立たないならコードを書かず別の課題を選ぶ。試作が核心に届かなければ例外や閾値で延命しない。

## 実装前の独立レビュー

開発履歴なし・この文書だけのレビュー一回で、件数一覧を越えて別配置を比較する形にはなっているが、利用価値は要人間判断とされた。構築時期/所有に加え、アクセス制御/構築を隠す契約/呼出側の知識増加を上の条件と反例へ統合した。機械で「渡すだけ」を取得できた証拠や実用性の合格ではない。ここで解析実装へ進めない。
