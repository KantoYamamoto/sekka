"""Capture a reproducible, local Sekka review bundle. Never edits the input repository."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time


def capture(repo, base, head, binary, output, baseline=None):
    def git(*args):
        return subprocess.check_output(["git", "-C", str(repo), *args])

    repo = Path(git("rev-parse", "--show-toplevel").decode().strip())
    base = git("rev-parse", "--verify", base + "^{commit}").decode().strip()
    head = git("rev-parse", "--verify", head + "^{commit}").decode().strip()
    # Keep raw source/diff and binaries out of version control, including external app inputs.
    output = output.resolve()
    ignored = subprocess.run(
        ["git", "-C", str(repo), "check-ignore", "-q", str(output)], capture_output=True
    )
    if ignored.returncode != 0:
        raise ValueError("Output must be inside the input repository and ignored by Git")
    output.mkdir(parents=True, exist_ok=False)
    patch = git("diff", "--no-ext-diff", "--no-textconv", "--no-color", base, head, "--", "*.swift")
    (output / "ordinary.diff").write_bytes(patch)
    changed = git("diff", "--name-only", "-z", base, head).decode().split("\0")
    manifest = {
        "base": base, "head": head,
        "changedFiles": [p for p in changed if p],
        "ordinaryDiffCharacters": len(patch.decode()),
        "ordinaryDiffSHA256": hashlib.sha256(patch).hexdigest(),
        "tools": {},
        "reviewTime": None,
        "warning": "Tool execution time is not review time. Self-review is not independent validation.",
    }
    for label, executable in [("candidate", binary), ("baseline", baseline)]:
        if executable is None:
            continue
        # Freeze evaluator bytes before running; rebuilding the original cannot change this run.
        frozen = output / (label + "-sekka")
        shutil.copyfile(executable.resolve(), frozen)
        frozen.chmod(0o700)
        version = subprocess.check_output([str(frozen), "--version"]).decode().strip()
        results = {}
        for name, options in [
            ("text", []), ("compact", ["--format", "json"]),
            ("full", ["--format", "json", "--json-detail", "full"]),
        ]:
            start = time.monotonic()
            data = subprocess.check_output(
                [str(frozen), "diff", base, "--head", head, "--path", str(repo), *options]
            )
            elapsed = time.monotonic() - start
            (output / (label + "." + name)).write_bytes(data)
            results[name] = {"characters": len(data.decode()), "seconds": elapsed}
        manifest["tools"][label] = {
            "version": version, "sha256": hashlib.sha256(frozen.read_bytes()).hexdigest(),
            "outputs": results,
        }
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (output / "review.md").write_text(
        "# Self-review notes\n\n"
        "- Review locations selected from Sekka: TODO\n"
        "- Findings from ordinary.diff (including unobserved changes): TODO\n"
        "- Noise or missing navigation: TODO\n"
        "- Next improvement and regression case: TODO\n"
        "- Prior knowledge / limitations / review time: TODO\n"
    )
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--base", required=True)
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--binary", type=Path, default=Path(".build/debug/sekka"))
    parser.add_argument("--baseline-binary", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    capture(args.repo, args.base, args.head, args.binary, args.output, args.baseline_binary)
    print("Review bundle:", args.output.resolve())
