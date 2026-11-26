#!/usr/bin/env python3
"""Source checks; optional actual Godot import and test runs."""
import argparse, pathlib, re, subprocess, sys, shutil, tempfile, uuid, xml.etree.ElementTree as ET, os
root=pathlib.Path(__file__).resolve().parents[1]
addon=root/'addons/pft_benchmark'
parser=argparse.ArgumentParser(); parser.add_argument('--godot'); parser.add_argument('--gui', action='store_true', help='run graphical smoke tests (display required)'); parser.add_argument('--renderer', choices=['gl_compatibility','mobile','forward_plus'], default='gl_compatibility'); args=parser.parse_args()
if args.gui and not args.godot: parser.error('--gui requires --godot')
errors=[]
def check(ok,msg):
    if not ok: errors.append(msg)
for p in root.rglob('*'):
    if '.godot' in p.parts or '.git' in p.parts: continue
    if p.suffix not in ('.gd','.tscn','.godot','.cfg'): continue
    s=p.read_text(encoding='utf-8')
    for path in re.findall(r'res://[^"\s]+',s):
        check((root/path[6:]).exists(), f'{p.name}: missing {path}')
    if p.suffix=='.gd':
        for alias in re.findall(r'^const (\w+) = preload\(',s,re.M):
            check(alias.startswith('FG'), f'{p.name}: unprefixed script alias {alias}')
        names=re.findall(r'^(?:static )?func (\w+)\(',s,re.M)
        check(len(names)==len(set(names)), f'{p.name}: duplicate method')
        check('PFT / BENCHMARK' not in s and 'FREE  0.5.0' not in s, f'{p.name}: old visible brand')
metric=(addon/'metric_config.gd').read_text(); runtime=(addon/'runtime.gd').read_text()
ids=set(re.findall(r'^\s*"(\w+)": \["[^"\n]+", "[^"\n]*", [012]\]',metric,re.M))
check(len(ids)==24,'expected 24 metric IDs')
visibility=runtime.split('_metric_nodes = {',1)[1].split('}',1)[0]
check(ids==set(re.findall(r'"(\w+)":',visibility)),'runtime metric mapping mismatch')
check(set(re.findall(r'_wanted\("(\w+)"\)',runtime))<=ids,'unknown metric')
check('name="FrameGauge Free"' in (addon/'plugin.cfg').read_text(),'plugin name')
check('version="0.8.0"' in (addon/'plugin.cfg').read_text(),'plugin version')
check('PFTBenchmark="*res://addons/pft_benchmark/runtime.gd"' in (root/'project.godot').read_text(),'autoload compatibility')
check('user://pft_benchmark_appearance.cfg' in runtime,'local config compatibility')
ET.parse(addon/'icon.svg')
if errors:
    print('\n'.join(errors)); sys.exit(1)
print('Source checks passed (NOT an engine parser).')
if args.godot:
    executable = pathlib.Path(args.godot).expanduser()
    godot = str(executable.resolve()) if executable.is_file() else shutil.which(args.godot)
    if not godot:
        sys.exit('Godot executable not found.')
    if os.name == 'nt' and not godot.lower().endswith('_console.exe'):
        console = pathlib.Path(godot).with_name(pathlib.Path(godot).stem + '_console.exe')
        if console.is_file(): godot = str(console)
    version = subprocess.run([godot, '--version'], capture_output=True, text=True, errors='replace', timeout=30)
    version_text = version.stdout.strip()
    print('Godot version: '+version_text, flush=True)
    if version.returncode or not re.match(r'^4\.7\.2(?:\.|$)', version_text):
        sys.exit('Release gate requires Godot 4.7.2; select its console executable on Windows.')
    # Tests may modify project and user settings. Never run against the user's actual project.
    with tempfile.TemporaryDirectory(prefix='framegauge-test-') as tmp:
        isolated = pathlib.Path(tmp) / 'project'
        shutil.copytree(root, isolated, ignore=shutil.ignore_patterns('.godot', '.git', '__pycache__'))
        project = isolated / 'project.godot'
        project.write_text(re.sub(r'^config/name=.*$', 'config/name="FrameGauge QA '+uuid.uuid4().hex+'"', project.read_text(encoding='utf-8'), flags=re.M), encoding='utf-8')
        def run(cmd, graphical=False):
            print('RUN: '+ ' '.join(cmd), flush=True)
            result=subprocess.run([godot, *([] if graphical else ['--headless']), '--path', str(isolated), *cmd], capture_output=True, text=True, errors='replace', timeout=180)
            output=result.stdout+'\n'+result.stderr
            print(output)
            if result.returncode or re.search(r'SCRIPT ERROR|Parse Error|Failed to load script|(?:^|\n)\s*ERROR:', output, re.I):
                sys.exit(1)
        run(['--editor','--import','--quit'])
        for p in sorted(isolated.rglob('*.gd')):
            if '.godot' in p.parts: continue
            run(['--check-only','--script','res://'+p.relative_to(isolated).as_posix()])
        for p in sorted((isolated/'tests').glob('test_*.gd')):
            run(['--script','res://tests/'+p.name])
        if args.gui:
            run(['--rendering-method',args.renderer,'--audio-driver','Dummy','res://tests/gui_runtime_smoke.tscn'], graphical=True)
            for scene in ['demo/main.tscn','demo/scene_3d.tscn']:
                run(['--rendering-method',args.renderer,'--audio-driver','Dummy','--quit-after','180','res://'+scene], graphical=True)
    print('Requested engine checks passed; manual interaction, export, and performance checks remain required.')
else:
    print('Godot tests not run (no --godot specified).')
