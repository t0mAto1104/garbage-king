"""Self-contained macOS app using the locally installed official Godot runner.

This deliberately uses the existing editor binary to run a PCK, because this
machine has no macOS export template. It is not a standard template export.
"""
from pathlib import Path
import os
import plistlib
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]
GODOT=Path(os.environ.get('GODOT_APP',str(Path.home()/'Desktop/Godot.app'))).expanduser()
APP=ROOT/'build'/'macos'/'踩扁它！.app'
CONTENTS=APP/'Contents'
for part in ['MacOS','Resources']:
    (CONTENTS/part).mkdir(parents=True,exist_ok=True)
pack=CONTENTS/'Resources'/'game.pck'
subprocess.run([str(GODOT/'Contents/MacOS/Godot'),'--headless','--path',str(ROOT),'--export-pack','Windows Desktop',str(pack)],check=True)
shutil.copy2(GODOT/'Contents/MacOS/Godot',CONTENTS/'MacOS/CanStomperRuntime')
launcher=CONTENTS/'MacOS/CanStomper'
launcher.write_text('#!/bin/sh\nset -eu\nCONTENTS_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"\nexec "$CONTENTS_DIR/MacOS/CanStomperRuntime" --main-pack "$CONTENTS_DIR/Resources/game.pck" "$@"\n')
launcher.chmod(0o755)
info={
    'CFBundleExecutable':'CanStomper','CFBundleIdentifier':'local.canstomper.garage',
    'CFBundleName':'踩扁它！','CFBundleDisplayName':'踩扁它！',
    'CFBundleShortVersionString':'1.0','CFBundleVersion':'1',
    'CFBundlePackageType':'APPL','NSHighResolutionCapable':True,
    'NSRequiresAquaSystemAppearance':False,
    'LSApplicationCategoryType':'public.app-category.games',
    'NSHumanReadableCopyright':'Original game prototype. Godot Engine MIT license.',
}
with (CONTENTS/'Info.plist').open('wb') as f: plistlib.dump(info,f)
notice=ROOT/'THIRD_PARTY_NOTICES.md'
shutil.copy2(notice,CONTENTS/'Resources/THIRD_PARTY_NOTICES.md')
subprocess.run(['codesign','--force','--deep','--sign','-',str(APP)],check=True)
print('Created self-contained editor-runner app:',APP)
