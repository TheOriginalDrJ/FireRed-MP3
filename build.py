"""Build FireRed MP3, optionally adding independently packaged local soundtracks."""
import argparse
import json
import shutil
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parent
ICONS={'pokemon_red_rescue_team':'pmd_red_rescue_team'}

def package(folder,version):
    target=ROOT/'dist'/f'{folder.name}-{version}.zip'
    target.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as archive:
        for file in sorted(folder.rglob('*')):
            if file.is_file(): archive.write(file,file.relative_to(folder.parent))
    with zipfile.ZipFile(target) as archive:
        assert archive.testzip() is None
    print(target)

def build(source=None):
    player=ROOT/'mods/MP3Player'
    shutil.copytree(ROOT/'player',player,dirs_exist_ok=True)
    version=json.loads((player/'manifest.json').read_text())['version']
    package(player,version)
    if source is None: return
    for pack in json.loads((ROOT/'soundtracks.json').read_text()):
        gid=pack['folder'].removeprefix('Soundtrack-')
        music=source/'music'/gid
        icon=source/'assets/icons'/(ICONS.get(gid,gid)+'.png')
        if not music.is_dir() or not icon.is_file():
            raise FileNotFoundError(f'Missing local audio/artwork for {gid}: {source}')
        folder=ROOT/'mods'/pack['folder']
        (folder/'assets').mkdir(parents=True,exist_ok=True)
        shutil.copy2(icon,folder/'assets/cartridge.png')
        shutil.copytree(music,folder/'music'/gid,dirs_exist_ok=True)
        (folder/'main.lua').write_text(pack['entry'],encoding='utf-8')
        (folder/'library.lua').write_text(pack['library'],encoding='utf-8')
        (folder/'manifest.json').write_text(json.dumps(pack['manifest'],indent=2))
        package(folder,pack['manifest']['version'])

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,help='Local original MP3PlayerFireRed directory, for optional soundtrack builds')
    build(parser.parse_args().source)
