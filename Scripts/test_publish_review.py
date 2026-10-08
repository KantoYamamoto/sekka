import io
import json
import unittest
from unittest.mock import patch
import zipfile

from ci_review import render_summary
from publish_review import MARKER, current_pr, owned_comment, read_bundle, read_api_review, main


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

    def test_optional_trial_bundle_rejects_partial_duplicate_and_wrong_schema(self):
        self.assertEqual(read_api_review(self.bundle()), (None, ''))
        def trial(report, text=True, duplicate=False):
            data = io.BytesIO()
            with zipfile.ZipFile(data, 'w') as archive:
                archive.writestr('api-review.json', json.dumps(report))
                if text: archive.writestr('api-review.text', '</pre><img>')
                if duplicate: archive.writestr('api-review.text', 'duplicate')
            return data.getvalue()
        valid={'schemaVersion':1, 'analysis':'experimental-callback-contracts', 'contract':{'changes':[{'adaptations':[1]}]}}
        self.assertEqual(read_api_review(trial(valid)), (valid, '</pre><img>'))
        for data in [trial(valid, text=False), trial({'schemaVersion':2}), trial({'schemaVersion':1,'analysis':'experimental-callback-contracts','contract':{'changes':[{}]}})]:
            with self.assertRaises(ValueError): read_api_review(data)
        with self.assertWarns(UserWarning): data=trial(valid, duplicate=True)
        with self.assertRaises(ValueError): read_api_review(data)

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
                              {'coverage': {'changedFiles': [], 'skippedBodyCount': 0}, 'findings': [],
                               'inventory': {'scope': 'test', 'changes': []}},
                              '<'*16000 + '\nInspect source hunks: runner-only', 'https://github.com/o/r', '1', 'https://github.com/run')
        self.assertLess(len(body), 18000)
        self.assertNotIn('runner-only', body)
        self.assertIn('16,000文字', body)
        self.assertIn('未観測の変更が混在', body)

    def test_successful_publisher_passes_trial_data_to_trusted_renderer(self):
        run = {'event':'pull_request','path':'.github/workflows/pr-review.yml','status':'completed',
               'pull_requests':[{'number':1}], 'head_sha':'a'*40, 'head_repository':{'full_name':'o/r'}, 'conclusion':'success'}
        pr = {'number':1,'state':'open','base':{'sha':'c'*40,'repo':{'full_name':'o/r'}},
              'head':{'sha':'a'*40,'repo':{'full_name':'o/r'}}}
        manifest={'head':'a'*40,'base':'b'*40,'changedFiles':[]}
        report={'coverage':{'changedFiles':[],'skippedBodyCount':0},'findings':[], 'inventory':{'scope':'test','changes':[]}}
        trial={'schemaVersion':1,'analysis':'experimental-callback-contracts','contract':{'changes':[{'adaptations':[1,2]}]}}
        data=io.BytesIO()
        with zipfile.ZipFile(data,'w') as archive:
            for name,value in [('manifest.json',manifest),('candidate.compact',report),('api-review.json',trial)]:
                archive.writestr(name,json.dumps(value))
            archive.writestr('candidate.text','normal')
            archive.writestr('api-review.text','</pre><img>')
            archive.writestr('summary.md','<script>must not publish this</script>')
        writes=[]
        def fake_api(path,payload=None):
            if payload:
                writes.append(payload['body']); return {'html_url':'https://github.com/comment'}
            if path.endswith('/artifacts'): return {'artifacts':[{'name':'sekka-review-1','expired':False,'size_in_bytes':1000,'id':1}]}
            if '/actions/runs/' in path: return run
            if '/pulls/' in path: return pr
            if '/compare/' in path: return {'merge_base_commit':{'sha':'b'*40}}
            if '/comments?' in path: return []
            raise AssertionError(path)
        with patch.dict('os.environ',{'GITHUB_REPOSITORY':'o/r','SEKKA_RUN_ID':'1','SEKKA_DRY_RUN':'0'}), patch('publish_review.api',fake_api), patch('publish_review.subprocess.check_output',return_value=data.getvalue()):
            main()
        self.assertIn('候補 1件',writes[0]); self.assertIn('適応 2箇所',writes[0])
        self.assertIn('&lt;img&gt;',writes[0]); self.assertNotIn('<img>',writes[0]); self.assertNotIn('<script>',writes[0])

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
