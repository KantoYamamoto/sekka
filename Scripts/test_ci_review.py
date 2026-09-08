import unittest

from ci_review import render_summary, tree_text


class SummaryTests(unittest.TestCase):
    def render(self, files, text):
        return render_summary(
            {"base": "a" * 40, "head": "b" * 40, "changedFiles": files},
            {"findings": [], "coverage": {"changedFiles": [], "skippedBodyCount": 0},
             "inventory": {"scope": "test", "changes": [
                 {"file": f, "change": "modified", "analysis": "non-swift"} for f in files]}},
            text, "https://github.com/KantoYamamoto/sekka", "1", "https://github.com/run",
        )

    def test_source_and_paths_cannot_inject_summary_html(self):
        result = self.render(['<img src="x">.swift'], '</pre><img src="x">')
        self.assertNotIn('<img src="x">', result)
        self.assertIn('&lt;img', result)
        self.assertIn('/pull/1/files#diff-', result)

    def test_summary_is_bounded_and_reports_omissions(self):
        result = self.render([f'{i}.swift' for i in range(30)], 'x' * 20000)
        self.assertEqual(result.count('/pull/1/files#diff-'), 5)
        self.assertIn('残り25パス', result)
        self.assertIn('16,000文字', result)
        self.assertIn('Swift差分はありません', result)

    def test_shared_inventory_is_the_file_source_and_units_are_explicit(self):
        result = render_summary(
            {"base": "a" * 40, "head": "b" * 40, "changedFiles": ["stale.md"]},
            {"findings": [], "coverage": {"changedFiles": [], "skippedBodyCount": 0},
             "inventory": {"scope": "git-revisions", "changes": [
                 {"file": "current.md", "change": "added", "analysis": "non-swift"}]}},
            "", "https://github.com/KantoYamamoto/sekka", "1", "https://github.com/run")
        self.assertIn('current.md', result)
        self.assertNotIn('stale.md', result)
        self.assertIn('構造観測（件）', result)
        self.assertIn('本体比較省略（本体）', result)

    def test_file_entry_combines_structure_and_body_states(self):
        result = render_summary(
            {"base": "a", "head": "b"},
            {"findings": [], "inventory": {"scope": "test", "changes": [
                {"file": "App.swift", "analysis": "swift"}]},
             "coverage": {"changedFiles": [{"file": "App.swift", "observationCount": 0, "syntaxChanged": True}],
                          "skippedBodyCount": 1, "bodyComparisons": [
                              {"afterLocation": {"file": "App.swift"}, "status": "changed-syntax-only"},
                              {"beforeLocation": {"file": "App.swift"}, "status": "not-compared"}]}},
            "", "https://github.com/example/repo", "1", "https://github.com/run")
        self.assertIn('構造観測 0件 / 本体token変更 1本体（構造指標は同じ） / 本体未比較 1本体', result)
        self.assertEqual(result.count('/pull/1/files#diff-'), 1)
        self.assertNotIn('[構造観測なし]', result)

    def test_untrusted_inventory_status_does_not_become_html(self):
        result = render_summary(
            {"base": "a" * 40, "head": "b" * 40, "changedFiles": []},
            {"findings": [], "coverage": {"changedFiles": [], "skippedBodyCount": 0},
             "inventory": {"scope": "<img>", "changes": [
                 {"file": "doc.md", "analysis": "<img src=x>"}]}},
            "", "https://github.com/KantoYamamoto/sekka", "1", "https://github.com/run")
        self.assertNotIn('<img', result)
        self.assertIn('解析状態不明', result)


class TreeTests(unittest.TestCase):
    def test_branches_preserve_hierarchy_and_clear_between_types(self):
        source = "TypeA\n  change\n    removed\n    added\n  limitation\n\nTypeB\n  only\n    detail"
        expected = "TypeA\n├─ change\n│  ├─ removed\n│  └─ added\n└─ limitation\n\nTypeB\n└─ only\n   └─ detail"
        self.assertEqual(tree_text(source), expected)

    def test_literal_symbols_and_non_indented_notes_are_preserved(self):
        source = 'Header\n  + value: "│"\nNOTE scope remains unknown'
        self.assertEqual(tree_text(source), 'Header\n└─ + value: "│"\nNOTE scope remains unknown')
