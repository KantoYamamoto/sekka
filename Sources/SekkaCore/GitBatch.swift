import Foundation

enum GitBatch {
  /// Git's batch protocol frames object contents by byte length, not lines or characters.
  static func decode(_ data: Data, objects: [String]) throws -> [String: String] {
    var cursor = 0
    var sources: [String: String] = [:]
    func invalid() -> SekkaError { .message("Invalid or incomplete Git batch output; analysis stopped") }
    for object in objects {
      guard cursor < data.count, let newline = data[cursor...].firstIndex(of: 10),
        let header = String(data: data[cursor..<newline], encoding: .utf8)
      else { throw invalid() }
      let fields = header.split(separator: " ")
      guard fields.count == 3, fields[0] == object, fields[1] == "blob",
        let count = Int(fields[2]), count >= 0
      else { throw invalid() }
      let start = newline + 1
      guard start < data.count, count <= data.count - start - 1, data[start + count] == 10 else {
        throw invalid()
      }
      guard let source = String(data: data[start..<(start + count)], encoding: .utf8) else {
        throw SekkaError.message("Git returned non-UTF-8 source; analysis stopped")
      }
      sources[object] = source
      cursor = start + count + 1
    }
    guard cursor == data.count else { throw invalid() }
    return sources
  }
}
