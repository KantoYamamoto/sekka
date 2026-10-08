import Foundation
import CallbackContracts

do {
  let args = Array(CommandLine.arguments.dropFirst())
  guard args.count == 2 || (args.count == 3 && args[2] == "--text") else { try inputFailure("usage: contract-probe BEFORE_DIRECTORY AFTER_DIRECTORY [--text]") }
  let result = compare(try SourceInventory(args[0]), try SourceInventory(args[1]))
  if args.count == 3 { print(render(result), terminator: "") }
  else { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]; print(String(decoding: try encoder.encode(result), as: UTF8.self)) }
} catch { FileHandle.standardError.write(Data(("contract-probe: \(error)\n").utf8)); exit(2) }
