# FireRed MP3

A standalone FireRed Recomp music-player mod, with the custom PULSE interface
and optional soundtrack mods. Current version: **2.2.1**.

## Features

- Buy the MP3 Player at the Celadon Department Store's Poke Doll / stone counter
  for $9,800. Only one can be purchased; it disappears from stock once owned.
- Browse cartridge albums, named songs and full-screen artwork.
- Crisp bitmap lettering and arrow-key tab navigation.
- Pause/resume, previous/next, shuffle, and repeat controls.
- Independent native game-music and sound-effect switches.
- Register the Key Item, then press SELECT for bottom-right mini controls,
  including during battles. Left/right chooses a button, A activates it,
  and SELECT/B closes it. Other registered items retain their normal shortcut.
- Closing the player keeps music playing.

## Build and install

Requires Python 3.9 or newer. The player build uses only the standard library:

```sh
python build.py
```

Import `dist/MP3Player-2.2.1.zip` in Recomp's mod manager, enable it and restart.
Disable the old bundled **MP3 Player - FireRed** (`mp3_player_firered`) first.
Existing `MP3_PLAYER` Key Items remain compatible. Updates replace the same
`mp3_player` mod; do not install a second copy.

This targets the tested FireRed API 2 engine and requires `engine_internals`
permission for item/shop hooks. See [controls and behavior](player/CONTROLS.md).

## Optional soundtrack packs

This repository contains pack definitions, **not soundtrack audio or ROMs**.
The standalone player works without packs and shows an empty collection.
Use an existing local MP3PlayerFireRed asset folder to build five separate packs:

```sh
python build.py --source "/path/to/MP3PlayerFireRed"
```

The local source must contain `music/<game-id>/*.ogg` and
`assets/icons/<game-id>.png` (Red Rescue Team uses `pmd_red_rescue_team.png`).
Import only the soundtrack ZIPs you want, enable them with the player and restart.

| Pack | Supplied recordings |
| --- | ---: |
| Sonic Advance 2 | 50 |
| Sonic Advance 3 | 77 |
| Pokemon Mystery Dungeon: Red Rescue Team | 76 |
| Kingdom Hearts: Chain of Memories | 46 |
| Pokemon Emerald | 187 |

`soundtracks.json` preserves the pack manifests and Lua libraries. Among the
436 original recordings, 423 have source-mapped names; 13 retain unresolved
or placeholder labels. The extraction included some sound effects. See
`title-audit.json` for the complete mapping. Source-symbol names are descriptive,
not necessarily official album titles.

Metadata sources: [Sonic Advance 2](https://github.com/SAT-R/sa2/blob/main/include/constants/sa2/songs.h),
[Sonic Advance 3](https://github.com/SAT-R/sa3/blob/main/include/constants/songs.h),
[Red Rescue Team](https://github.com/pret/pmd-red/blob/master/include/constants/bg_music.h),
[Emerald](https://github.com/pret/pokeemerald/blob/master/include/constants/songs.h),
and [Kingdom Hearts GSF tags](https://www.zophar.net/music/gameboy-advance-gsf/kingdom-hearts-chain-of-memories).
Downloaded reference archives are not included.

## Development and verification

Edit `player/` and rebuild. Pack authors can use the registration example in
[CONTROLS.md](player/CONTROLS.md). Audio settings are session-local. Native audio
timers keep running when muted; the MP3 stream retains its own playback state.

Native verification requires Windows, an extracted compatible Recomp engine,
LÖVE DLLs and the local FireRed cache; these are not bundled:

```sh
python build.py --source "/path/to/MP3PlayerFireRed"
python verify.py --engine "/path/to/inspection" --runtime "/path/to/love-runtime"
```

The native bootstrap expects `work/firered-cache/` and `tests/underground-native/`
beside `inspection/`, matching the original isolated engine fixture. Tests do
not load player saves. Coverage includes native shop transactions, quantity
limits, stock removal, inventory serialization, pack loading, audio controls,
arrow navigation, source muting and real field/wild-battle mini controls.
Full launcher installation and every combination of third-party mods remain
outside these checks.

Game names and artwork retain their respective owners' rights. This is an
unofficial fan project, not affiliated with Nintendo, The Pokemon Company,
Sega, Square Enix or Disney. No license grant for third-party assets is implied.
