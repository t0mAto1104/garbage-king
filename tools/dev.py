"""Cross-platform Godot entry point. Python 3.10+, standard library only."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def find_godot(explicit: str | None = None) -> Path:
    candidates = [explicit, os.environ.get('GODOT_BIN'), shutil.which('godot'), shutil.which('godot4')]
    if sys.platform == 'darwin':
        candidates += [str(Path.home()/'Desktop/Godot.app'), '/Applications/Godot.app']
    for candidate in candidates:
        if not candidate:
            continue
        path = Path(candidate).expanduser()
        if path.suffix == '.app':
            path = path/'Contents/MacOS/Godot'
        if path.is_file():
            return path.resolve()
        if explicit or os.environ.get('GODOT_BIN'):
            raise RuntimeError(f'Configured Godot executable does not exist: {path}')
    raise RuntimeError('Godot 4.7.2 Standard not found. Set GODOT_BIN or use --godot <path>. No software was installed.')


def checked(command: list[str]) -> None:
    print('RUN:', ' '.join(command), flush=True)
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=180)
    output = result.stdout + result.stderr
    print(output, end='' if output.endswith('\n') else '\n', flush=True)
    if result.returncode or 'SCRIPT ERROR:' in output or '\nERROR:' in output:
        raise RuntimeError(f'Check failed: {command[-1]} (exit {result.returncode})')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', help='Godot executable or a macOS Godot.app')
    parser.add_argument('command', choices=['run', 'test'])
    args = parser.parse_args()
    try:
        godot = str(find_godot(args.godot))
        version = subprocess.run([godot, '--version'], capture_output=True, text=True, check=True).stdout.strip()
        if not version.startswith('4.7.2.'):
            raise RuntimeError(f'Project requires Godot 4.7.2 Standard; found {version}')
        if args.command == 'run':
            return subprocess.call([godot, '--path', str(ROOT)], cwd=ROOT)
        checked([godot, '--headless', '--path', str(ROOT), '--editor', '--quit'])
        for name in ['test_core.gd', 'test_feed.gd', 'test_scene.gd', 'test_progression.gd']:
            checked([godot, '--headless', '--path', str(ROOT), '--script', 'tests/'+name, '--', '--test-mode'])
        checked([sys.executable, '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_handoff_protocol.py', '-v'])
        checked([sys.executable, 'tools/test_balance.py'])
        print('Local tests: PASS (does not constitute Windows hardware or human playtesting)')
        return 0
    except (RuntimeError, OSError, subprocess.SubprocessError) as exc:
        print('ERROR:', exc, file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
