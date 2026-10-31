"""Portable, standard-library-only handoff generator and protocol validator."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
HANDOFFS = 'docs/handoffs/'


def git(*args: str, root: Path = ROOT, allow_fail: bool = False) -> str:
    result = subprocess.run(['git', *args], cwd=root, capture_output=True, text=True, encoding='utf-8')
    if result.returncode and not allow_fail:
        raise RuntimeError(result.stderr.strip() or 'git command failed')
    return result.stdout.rstrip('\n') if result.returncode == 0 else ''


def valid_path(value: str, allow_dot: bool = False) -> bool:
    if value == '.' and allow_dot:
        return True
    p = PurePosixPath(value)
    return bool(value) and not p.is_absolute() and '\\' not in value and ':' not in value and '..' not in p.parts and str(p) == value and value != '.'


def schema_errors(value, spec: dict, schema: dict, where: str = '$') -> list[str]:
    """Validate exactly the JSON Schema subset used in our versioned schema."""
    if '$ref' in spec:
        node = schema
        for part in spec['$ref'].removeprefix('#/').split('/'):
            node = node[part]
        return schema_errors(value, node, schema, where)
    errors = []
    if 'const' in spec and value != spec['const']:
        errors.append(f'{where}: expected {spec["const"]!r}')
    if 'enum' in spec and value not in spec['enum']:
        errors.append(f'{where}: invalid value {value!r}')
    types = spec.get('type', [])
    types = [types] if isinstance(types, str) else types
    matches = {'object': isinstance(value, dict), 'array': isinstance(value, list),
               'string': isinstance(value, str), 'boolean': isinstance(value, bool), 'null': value is None}
    if types and not any(matches.get(t, False) for t in types):
        return errors + [f'{where}: expected {types}']
    if isinstance(value, str):
        if len(value.strip()) < spec.get('minLength', 0):
            errors.append(f'{where}: empty text')
        if value.strip().startswith('TODO:') or value.strip() == 'TODO':
            errors.append(f'{where}: fill the TODO placeholder')
        if 'pattern' in spec and not re.search(spec['pattern'], value):
            errors.append(f'{where}: invalid format')
        if spec.get('format') == 'date-time':
            try:
                if datetime.fromisoformat(value.replace('Z', '+00:00')).tzinfo is None:
                    raise ValueError('timezone missing')
            except ValueError:
                errors.append(f'{where}: use ISO 8601 with a timezone')
    if isinstance(value, dict):
        for key in spec.get('required', []):
            if key not in value:
                errors.append(f'{where}: missing {key}')
        properties = spec.get('properties', {})
        for key, child in value.items():
            if key in properties:
                errors += schema_errors(child, properties[key], schema, f'{where}.{key}')
            elif spec.get('additionalProperties') is False:
                errors.append(f'{where}: unknown field {key}')
    if isinstance(value, list):
        if len(value) < spec.get('minItems', 0):
            errors.append(f'{where}: not enough items')
        for i, child in enumerate(value):
            errors += schema_errors(child, spec.get('items', {}), schema, f'{where}[{i}]')
    return errors


def validate_record(data: dict, path: Path, root: Path, schema: dict) -> list[str]:
    errors = schema_errors(data, schema, schema)
    if errors:
        return errors
    if path.stem != data['id']:
        errors.append('id must match filename')
    seen = set()
    for change in data['changes']:
        name = change['path']
        if not valid_path(name):
            errors.append(f'non-portable change path: {name}')
        if name in seen:
            errors.append(f'duplicate change path: {name}')
        seen.add(name)
    for test in data['tests']:
        if not valid_path(test['working_directory'], allow_dot=True):
            errors.append('test working_directory must be repository-relative')
    for previous in data['previous_handoffs']:
        if not valid_path(previous) or not previous.startswith(HANDOFFS) or not previous.endswith('.json'):
            errors.append(f'invalid previous handoff path: {previous}')
        elif previous == path.relative_to(root).as_posix() or not (root/previous).is_file():
            errors.append(f'previous handoff missing or self-referencing: {previous}')
    return errors


def changed_files(root: Path, base: str | None) -> dict[str, str]:
    result = {}
    if base:
        parts = git('diff', '--name-status', '--no-renames', '-z', base, '--', root=root).split('\0')
        for i in range(0, len(parts)-1, 2):
            status, path = parts[i:i+2]
            result[path] = {'A': 'added', 'D': 'deleted'}.get(status[0], 'modified')
    else:
        for path in git('ls-files', '-z', root=root).split('\0'):
            if path:
                result[path] = 'added'
    for path in git('ls-files', '--others', '--exclude-standard', '-z', root=root).split('\0'):
        if path:
            result[path] = 'added'
    return result


def coverage_errors(changes: dict[str, str], records: dict[str, dict]) -> list[str]:
    errors = []
    existing = [p for p, kind in changes.items() if p.startswith(HANDOFFS) and p.endswith('.json') and kind != 'added']
    if existing:
        errors.append('historical handoffs are append-only: ' + ', '.join(existing))
    added = [p for p, kind in changes.items() if p.startswith(HANDOFFS) and p.endswith('.json') and kind == 'added']
    if changes and not added:
        errors.append('add a new docs/handoffs/*.json for this update')
    if changes and 'docs/PROJECT_STATE.md' not in changes:
        errors.append('update docs/PROJECT_STATE.md for this update')
    declared = set()
    for name in added:
        for change in records.get(name, {}).get('changes', []):
            declared.add(change['path'])
    missing = [p for p in changes if not (p.startswith(HANDOFFS) and p.endswith('.json')) and p not in declared]
    if missing:
        errors.append('handoff missing changed paths: ' + ', '.join(sorted(missing)))
    return errors


def choose_base(root: Path) -> str | None:
    head = git('rev-parse', '--verify', 'HEAD', root=root, allow_fail=True)
    if not head:
        return None
    branch = git('branch', '--show-current', root=root)
    remote = git('rev-parse', '--verify', 'origin/main', root=root, allow_fail=True)
    return git('merge-base', head, remote, root=root) if remote and branch != 'main' else head


def new_record(slug: str, author: str, tool: str, root: Path = ROOT) -> Path:
    if not re.fullmatch('[a-z0-9][a-z0-9-]*', slug):
        raise ValueError('task name must use lowercase letters, digits and hyphens')
    now = datetime.now(timezone.utc).replace(microsecond=0)
    identifier = now.strftime('%Y%m%dT%H%M%SZ-')+slug
    path = root/HANDOFFS/(identifier+'.json')
    base = choose_base(root)
    changes = changed_files(root, base)
    record = {
        'protocol_version': '1.0', 'id': identifier, 'created_at': now.isoformat(),
        'author': {'human': author, 'tool': tool, 'model': 'unknown'},
        'status': 'partial', 'branch': git('symbolic-ref', '--short', 'HEAD', root=root),
        'base_commit': base, 'previous_handoffs': [],
        'request': 'TODO: 用户需求', 'summary': 'TODO: 最终行为与完成范围',
        'changes': [{'path': p, 'kind': kind, 'summary': 'TODO: 改动及原因'} for p, kind in sorted(changes.items()) if not (p.startswith(HANDOFFS) and p.endswith('.json'))],
        'decisions': [], 'contracts': [],
        'tests': [{'command': 'TODO: 实际命令', 'working_directory': '.', 'result': 'not_run', 'summary': 'TODO: 结果或未执行原因'}],
        'risks': [], 'next_steps': [],
        'recovery': {'strategy': 'git_revert', 'notes': 'TODO: 恢复方法与数据注意事项'},
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('x', encoding='utf-8', newline='\n') as f:
        json.dump(record, f, ensure_ascii=False, indent=2)
        f.write('\n')
    return path


def validate(root: Path = ROOT, base: str | None = None) -> list[str]:
    schema = json.loads((root/'docs/protocol/handoff.schema.json').read_text(encoding='utf-8'))
    errors = []
    records = {}
    paths = sorted((root/HANDOFFS).glob('*.json'))
    if not paths:
        errors.append('no handoff records found')
    for path in paths:
        relative = path.relative_to(root).as_posix()
        try:
            data = json.loads(path.read_text(encoding='utf-8'))
            found = validate_record(data, path, root, schema)
            errors += [f'{relative}: {message}' for message in found]
            if not found:
                records[relative] = data
        except (ValueError, OSError) as exc:
            errors.append(f'{relative}: {exc}')
    if base and set(base) != {'0'}:
        if not re.fullmatch('[0-9a-f]{40}', base):
            errors.append('base must be a complete commit SHA')
        else:
            changes = changed_files(root, base)
            errors += coverage_errors(changes, records)
            for name, kind in changes.items():
                if name.startswith(HANDOFFS) and name.endswith('.json') and kind == 'added' and name in records:
                    parent = records[name]['base_commit']
                    if parent is None:
                        errors.append(f'{name}: only the initial repository snapshot may use null base_commit')
                    elif git('cat-file', '-t', parent, root=root, allow_fail=True) != 'commit':
                        errors.append(f'{name}: base_commit is not available in Git history')
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    new = sub.add_parser('new', help='generate an unfilled handoff from the current diff')
    new.add_argument('slug')
    new.add_argument('--author', default=git('config', '--get', 'user.name', allow_fail=True) or 'unknown')
    new.add_argument('--tool', default='unknown')
    check = sub.add_parser('validate', help='validate schema and update coverage')
    check.add_argument('--base', help='complete base commit; defaults to local task base')
    args = parser.parse_args()
    try:
        if args.command == 'new':
            print(new_record(args.slug, args.author, args.tool).relative_to(ROOT))
            print('Fill TODO fields, confirm previous_handoffs, and update PROJECT_STATE.md before committing.')
            return 0
        errors = validate(base=args.base if args.base is not None else choose_base(ROOT))
        if errors:
            for message in errors:
                print('ERROR:', message, file=sys.stderr)
            return 1
        print('Handoff protocol: PASS')
        return 0
    except (RuntimeError, ValueError, OSError) as exc:
        print('ERROR:', exc, file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
