struct Grid<Element> {
  let onTap: (Element, Int) -> Void
  init(data: [Element], onTap: @escaping (Element, Int) -> Void) { self.onTap = onTap }
}
struct Screen {
  func open(_ value: Int) {}
  func named() { _ = Grid(data: [1], onTap: { item, _ in open(item) }) }
  func implicit() { _ = Grid(data: [2], onTap: { item, _ in open(item) }) }
  func branched() { _ = Grid(data: [3], onTap: { item, _ in if item > 0 { open(item) } }) }
  func unused() { _ = Grid(data: [4], onTap: { _, _ in }) }
}
