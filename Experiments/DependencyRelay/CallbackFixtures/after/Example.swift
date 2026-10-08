struct Item {}
struct Leaf {
  let onSelect: (Item) -> Void
  func select(_ item: Item) { onSelect(item) }
}
struct Screen {
  let onResume: (Item) -> Void
  var body: Panel { Panel(onResume: onResume) }
}
struct Panel {
  let onResume: (Item) -> Void
  var body: Leaf { Leaf(onSelect: onResume) }
}
func makeScreen() -> Screen { Screen(onResume: { _ in }) }
