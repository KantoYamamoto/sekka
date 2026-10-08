struct Grid<Element> {
  let onTap: (Element) -> Void
  init(data: [Element], onTap: @escaping (Element) -> Void) { self.onTap = onTap }
}
struct Screen {
  func open(_ value: Int) {}
  func named() { _ = Grid(data: [1], onTap: { item in open(item) }) }
  func implicit() { _ = Grid(data: [2], onTap: { open($0) }) }
  func branched() { _ = Grid(data: [3], onTap: { item in if item > 0 { open(item) } }) }
  func unused() { _ = Grid(data: [4], onTap: { _ in }) }
}
