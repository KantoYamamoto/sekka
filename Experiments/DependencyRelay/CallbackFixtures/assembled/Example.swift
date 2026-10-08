struct Item {}
struct Leaf {
  let onSelect: (Item) -> Void
  func select(_ item: Item) { onSelect(item) }
}
struct Screen {
  let panel: Panel
}
struct Panel {
  let content: Leaf
}
func makeScreen() -> Screen { Screen(panel: Panel(content: Leaf(onSelect: { _ in }))) }
