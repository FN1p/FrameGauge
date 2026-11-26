#!/usr/bin/env python3
"""Produce candidate ZIPs only. A source check is not release approval."""
from pathlib import Path
import argparse, hashlib, re, subprocess, sys, zipfile
root = Path(__file__).resolve().parents[1]
addon = root / 'addons/pft_benchmark'
version = re.search(r'^version="([^"\n]+)"', (addon/'plugin.cfg').read_text(), re.M).group(1)
parser = argparse.ArgumentParser()
parser.add_argument('--out', type=Path, default=root.parent/'dist')
args = parser.parse_args()
out = args.out.resolve()
if out == root or root in out.parents:
    sys.exit('Choose an output folder outside the project.')
out.mkdir(parents=True, exist_ok=True)
subprocess.run([sys.executable, str(root/'tools/validate.py')], check=True)
excluded = {'.godot', '.git', '__pycache__', 'dist'}
def include(p):
    return p.is_file() and not (set(p.relative_to(root).parts) & excluded) and p.suffix not in {'.log', '.tmp', '.pyc', '.zip'}
files = sorted(p for p in root.rglob('*') if include(p))
addon_files = [p for p in files if addon in p.parents]
def make(name, selected):
    dest = out/name
    with zipfile.ZipFile(dest, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for p in selected:
            info = zipfile.ZipInfo(p.relative_to(root).as_posix(), (2026, 11, 27, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            z.writestr(info, p.read_bytes(), compresslevel=9)
    with zipfile.ZipFile(dest) as z:
        assert z.testzip() is None
        assert set(z.namelist()) == {p.relative_to(root).as_posix() for p in selected}
        for p in selected: assert z.read(p.relative_to(root).as_posix()) == p.read_bytes()
    return dest
paths = [make(f'FrameGauge_{version}_Release_Candidate.zip', files), make(f'FrameGauge_{version}_addon.zip', addon_files)]
(out/f'FrameGauge_{version}_SHA256.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name+'\n' for p in paths))
for p in paths: print(f'{p.name}: {p.stat().st_size} bytes')
print('Candidate archives verified. Engine release gates still required.')
