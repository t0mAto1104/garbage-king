"""Package the current Windows export using a narrow runtime-file allowlist."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import struct
import zipfile
import os
import sys

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build' / 'windows-v1.1'
if sys.platform == 'darwin':
    TEMPLATE_HOME = Path.home()/'Library/Application Support'
elif sys.platform == 'win32':
    TEMPLATE_HOME = Path(os.environ.get('APPDATA', str(Path.home()/'AppData/Roaming')))
else:
    TEMPLATE_HOME = Path(os.environ.get('XDG_DATA_HOME', str(Path.home()/'.local/share')))
TEMPLATES = TEMPLATE_HOME/'Godot/export_templates/4.7.2.stable'
if sys.platform not in ('darwin','win32'):
    TEMPLATES = TEMPLATE_HOME/'godot/export_templates/4.7.2.stable'
OUTPUT = ROOT/'build/releases/CanStomperDemo_v1.1_Windows_x64.zip'
EXE = BUILD / 'CanStomper.exe'

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024*1024), b''):
            h.update(block)
    return h.hexdigest()

def main():
    global BUILD, TEMPLATES, OUTPUT, EXE
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=Path, default=BUILD)
    parser.add_argument('--templates', type=Path, default=TEMPLATES)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    parser.add_argument('--template-receipt', type=Path, help='Optional official-template hash receipt')
    args = parser.parse_args()
    BUILD, TEMPLATES, OUTPUT = args.build, args.templates, args.output
    EXE = BUILD/'CanStomper.exe'
    if OUTPUT.exists():
        raise FileExistsError(f'Refusing to overwrite release: {OUTPUT}')
    raw = EXE.read_bytes()
    pe = struct.unpack_from('<I',raw,0x3c)[0]
    assert raw[:2] == b'MZ' and raw[pe:pe+4] == b'PE\0\0', 'Not a Windows PE executable'
    assert struct.unpack_from('<H',raw,pe+4)[0] == 0x8664, 'Not x86-64'
    assert raw[-4:] == b'GDPC', 'Embedded resource pack footer missing'
    size = struct.unpack_from('<Q',raw,len(raw)-12)[0]
    start = len(raw)-12-size
    assert raw[start:start+4] == b'GDPC', 'Embedded resource pack header missing'
    if args.template_receipt:
        receipt = json.loads(args.template_receipt.read_text())
        for name in ['windows_release_x86_64.exe','icudt_godot.dat']:
            record = next(x for x in receipt['files'] if x['name'] == name)
            assert digest(TEMPLATES/name) == record['sha256'], f'Template verification failed: {name}'
    shutil.copy2(TEMPLATES/'icudt_godot.dat',BUILD/'icudt_godot.dat')
    licenses = BUILD/'licenses'
    licenses.mkdir(exist_ok=True)
    shutil.copy2(ROOT/'GODOT_LICENSE.txt',licenses/'GODOT_LICENSE.txt')
    shutil.copy2(ROOT/'licenses/GODOT_COPYRIGHT.txt',licenses/'GODOT_COPYRIGHT.txt')
    shutil.copy2(ROOT/'THIRD_PARTY_NOTICES.md',licenses/'THIRD_PARTY_NOTICES.md')
    readme = '''踩扁它！ / Can Stomper — Demo v1.1

开始游戏
1. 右键 ZIP → 全部解压。
2. 打开解压后的 CanStomperDemo 文件夹。
3. 双击 CanStomper.exe。

无需安装 Godot、Python 或额外启动器。请保留同目录下的运行数据文件。
适用 Windows 10/11，64 位 Intel/AMD 电脑；显卡驱动需支持 OpenGL 3.3。

操作
鞋尖悬停罐子会连续踩踏，移开停止；点击共用冷却，不必连点。
空格踩悬停罐，未悬停时踩最早到达的可用罐；Esc 暂停/继续。
左侧购买升级。自动工坊首项升级供罐速度，初始每秒一罐，最快每秒四罐。
未踩扁的罐子会积累，位置和受损状态会自动保存。
右上角可以静音，玩法/暂停中可以减弱特效。左下角可确认重置试玩。

进度保存在当前 Windows 用户的应用数据目录，不需要管理员权限。
没有离线收益，ZIP 中没有开发者的个人存档。

打包脚本检查 EXE 结构和 ZIP 完整性；包内逻辑、贴图音频及 Windows 实机运行需另行验证。
内部试玩版未做发行签名。如遇问题，请反馈截图、Windows 版本和复现步骤。
引擎与组件许可见 licenses 文件夹。
'''
    (BUILD/'开始游戏.txt').write_text(readme,encoding='utf-8-sig')
    files = [EXE, BUILD/'icudt_godot.dat', BUILD/'开始游戏.txt', *sorted(licenses.iterdir())]
    manifest = {
        'game':'Can Stomper','version':'1.1','platform':'Windows x86-64',
        'engine':'4.7.2.stable.official.ed1daf0bf',
        'resource_pack':'embedded in CanStomper.exe','windows_runtime_verified':False,
        'verification':'PE x86-64 + embedded PCK header/footer + ZIP CRC and file hashes; runtime probes require a separate run',
        'files':[{'path':p.relative_to(BUILD).as_posix(),'bytes':p.stat().st_size,'sha256':digest(p)} for p in files],
    }
    manifest_path = BUILD/'build_manifest.json'
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    files.append(manifest_path)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(OUTPUT,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as bundle:
        for path in files:
            bundle.write(path,'CanStomperDemo/'+path.relative_to(BUILD).as_posix())
    with zipfile.ZipFile(OUTPUT) as bundle:
        assert bundle.testzip() is None, 'ZIP CRC verification failed'
        assert len(bundle.infolist()) == len(files), 'Unexpected file count'
        # Verify decompression against the exact packaged files.
        for path in files:
            restored = bundle.read('CanStomperDemo/'+path.relative_to(BUILD).as_posix())
            assert hashlib.sha256(restored).hexdigest() == digest(path)
    print(json.dumps({'zip':str(OUTPUT),'bytes':OUTPUT.stat().st_size,'sha256':digest(OUTPUT),'files':len(files)},ensure_ascii=False,indent=2))

if __name__ == '__main__':
    main()
