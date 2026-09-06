import Foundation
import Testing

@testable import SekkaCore

@Test func gitBatchUsesByteLengthsForUnicodeAndEmbeddedHeaderLines() throws {
  let first = "// 雪\nsecond blob 0\n\nstruct A {}"
  let second = ""
  let data = Data("first blob \(first.utf8.count)\n\(first)\nsecond blob 0\n\(second)\n".utf8)
  let decoded = try GitBatch.decode(data, objects: ["first", "second"])
  #expect(decoded == ["first": first, "second": second])
}

@Test func invalidGitBatchCannotReturnPartialSuccess() throws {
  for input in ["a missing\n", "b blob 0\n\n", "a blob 4\nabc\n", "a blob -1\n\n", "a blob 0\n\nextra"] {
    #expect(throws: SekkaError.self) { try GitBatch.decode(Data(input.utf8), objects: ["a"]) }
  }
  var bytes = Data("a blob 1\n".utf8)
  bytes.append(255)
  bytes.append(10)
  #expect(throws: SekkaError.self) { try GitBatch.decode(bytes, objects: ["a"]) }
}
