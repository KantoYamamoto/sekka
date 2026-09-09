import CallSequenceExperiment
import Foundation

func sources(at path: String) throws -> [(String, String)] {
  let input = URL(fileURLWithPath: path).standardizedFileURL
  guard try input.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
    throw CocoaError(.fileReadUnsupportedScheme)
  }
  let root = input.resolvingSymlinksInPath()
  var directory: ObjCBool = false
  guard FileManager.default.fileExists(atPath: root.path, isDirectory: &directory), directory.boolValue else {
    throw CocoaError(.fileReadNoSuchFile)
  }
  var readError: (any Error)?
  guard let enumerator = FileManager.default.enumerator(
    at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
    options: [], errorHandler: { _, error in readError = error; return false }
  ) else { throw CocoaError(.fileReadUnknown) }
  var files: [(String, String)] = []
  for case let url as URL in enumerator {
    // Ignore dot-prefixed entries inside the input, not Finder visibility metadata.
    if url.lastPathComponent.hasPrefix(".") {
      enumerator.skipDescendants()
      continue
    }
    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
    if values.isSymbolicLink == true { throw CocoaError(.fileReadUnsupportedScheme) }
    guard url.pathExtension == "swift", values.isRegularFile == true else { continue }
    // Foundation may enumerate /private/var while the input canonicalizes to /var.
    let components = url.standardizedFileURL.resolvingSymlinksInPath().pathComponents
    guard Array(components.prefix(root.pathComponents.count)) == root.pathComponents else {
      throw CocoaError(.fileReadUnknown)
    }
    let relative = components.dropFirst(root.pathComponents.count).joined(separator: "/")
    files.append((relative, try String(contentsOf: url, encoding: .utf8)))
  }
  if let readError { throw readError }
  return files
}

do {
  guard CommandLine.arguments.count == 3 else {
    throw NSError(domain: "Usage: call-sequence-probe BEFORE_DIR AFTER_DIR", code: 2)
  }
  let report = try CallSequences.compare(
    before: sources(at: CommandLine.arguments[1]), after: sources(at: CommandLine.arguments[2]))
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
  FileHandle.standardOutput.write(try encoder.encode(report))
  FileHandle.standardOutput.write(Data([10]))
} catch {
  FileHandle.standardError.write(Data("\(error)\n".utf8))
  exit(2)
}
