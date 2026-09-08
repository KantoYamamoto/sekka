import Foundation
import Testing

@testable import SekkaCore

@Test func directoryInventoryIncludesBinaryAndCustomExclusionsWithoutParsingThem() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let before = root.appendingPathComponent("before")
  let after = root.appendingPathComponent("after")
  for dir in [before, after] {
    try FileManager.default.createDirectory(at: dir.appendingPathComponent(".build"), withIntermediateDirectories: true)
    try Data([0, 255]).write(to: dir.appendingPathComponent("image.bin"))
    try "struct Model {}".write(to: dir.appendingPathComponent("Model.swift"), atomically: true, encoding: .utf8)
  }
  try Data([0, 254]).write(to: after.appendingPathComponent("image.bin"))
  try "invalid Swift".write(to: after.appendingPathComponent("Excluded.swift"), atomically: true, encoding: .utf8)
  try "ignored".write(to: after.appendingPathComponent(".build/Generated.swift"), atomically: true, encoding: .utf8)
  try FileManager.default.createSymbolicLink(atPath: after.appendingPathComponent("Alias.swift").path, withDestinationPath: "Model.swift")
  let result = try Inputs.directoryChanges(before: before.path, after: after.path, excluding: ["Excluded.swift"])
  #expect(result.changes == [
    InputChange(file: "Excluded.swift", change: "added", analysis: "excluded"),
    InputChange(file: "image.bin", change: "modified", analysis: "non-swift"),
  ])
  #expect(result.scope.contains("symlinks and default excluded paths omitted"))
  #expect(try Inputs.directory(after.path, excluding: ["Excluded.swift"]).map(\.path) == ["Model.swift"])
}

@Test func directoryInventoryComparesBeyondFirstChunkAndKeepsDeletedPaths() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let before = root.appendingPathComponent("before")
  let after = root.appendingPathComponent("after")
  for dir in [before, after] { try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }
  var data = Data(repeating: 1, count: 80_000)
  try data.write(to: before.appendingPathComponent("large.bin"))
  data[79_999] = 2
  try data.write(to: after.appendingPathComponent("large.bin"))
  try Data().write(to: before.appendingPathComponent("gone.md"))
  let result = try Inputs.directoryChanges(before: before.path, after: after.path)
  #expect(result.changes.map(\.file) == ["gone.md", "large.bin"])
  #expect(result.changes.map(\.change) == ["deleted", "modified"])
  #expect(throws: SekkaError.self) {
    try Inputs.directoryChanges(before: root.appendingPathComponent("missing").path, after: after.path)
  }
}

@Test func inventoryTextIsBoundedAndBothJSONDetailsRetainTheSameInventory() throws {
  let inventory = ComparisonInventory(scope: "git-revisions", changes: (0..<25).map {
    InputChange(file: "docs/\($0).md", change: "added", analysis: "non-swift")
  })
  var report = Differ.compare(Snapshot(), Snapshot(), beforeLabel: "a", afterLabel: "b")
  report.inventory = inventory
  let text = Renderer.text(report)
  #expect(text.contains("Changed paths: 25"))
  #expect(text.contains("5 more paths"))
  #expect(text.contains("Changes exist, but none are analyzed as Swift"))
  #expect(!text.contains("docs/24.md"))
  for detail in [JSONDetail.compact, .full] {
    let object = try JSONSerialization.jsonObject(with: Data(Renderer.json(report, detail: detail).utf8)) as! [String: Any]
    let data = try JSONSerialization.data(withJSONObject: object["inventory"]!)
    #expect(try JSONDecoder().decode(ComparisonInventory.self, from: data) == inventory)
  }
  #expect(Renderer.github(report).contains("Sekka comparison scope"))
}
