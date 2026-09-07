import Foundation
import SekkaCore

private let help = """
  Sekka 0.2.0-dev — Swift structural observations, without building the target.

  Usage:
    sekka scan [--path DIRECTORY] [--format text|json]
    sekka diff REF [--path REPOSITORY] [--head REF] [--merge-base]
    sekka diff --before DIRECTORY --after DIRECTORY

  Options:
    --format text|json|github  Output format (default: text; github requires Git diff)
    --json-detail compact|full  Diff JSON detail (default: compact; schema version 2)
    --exclude PATH            Exclude a relative file/directory prefix; repeatable
    --fail-on-findings        Exit 1 for observations (default: exit 0)
    --head REF                Compare a committed head; default: working tree
    --merge-base              Compare against merge-base(REF, HEAD/--head)
    --show-diff FILE          Show source hunks for a changed analyzed Swift file (text only)
    --at before:LINE|after:LINE  Select a declaration's hunks; requires --expect-input
    --expect-input ID         Refuse navigation if analyzed source differs from the summary
    --help                    Show this help
    --version                 Show version

  Git mode analyzes the entire repository, even when --path is a subdirectory.
  Working tree includes staged/unstaged/untracked non-ignored Swift files.
  Directory mode does not interpret .gitignore. Symlinks are skipped in both modes.
  Defaults exclude .build, .swiftpm, .git, Pods, Carthage, DerivedData.
  Exit codes: 0 success, 1 observations with --fail-on-findings, 2 input/analysis error.
  """

private struct Options {
  var command = ""
  var ref: String?
  var path = FileManager.default.currentDirectoryPath
  var before: String?
  var after: String?
  var head: String?
  var format = "text"
  var exclude: [String] = []
  var mergeBase = false
  var fail = false
  var jsonDetail = JSONDetail.compact
  var jsonDetailSpecified = false
  var showDiff: String?
  var at: String?
  var expectInput: String?

  init(_ args: [String]) throws {
    guard let first = args.first, ["scan", "diff"].contains(first) else {
      throw SekkaError.message(help)
    }
    command = first
    var index = 1
    while index < args.count {
      let arg = args[index]
      func value() throws -> String {
        guard index + 1 < args.count, !args[index + 1].hasPrefix("--") else {
          throw SekkaError.message("Missing value for \(arg)")
        }
        index += 1
        return args[index]
      }
      switch arg {
      case "--path": path = try value()
      case "--before": before = try value()
      case "--after": after = try value()
      case "--head": head = try value()
      case "--format": format = try value()
      case "--show-diff": showDiff = try value()
      case "--at": at = try value()
      case "--expect-input": expectInput = try value()
      case "--json-detail":
        let raw = try value()
        guard let detail = JSONDetail(rawValue: raw) else {
          throw SekkaError.message("Unknown JSON detail: \(raw)")
        }
        jsonDetail = detail
        jsonDetailSpecified = true
      case "--exclude":
        let raw = try value()
        let item = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !raw.hasPrefix("/"), !item.isEmpty, !item.split(separator: "/").contains("..") else {
          throw SekkaError.message("Exclude must be a relative file/directory prefix")
        }
        exclude.append(item)
      case "--merge-base": mergeBase = true
      case "--fail-on-findings": fail = true
      default:
        guard command == "diff", ref == nil, !arg.hasPrefix("-") else {
          throw SekkaError.message("Unknown argument: \(arg)")
        }
        ref = arg
      }
      index += 1
    }
    guard ["text", "json", "github"].contains(format) else {
      throw SekkaError.message("Unknown format: \(format)")
    }
    if jsonDetailSpecified && (command != "diff" || format != "json") {
      throw SekkaError.message("--json-detail requires diff --format json")
    }
    if showDiff != nil || at != nil || expectInput != nil {
      guard command == "diff", showDiff != nil, format == "text", !fail else {
        throw SekkaError.message("Navigation requires diff --show-diff FILE --format text, without --fail-on-findings")
      }
      if at != nil && expectInput == nil {
        throw SekkaError.message("--at requires --expect-input from the summary; rerun the summary first")
      }
    }
    if command == "scan" {
      guard before == nil, after == nil, head == nil, !mergeBase, !fail, format != "github" else {
        throw SekkaError.message("scan accepts --path, --exclude and --format text|json only")
      }
    } else if before != nil || after != nil {
      guard before != nil, after != nil, ref == nil, head == nil, !mergeBase else {
        throw SekkaError.message(
          "Directory diff requires --before and --after, without Git options")
      }
      guard format != "github" else {
        throw SekkaError.message(
          "github format requires Git mode so annotation paths match the repository")
      }
    } else if ref == nil {
      throw SekkaError.message("diff requires a Git ref or --before/--after directories")
    }
  }
}

private func run() throws -> Int32 {
  let args = Array(CommandLine.arguments.dropFirst())
  if args.contains("--help") || args.isEmpty {
    print(help)
    return 0
  }
  if args == ["--version"] {
    print("sekka 0.2.0-dev")
    return 0
  }
  let options = try Options(args)
  if options.command == "scan" {
    let snapshot = try Analyzer.analyze(Inputs.directory(options.path, excluding: options.exclude))
    print(try options.format == "json" ? Renderer.json(snapshot) : Renderer.text(snapshot))
    return 0
  }
  let beforeFiles: [(path: String, source: String)]
  let afterFiles: [(path: String, source: String)]
  let beforeLabel: String
  let afterLabel: String
  let inventory: ComparisonInventory
  var replay: [String] = ["sekka", "diff"]
  if let before = options.before, let after = options.after {
    beforeFiles = try Inputs.directory(before, excluding: options.exclude)
    afterFiles = try Inputs.directory(after, excluding: options.exclude)
    beforeLabel = before
    afterLabel = after
    inventory = try Inputs.directoryChanges(before: before, after: after, excluding: options.exclude)
    replay += ["--before", URL(fileURLWithPath: before).standardizedFileURL.path,
      "--after", URL(fileURLWithPath: after).standardizedFileURL.path]
  } else {
    let root = try Inputs.gitRoot(options.path)
    let ref = options.ref!
    let headCommit = try options.head.map { try Inputs.revision($0, at: root) }
    let base =
      try options.mergeBase
      ? Inputs.commonAncestor(ref, headCommit ?? "HEAD", at: root) : Inputs.revision(ref, at: root)
    beforeFiles = try Inputs.gitSnapshot(base, at: root, excluding: options.exclude)
    if let headCommit {
      afterFiles = try Inputs.gitSnapshot(headCommit, at: root, excluding: options.exclude)
    } else {
      afterFiles = try Inputs.worktree(at: root, excluding: options.exclude)
    }
    beforeLabel =
      options.mergeBase
      ? "merge-base(\(ref), \(options.head ?? "HEAD")) [\(base.prefix(12))]"
      : "\(ref) [\(base.prefix(12))]"
    afterLabel = headCommit.map { "\(options.head!) [\($0.prefix(12))]" } ?? "working tree"
    inventory = try Inputs.gitChanges(from: base, to: headCommit, at: root, excluding: options.exclude)
    replay += [base, "--path", root]
    if let headCommit { replay += ["--head", headCommit] }
  }
  for excluded in options.exclude { replay += ["--exclude", excluded] }
  guard !beforeFiles.isEmpty || !afterFiles.isEmpty || !inventory.changes.isEmpty else {
    throw SekkaError.message(
      "No Swift files found on either side; check the input paths and exclusions")
  }
  let beforeSnapshot = try Analyzer.analyze(beforeFiles)
  let afterSnapshot = try Analyzer.analyze(afterFiles)
  var report = Differ.compare(
    beforeSnapshot, afterSnapshot, beforeLabel: beforeLabel,
    afterLabel: afterLabel)
  report.inventory = inventory
  let fingerprint = try options.format == "text"
    ? Inputs.fingerprint(before: beforeSnapshot, after: afterSnapshot) : nil
  if let expected = options.expectInput, expected != fingerprint {
    throw SekkaError.message("Analyzed input changed; rerun the summary before selecting old locations")
  }
  if let file = options.showDiff {
    print(try DiffNavigation.render(before: beforeSnapshot, after: afterSnapshot, report: report, file: file, at: options.at))
    return 0
  }
  switch options.format {
  case "json": print(try Renderer.json(report, detail: options.jsonDetail))
  case "github": print(Renderer.github(report))
  default:
    print(Renderer.text(report))
    if !report.coverage.changedFiles.isEmpty {
      func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
      print("Inspect source hunks: " + (replay + ["--expect-input", fingerprint!]).map(quote).joined(separator: " ")
        + " --show-diff FILE [--at before:LINE|after:LINE]")
    }
  }
  return options.fail && !report.findings.isEmpty ? 1 : 0
}

do { exit(try run()) } catch {
  FileHandle.standardError.write(Data("sekka: \(error)\n".utf8))
  exit(2)
}
