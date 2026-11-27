"""Unpack ZIP files from photos-upload/ into assets/meals/.

Only pictures whose file name matches a dish in docs/dish-photos.md are kept.
Names are tidied (lower case, spaces/dashes become underscores, .jpeg becomes .jpg).
Writes a short report to the GitHub job summary.
"""
import os
import pathlib
import re
import zipfile

MAX_FILE_BYTES = 3 * 1024 * 1024
checklist = pathlib.Path('docs/dish-photos.md').read_text(encoding='utf-8')
allowed = set(re.findall(r'`([a-z0-9_]+)\.jpg`', checklist))
out_dir = pathlib.Path('assets/meals')
out_dir.mkdir(parents=True, exist_ok=True)

imported, unknown, too_big, bad_zips = [], [], [], []
zips = sorted(pathlib.Path('photos-upload').glob('*.zip'))
for zip_path in zips:
    try:
        archive = zipfile.ZipFile(zip_path)
    except zipfile.BadZipFile:
        bad_zips.append(zip_path.name)
        continue
    with archive:
        for info in archive.infolist():
            if info.is_dir():
                continue
            parts = info.filename.replace('\\', '/').split('/')
            base = parts[-1]
            if '__MACOSX' in parts or base.startswith('.'):
                continue
            stem, ext = os.path.splitext(base)
            ext = ext.lower()
            if ext not in ('.jpg', '.jpeg', '.png'):
                continue
            slug = re.sub(r'^_+|_+$', '', re.sub(r'[^a-z0-9]+', '_', stem.lower()))
            if slug not in allowed:
                unknown.append(info.filename)
                continue
            if info.file_size > MAX_FILE_BYTES:
                too_big.append(info.filename)
                continue
            target = out_dir / (slug + ('.png' if ext == '.png' else '.jpg'))
            target.write_bytes(archive.read(info))
            imported.append(target.name)
    zip_path.unlink()

present = {p.stem for p in out_dir.glob('*') if p.suffix in ('.jpg', '.png')}
lines = ['## Photo import', '',
         f'- ZIP files processed: {len(zips)}',
         f'- Photos imported: {len(imported)}',
         f'- Dishes with a photo now: {len(present & allowed)} of {len(allowed)}']
if unknown:
    lines += ['', 'Skipped (name does not match any dish in docs/dish-photos.md):'] + [f'- `{n}`' for n in unknown]
if too_big:
    lines += ['', 'Skipped (larger than 3 MB, please shrink):'] + [f'- `{n}`' for n in too_big]
if bad_zips:
    lines += ['', 'Not a valid ZIP file:'] + [f'- `{n}`' for n in bad_zips]
report = '\n'.join(lines) + '\n'
print(report)
summary = os.environ.get('GITHUB_STEP_SUMMARY')
if summary:
    with open(summary, 'a', encoding='utf-8') as handle:
        handle.write(report)
