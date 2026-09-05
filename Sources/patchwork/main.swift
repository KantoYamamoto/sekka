import Foundation
import PatchworkCore

private let help = """
  Patchwork 0.1.0-dev — Swift structural observations, without building the target.

  Usage:
    patchwork scan [--path DIRECTORY] [--format text|json]
    patchwork diff REF [--path REPOSITORY] [--head REF] [--merge-base]
    patchwork diff --before DIRECTORY --after DIRECTORY

  Options:
    --format text|json|github  Output format (default: text; github requires Git diff)
    --exclude PATH            Exclude a relative file/directory prefix; repeatable
    --fail-on-findings        Exit 1 for observations (default: exit 0)
    --head REF                Compare a committed head; default: working tree
    --merge-base              Compare against merge-base(REF, HEAD/--head)
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

  init(_ args: [String]) throws {
    guard let first = args.first, ["scan", "diff"].contains(first) else {
      throw PatchworkError.message(help)
    }
    command = first
    var index = 1
    while index < args.count {
      let arg = args[index]
      func value() throws -> String {
        guard index + 1 < args.count, !args[index + 1].hasPrefix("--") else {
          throw PatchworkError.message("Missing value for \(arg)")
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
      case "--exclude":
        let raw = try value()
        let item = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !raw.hasPrefix("/"), !item.isEmpty, !item.split(separator: "/").contains("..") else {
          throw PatchworkError.message("Exclude must be a relative file/directory prefix")
        }
        exclude.append(item)
      case "--merge-base": mergeBase = true
      case "--fail-on-findings": fail = true
      default:
        guard command == "diff", ref == nil, !arg.hasPrefix("-") else {
          throw PatchworkError.message("Unknown argument: \(arg)")
        }
        ref = arg
      }
      index += 1
    }
    guard ["text", "json", "github"].contains(format) else {
      throw PatchworkError.message("Unknown format: \(format)")
    }
    if command == "scan" {
      guard before == nil, after == nil, head == nil, !mergeBase, !fail, format != "github" else {
        throw PatchworkError.message("scan accepts --path, --exclude and --format text|json only")
      }
    } else if before != nil || after != nil {
      guard before != nil, after != nil, ref == nil, head == nil, !mergeBase else {
        throw PatchworkError.message(
          "Directory diff requires --before and --after, without Git options")
      }
      guard format != "github" else {
        throw PatchworkError.message(
          "github format requires Git mode so annotation paths match the repository")
      }
    } else if ref == nil {
      throw PatchworkError.message("diff requires a Git ref or --before/--after directories")
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
    print("patchwork 0.1.0-dev")
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
  if let before = options.before, let after = options.after {
    beforeFiles = try Inputs.directory(before, excluding: options.exclude)
    afterFiles = try Inputs.directory(after, excluding: options.exclude)
    beforeLabel = before
    afterLabel = after
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
  }
  guard !beforeFiles.isEmpty || !afterFiles.isEmpty else {
    throw PatchworkError.message(
      "No Swift files found on either side; check the input paths and exclusions")
  }
  let report = try Differ.compare(
    Analyzer.analyze(beforeFiles), Analyzer.analyze(afterFiles), beforeLabel: beforeLabel,
    afterLabel: afterLabel)
  switch options.format {
  case "json": print(try Renderer.json(report))
  case "github": print(Renderer.github(report))
  default: print(Renderer.text(report))
  }
  return options.fail && !report.findings.isEmpty ? 1 : 0
}

do { exit(try run()) } catch {
  FileHandle.standardError.write(Data("patchwork: \(error)\n".utf8))
  exit(2)
}
