"""Own synthetic controls only. Never executes supplied Swift source."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

binary = str(Path(sys.argv[1]).resolve())
fixtures = Path(__file__).parent / "Fixtures"
before = (fixtures / "before.swift").read_text()
after = (fixtures / "after.swift").read_text()

with tempfile.TemporaryDirectory(prefix="sekka-relay-check-") as directory:
    root = Path(directory)
    old, new = root / "before.swift", root / "after.swift"
    old.write_text(before)

    def run(source, text=False, failure=False, old_source=before):
        old.write_text(old_source)
        new.write_text(source)
        command = [binary, str(old), str(new)] + (["--text"] if text else [])
        a = subprocess.run(command, capture_output=True, timeout=10)
        b = subprocess.run(command, capture_output=True, timeout=10)
        assert (a.returncode, a.stdout, a.stderr) == (b.returncode, b.stdout, b.stderr)
        if failure:
            assert a.returncode == 2 and not a.stdout and a.stderr
            return
        assert a.returncode == 0, a.stderr
        return a.stdout.decode() if text else json.loads(a.stdout)

    result = run(after)
    assert not result["unknown"]
    finding, = result["findings"]
    assert finding["dependency"] == "EventSink"
    assert [(s["owner"], s["selector"], s["childField"], s["child"], s["site"]["line"], s["pass"]["line"])
            for s in finding["steps"]] == [
        ("CheckoutScreen", "init(repository:events:)", "model", "CheckoutModel", 11, 12),
        ("CheckoutModel", "init(repository:events:)", "checkout", "Checkout", 17, 18)]
    assert finding["retainedBy"] == "Checkout" and finding["storage"]["line"] == 23
    assert [s["line"] for s in finding["writtenUses"]] == [30]
    assert finding["alternatives"] == ["CheckoutModel(checkout: Checkout)", "CheckoutScreen(model: CheckoutModel)"]
    output = run(after, text=True)
    assert "Benefit:" in output and "Conditions:" in output and "Compare:" in output
    print(output)

    no_candidates = {
        "unchanged": before,
        "middle-use": after.replace("checkout = Checkout(", 'events.record("middle")\n        checkout = Checkout('),
        "transform": after.replace("events: events)", "events: transform(events))") + "\nfunc transform(_ value: EventSink) -> EventSink { value }\n",
        "closure": after.replace("checkout = Checkout(", "let later = { events.record(\"later\") }\n        checkout = Checkout("),
        "overload": after.replace("struct CheckoutModel {", "struct CheckoutModel {\n    init() { checkout = Checkout(repository: Repository(), events: EventSink()) }"),
        "shadow-constructor": after + "\nfunc CheckoutModel(repository: Repository, events: EventSink) {}\n",
        "conditional": after + "\n#if DEBUG\nstruct DebugOnly {}\n#endif\n",
        "assembled": (fixtures / "assembled.swift").read_text(),
        "nested-self-not-leaf-use": after.replace('events.record("purchase")', "")
            .replace("struct Checkout {", "struct Checkout {\n    struct Nested { let events: EventSink; func record() { self.events.record(\"nested\") } }"),
        "member-factory-not-constructor": after.replace("struct CheckoutScreen {", "struct CheckoutScreen {\n    func CheckoutModel(repository: Repository, events: EventSink) -> CheckoutModel { fatalError() }"),
        "nested-function-parameter": after.replace('events.record("purchase")', 'func record(events: EventSink) { events.record("nested") }'),
        "closure-parameter": after.replace('events.record("purchase")', 'let record: (EventSink) -> Void = { events in events.record("nested") }'),
    }
    for name, source in no_candidates.items():
        assert not run(source)["findings"], name
    shadow_before = before.replace("struct CheckoutScreen {", "struct ModelFactory {\n    init() {}\n    func callAsFunction(repository: Repository) -> CheckoutModel { CheckoutModel(repository: repository) }\n}\nstruct CheckoutScreen {")
    shadow_before = shadow_before.replace("init(repository: Repository) {\n        model", "init(repository: Repository, CheckoutModel: ModelFactory) {\n        model")
    shadow_after = after.replace("struct CheckoutScreen {", "struct ModelFactory {\n    init() {}\n    func callAsFunction(repository: Repository, events: EventSink) -> CheckoutModel { CheckoutModel(repository: repository, events: EventSink()) }\n}\nstruct CheckoutScreen {")
    shadow_after = shadow_after.replace("init(repository: Repository, events: EventSink) {\n        model", "init(repository: Repository, events: EventSink, CheckoutModel: ModelFactory) {\n        model")
    assert not run(shadow_after, old_source=shadow_before)["findings"], "parameter-callAsFunction-not-constructor"
    run("struct Broken {", failure=True)
    print(f"PASS: positive evidence/alternative, {len(no_candidates) + 1} negative controls, parse failure; each output repeated byte-for-byte")
