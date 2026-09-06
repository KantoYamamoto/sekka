import unittest

from ci_review import render_summary


class SummaryTests(unittest.TestCase):
    def render(self, files, text):
        return render_summary(
            {"base": "a" * 40, "head": "b" * 40, "changedFiles": files},
            {"findings": [], "coverage": {"changedFiles": [], "skippedBodyCount": 0}},
            text, "https://github.com/KantoYamamoto/sekka", "1", "https://github.com/run",
        )

    def test_source_and_paths_cannot_inject_summary_html(self):
        result = self.render(['<img src="x">.swift'], '</pre><img src="x">')
        self.assertNotIn('<img src="x">', result)
        self.assertIn('&lt;img', result)
        self.assertIn('/pull/1/files#diff-', result)

    def test_summary_is_bounded_and_reports_omissions(self):
        result = self.render([f'{i}.swift' for i in range(30)], 'x' * 20000)
        self.assertEqual(result.count('/pull/1/files#diff-'), 20)
        self.assertIn('残り10ファイル', result)
        self.assertIn('16,000文字', result)
        self.assertIn('Swift差分はありません', result)
