import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('handoff', ROOT/'tools/handoff.py')
handoff = importlib.util.module_from_spec(spec)
spec.loader.exec_module(handoff)


class HandoffTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.directory = self.root/'docs/handoffs'
        self.directory.mkdir(parents=True)
        self.path = self.directory/'20261031T000000Z-test.json'
        self.schema = json.loads((ROOT/'docs/protocol/handoff.schema.json').read_text())
        self.record = {
            'protocol_version': '1.0', 'id': self.path.stem, 'created_at': '2026-10-31T00:00:00+00:00',
            'author': {'human': 'tester', 'tool': 'different-ai', 'model': 'unknown'},
            'status': 'partial', 'branch': 'feat/test', 'base_commit': None, 'previous_handoffs': [],
            'request': 'Make a gameplay change', 'summary': 'Added the change; GPU test unavailable.',
            'changes': [{'path': 'scripts/main.gd', 'kind': 'modified', 'summary': 'Update behavior'}],
            'decisions': [], 'contracts': [],
            'tests': [{'command': 'godot --headless', 'working_directory': '.', 'result': 'not_run', 'summary': 'Godot unavailable on this machine'}],
            'risks': ['Runtime verification pending'],
            'next_steps': [{'priority': 'P1', 'task': 'Run game tests', 'acceptance': 'Run the named test scripts and record the outcome'}],
            'recovery': {'strategy': 'git_revert', 'notes': 'Revert the gameplay commit; no save migration'},
        }

    def tearDown(self):
        self.temp.cleanup()

    def errors(self, record=None, path=None):
        return handoff.validate_record(record or self.record, path or self.path, self.root, self.schema)

    def test_valid_partial_and_honest_unrun_test(self):
        self.assertEqual(self.errors(), [])

    def test_required_test_evidence(self):
        self.record['tests'] = []
        self.assertTrue(self.errors())

    def test_rejects_fabricated_result_state(self):
        self.record['tests'][0]['result'] = 'probably_passed'
        self.assertTrue(self.errors())

    def test_rejects_unfilled_summary(self):
        self.record['summary'] = 'TODO: fill this'
        self.assertTrue(self.errors())

    def test_timezone_is_required(self):
        self.record['created_at'] = '2026-10-31T12:00:00'
        self.assertTrue(self.errors())

    def test_nonportable_and_parent_paths(self):
        for path in ['/Users/person/file', 'C:\\work\\file', '../secrets', './scripts/file']:
            with self.subTest(path=path):
                self.record['changes'][0]['path'] = path
                self.assertTrue(self.errors())

    def test_duplicate_paths_rejected(self):
        self.record['changes'].append(copy.deepcopy(self.record['changes'][0]))
        self.assertTrue(self.errors())

    def test_historical_deleted_paths_need_not_exist(self):
        self.record['changes'][0] = {'path': 'removed/file.gd', 'kind': 'deleted', 'summary': 'Removed obsolete code'}
        self.assertEqual(self.errors(), [])

    def test_previous_handoff_must_exist(self):
        self.record['previous_handoffs'] = ['docs/handoffs/missing.json']
        self.assertTrue(self.errors())

    def test_previous_handoff_may_not_reference_itself(self):
        self.path.write_text('{}')
        self.record['previous_handoffs'] = ['docs/handoffs/'+self.path.name]
        self.assertTrue(self.errors())

    def test_id_and_filename_match(self):
        self.record['id'] = '20261031T000001Z-other'
        self.assertTrue(self.errors())

    def test_update_must_include_handoff(self):
        errors = handoff.coverage_errors({'scripts/main.gd': 'modified'}, {})
        self.assertTrue(any('new docs/handoffs' in e for e in errors))

    def test_coverage_and_project_state_are_enforced(self):
        name = 'docs/handoffs/'+self.path.name
        changes = {'scripts/main.gd': 'modified', name: 'added'}
        self.assertTrue(any('PROJECT_STATE' in e for e in handoff.coverage_errors(changes, {name: self.record})))
        changes['docs/PROJECT_STATE.md'] = 'modified'
        self.assertTrue(any('missing changed paths' in e for e in handoff.coverage_errors(changes, {name: self.record})))
        self.record['changes'].append({'path': 'docs/PROJECT_STATE.md', 'kind': 'modified', 'summary': 'Reflect current behavior'})
        self.assertEqual(handoff.coverage_errors(changes, {name: self.record}), [])

    def test_handoffs_are_append_only(self):
        name = 'docs/handoffs/'+self.path.name
        self.assertTrue(any('append-only' in e for e in handoff.coverage_errors({name: 'modified'}, {name: self.record})))

    def test_followup_requires_an_existing_base_commit(self):
        subprocess.run(['git', 'init', '-b', 'main'], cwd=self.root, check=True, capture_output=True)
        subprocess.run(['git', 'config', 'user.name', 'Protocol Test'], cwd=self.root, check=True)
        subprocess.run(['git', 'config', 'user.email', 'test@example.invalid'], cwd=self.root, check=True)
        protocol = self.root/'docs/protocol'
        protocol.mkdir()
        (protocol/'handoff.schema.json').write_text(json.dumps(self.schema))
        self.path.write_text(json.dumps(self.record))
        subprocess.run(['git', 'add', '.'], cwd=self.root, check=True)
        subprocess.run(['git', 'commit', '-m', 'initial'], cwd=self.root, check=True, capture_output=True)
        base = handoff.git('rev-parse', 'HEAD', root=self.root)
        following = copy.deepcopy(self.record)
        following['id'] = '20261031T000001Z-followup'
        following['changes'] = [{'path': 'docs/PROJECT_STATE.md', 'kind': 'added', 'summary': 'Current task state'}]
        new_path = self.directory/(following['id']+'.json')
        new_path.write_text(json.dumps(following))
        (self.root/'docs/PROJECT_STATE.md').write_text('current state')
        self.assertTrue(any('null base_commit' in e for e in handoff.validate(self.root, base)))
        following['base_commit'] = 'f'*40
        new_path.write_text(json.dumps(following))
        self.assertTrue(any('not available' in e for e in handoff.validate(self.root, base)))
        following['base_commit'] = base
        new_path.write_text(json.dumps(following))
        self.assertEqual(handoff.validate(self.root, base), [])

    def test_generator_uses_git_and_preserves_existing_file(self):
        subprocess.run(['git', 'init', '-b', 'main'], cwd=self.root, check=True, capture_output=True)
        (self.root/'game.txt').write_text('original')
        path = handoff.new_record('new-task', 'developer', 'tool', self.root)
        generated = json.loads(path.read_text())
        self.assertIsNone(generated['base_commit'])
        self.assertEqual(generated['changes'][0]['path'], 'game.txt')
        self.assertTrue(any('TODO' in e for e in self.errors(generated, path)))
        with self.assertRaises(FileExistsError):
            # Freeze the filename by recreating the same task within the same second.
            from unittest.mock import patch
            with patch.object(handoff, 'datetime') as clock:
                from datetime import datetime
                clock.now.return_value = datetime.fromisoformat(generated['created_at'])
                handoff.new_record('new-task', 'developer', 'tool', self.root)


if __name__ == '__main__':
    unittest.main(verbosity=2)
