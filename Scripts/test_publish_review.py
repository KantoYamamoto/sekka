import io
import json
import unittest
from unittest.mock import patch
import zipfile

from ci_review import render_summary
from publish_review import MARKER, current_pr, owned_comment, read_bundle, main


class PublishTests(unittest.TestCase):
    def bundle(self, head='a' * 40):
        data = io.BytesIO()
        with zipfile.ZipFile(data, 'w') as archive:
            archive.writestr('manifest.json', json.dumps({'head': head, 'base': 'b' * 40, 'changedFiles': ['App.swift']}))
            archive.writestr('candidate.compact', '{}')
            archive.writestr('candidate.text', '<script>untrusted</script>')
        return data.getvalue()

    def test_bundle_is_data_only_and_rejects_wrong_head(self):
        _, _, text = read_bundle(self.bundle(), 'a' * 40)
        self.assertIn('<script>', text)
        with self.assertRaises(ValueError):
            read_bundle(self.bundle(), 'c' * 40)
        with zipfile.ZipFile(io.BytesIO(self.bundle())) as archive:
            self.assertNotIn('summary.md', archive.namelist())

    def test_missing_bundle_and_large_payload_fail(self):
        data = io.BytesIO()
        with zipfile.ZipFile(data, 'w') as archive:
            archive.writestr('unrelated.txt', 'text')
        with self.assertRaises(ValueError):
            read_bundle(data.getvalue(), 'a' * 40)
        with patch('publish_review.LIMIT', 1):
            with self.assertRaises(ValueError):
                read_bundle(self.bundle(), 'a' * 40)

    def test_only_own_bot_comment_is_updated(self):
        spoof = {'id': 1, 'body': MARKER, 'user': {'login': 'someone', 'type': 'User'}}
        bot = {'id': 2, 'body': MARKER + '\nold', 'user': {'login': 'github-actions[bot]', 'type': 'Bot'}}
        self.assertEqual(owned_comment([spoof, bot]), bot)
        self.assertIsNone(owned_comment([spoof]))

    def test_head_repository_and_open_state_must_match(self):
        pr = {'state': 'open', 'base': {'repo': {'full_name': 'owner/repo'}}, 'head': {'sha': 'a', 'repo': {'full_name': 'fork/repo'}}}
        run = {'head_sha': 'a', 'head_repository': {'full_name': 'fork/repo'}}
        self.assertTrue(current_pr(pr, run, 'owner/repo'))
        pr['head']['sha'] = 'b'
        self.assertFalse(current_pr(pr, run, 'owner/repo'))

    def test_escape_expansion_is_bounded_and_runner_command_removed(self):
        body = render_summary({'base': 'a'*40, 'head': 'b'*40, 'changedFiles': []},
                              {'coverage': {'changedFiles': [], 'skippedBodyCount': 0}, 'findings': []},
                              '<'*16000 + '\nInspect source hunks: runner-only', 'https://github.com/o/r', '1', 'https://github.com/run')
        self.assertLess(len(body), 18000)
        self.assertNotIn('runner-only', body)
        self.assertIn('16,000文字', body)
        self.assertIn('未観測の変更が混在', body)

    def test_failed_run_replaces_previous_result_with_failure_notice(self):
        run = {'event': 'pull_request', 'path': '.github/workflows/pr-review.yml', 'status': 'completed',
               'pull_requests': [{'number': 1}], 'head_sha': 'a'*40,
               'head_repository': {'full_name': 'o/r'}, 'conclusion': 'failure'}
        pr = {'number': 1, 'state': 'open', 'base': {'repo': {'full_name': 'o/r'}},
              'head': {'sha': 'a'*40, 'repo': {'full_name': 'o/r'}}}
        writes = []
        def fake_api(path, payload=None):
            if payload:
                writes.append((path, payload))
                return {'html_url': 'https://github.com/comment'}
            if '/actions/runs/' in path: return run
            if '/pulls/' in path: return pr
            if '/comments?' in path:
                return [{'id': 7, 'body': MARKER, 'user': {'login': 'github-actions[bot]', 'type': 'Bot'}}]
            raise AssertionError(path)
        with patch.dict('os.environ', {'GITHUB_REPOSITORY': 'o/r', 'SEKKA_RUN_ID': '1', 'SEKKA_DRY_RUN': '0'}), patch('publish_review.api', fake_api):
            main()
        self.assertEqual(writes[0][0], 'repos/o/r/issues/comments/7')
        self.assertIn('結果を更新できませんでした', writes[0][1]['body'])
        self.assertNotIn('構造案内を開く', writes[0][1]['body'])
