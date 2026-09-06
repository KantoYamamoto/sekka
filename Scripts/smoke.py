"""Exercise the real CLI and Git snapshots in a disposable repository. No dependencies."""
import json
import re
from pathlib import Path
import subprocess
import sys
import tempfile

binary = Path(sys.argv[1] if len(sys.argv) > 1 else ".build/debug/sekka").resolve()
assert binary.is_file(), f"Build sekka first: {binary}"
checks = 0

with tempfile.TemporaryDirectory(prefix="sekka-smoke-") as temporary:
    repo = Path(temporary)

    def git(*args):
        return subprocess.run(
            ["git", "-c", "user.name=Sekka Tests", "-c", "user.email=tests@example.invalid", "-c", "commit.gpgsign=false", *args],
            cwd=repo, check=True, text=True, capture_output=True,
        ).stdout.strip()

    def run(*args, code=0):
        global checks
        result = subprocess.run([str(binary), *args], cwd=repo, text=True, capture_output=True)
        assert result.returncode == code, (args, result.returncode, result.stdout, result.stderr)
        checks += 1
        return result

    git("init", "-b", "main")
    (repo / ".gitignore").write_text("Ignored.swift\n")
    (repo / "Model.swift").write_text("struct Model { let repo: Repo }\n")
    (repo / "Deleted.swift").write_text("struct Deleted {}\n")
    (repo / "space name.swift").write_text("enum Choice { case a }\n")
    git("add", ".")
    git("commit", "-m", "base")
    base = git("rev-parse", "HEAD")

    clean = json.loads(run("diff", "HEAD", "--format", "json").stdout)
    assert clean["findings"] == []
    (repo / "Model.swift").write_text("struct Model { let repo: Repo; let analytics: Analytics }\n")
    (repo / "Deleted.swift").unlink()
    (repo / "New.swift").write_text("actor New {}\n")
    (repo / "Ignored.swift").write_text("invalid {{{")
    (repo / "Linked.swift").symlink_to(repo / "Model.swift")
    git("add", "Model.swift")
    dirty = json.loads(run("diff", "HEAD", "--format", "json").stdout)
    assert dirty["beforeFiles"] == 3 and dirty["afterFiles"] == 3
    assert any(f["rule"] == "type-removed" and f["type"] == "Deleted" for f in dirty["findings"])
    assert any(f["rule"] == "type-added" and f["type"] == "New" for f in dirty["findings"])
    assert any("Analytics" in f["added"] for f in dirty["findings"])
    assert dirty["schemaVersion"] == 2 and dirty["detail"] == "compact"
    assert len(dirty["coverage"]["changedFiles"]) == 3
    full = json.loads(run("diff", "HEAD", "--format", "json", "--json-detail", "full").stdout)
    assert full["coverage"] == dirty["coverage"]
    assert any("Analytics" in f["after"] for f in full["findings"])
    assert run("diff", "HEAD", "--format", "json").stdout == run("diff", "HEAD", "--format", "json").stdout
    run("diff", "HEAD", "--fail-on-findings", code=1)
    committed = json.loads(run("diff", "HEAD", "--head", "HEAD", "--format", "json").stdout)
    assert committed["findings"] == []
    excluded = json.loads(run("diff", "HEAD", "--exclude", "Model.swift", "--format", "json").stdout)
    assert not any(f["type"] == "Model" for f in excluded["findings"])
    annotations = run("diff", "HEAD", "--format", "github").stdout
    assert "::notice " in annotations and "::error " not in annotations
    summary = run("diff", "HEAD").stdout
    fingerprint = re.search(r"--expect-input' '([0-9a-f]+)'", summary).group(1)
    selected = run("diff", "HEAD", "--show-diff", "Model.swift", "--at", "after:1",
                   "--expect-input", fingerprint).stdout
    assert "Analytics" in selected and "showing all file hunks" in selected
    assert "Deleted" in run("diff", "HEAD", "--show-diff", "Deleted.swift").stdout
    saved = (repo / "Model.swift").read_bytes()
    (repo / "Model.swift").write_bytes(b"// shifted lines\n" + saved)
    stale = run("diff", "HEAD", "--show-diff", "Model.swift", "--at", "after:1",
                "--expect-input", fingerprint, code=2)
    assert stale.stdout == "" and "input changed" in stale.stderr
    (repo / "Model.swift").write_bytes(saved)
    run("diff", "HEAD", "--show-diff", "Model.swift", "--at", "after:1", code=2)
    run("diff", "HEAD", "--show-diff", "Model.swift", "--format", "json", code=2)
    run("diff", "HEAD", "--show-diff", "missing.swift", code=2)
    (repo / "space name.swift").write_text("enum Choice { case a, b }\n")
    assert "case a, b" in run("diff", "HEAD", "--show-diff", "space name.swift").stdout
    run("diff", "does-not-exist", code=2)
    run("scan", "--format", "wat", code=2)
    run("diff", "HEAD", "--format", "json", "--json-detail", "wat", code=2)
    run("diff", "HEAD", "--json-detail", "full", code=2)
    run("scan", "--format", "json", "--json-detail", "full", code=2)
    run("diff", "--before", str(repo), code=2)
    (repo / "Broken.swift").write_text("struct {")
    broken = run("diff", "HEAD", "--format", "json", code=2)
    assert broken.stdout == "" and "Cannot parse" in broken.stderr
    (repo / "Broken.swift").unlink()
    # Separate heads: main gains an unrelated type after the feature forked.
    git("add", "-A")
    git("commit", "-m", "feature")
    feature = git("rev-parse", "HEAD")
    git("checkout", "-b", "base-advanced", base)
    (repo / "Unrelated.swift").write_text("struct Unrelated {}\n")
    git("add", "Unrelated.swift")
    git("commit", "-m", "unrelated base change")
    fork = json.loads(run("diff", "HEAD", "--head", feature, "--merge-base", "--format", "json").stdout)
    assert not any(f["type"] == "Unrelated" for f in fork["findings"])
    assert any(f["type"] == "New" for f in fork["findings"])
    past = run("diff", "HEAD", "--head", feature, "--merge-base", "--show-diff", "Model.swift").stdout
    assert "Analytics" in past and "Unrelated" not in past
    assert git("rev-parse", "--abbrev-ref", "HEAD") == "base-advanced"
    assert git("status", "--porcelain") == ""
    # Comparing two empty trees must not be mistaken for a successful analysis.
    (repo / "Empty").mkdir()
    run("diff", "--before", str(repo / "Empty"), "--after", str(repo / "Empty"), code=2)

print(f"PASS: {checks} CLI/Git checks")
