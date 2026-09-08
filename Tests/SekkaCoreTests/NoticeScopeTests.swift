import Foundation
import Testing

@testable import SekkaCore

private func jsonObject(_ report: DiffReport, detail: JSONDetail) throws -> [String: Any] {
  try #require(JSONSerialization.jsonObject(with: Data(Renderer.json(report, detail: detail).utf8)) as? [String: Any])
}

@Test func compactOmitsOnlyUnchangedFileConditionalLocations() throws {
  let unchanged = "#if DEBUG\nstruct A {}\n#endif"
  let duplicate = "struct Duplicate {}\nstruct Duplicate {}"
  let a = try Analyzer.analyze([("Fixture.swift", unchanged), ("Duplicate.swift", duplicate),
    ("Changed.swift", "#if DEBUG\nstruct B { let x = 1 }\n#endif")])
  let b = try Analyzer.analyze([("Fixture.swift", unchanged), ("Duplicate.swift", duplicate),
    ("Changed.swift", "#if RELEASE\nstruct B { let x = 2 }\n#endif")])
  let report = Differ.compare(a, b, beforeLabel: "a", afterLabel: "b")
  let compact = try jsonObject(report, detail: .compact)
  let full = try jsonObject(report, detail: .full)
  let kept = try #require(compact["notices"] as? [[String: Any]])
  let all = try #require(full["notices"] as? [[String: Any]])
  #expect(compact["omittedUnchangedConditionalNoticeCount"] as? Int == 2)
  #expect(all.count == kept.count + 2)
  let paths = kept.compactMap { ($0["location"] as? [String: Any])?["file"] as? String }
  #expect(!paths.contains("Fixture.swift"))
  #expect(paths.filter { $0 == "Changed.swift" }.count == 2)
  #expect(paths.contains("Duplicate.swift"))
  #expect((compact["limitations"] as? [String])?.contains { $0.contains("All conditional-compilation branches") } == true)
  #expect(try !Renderer.json(report, detail: .full).contains("conditionalHeader"))
  #expect(full["omittedUnchangedConditionalNoticeCount"] == nil)
}

@Test func commentOnlyChangesKeepConditionalLocations() throws {
  let source = "#if DEBUG\nstruct A {}\n#endif"
  let a = try Analyzer.analyze([("App.swift", source)])
  let b = try Analyzer.analyze([("App.swift", "// shifted\n" + source)])
  let report = Differ.compare(a, b, beforeLabel: "a", afterLabel: "b")
  let compact = try jsonObject(report, detail: .compact)
  #expect(compact["omittedUnchangedConditionalNoticeCount"] == nil)
  #expect((compact["notices"] as? [Any])?.count == 2)
  #expect(Renderer.text(report).contains("--json-detail full → notices"))
}
