# PULSE MP3 Player 2.2.1

2.2.1 limits the MP3 Player to one per bag. Shop quantity is locked to one;
after purchase it disappears immediately from the stock list and stays hidden
on subsequent visits while owned, including existing saves. Cancelled or failed
purchases leave it available. Duplicate inventory additions are rejected.

2.2.0 uses arrow navigation in the full player. Left/right chooses a tab;
Down (or A) enters its content. Up from the first row returns to the tabs.
B goes back or returns focus to tabs; B on the tabs closes the player.
SELECT and R no longer switch full-player tabs. Registered SELECT still opens
the mini player.

Settings now include Game Music (native background music and fanfares) and
Game SFX (sound effects and cries). These switches do not change MP3 volume or
the game's saved volume options. Audio timing/callbacks continue while muted.
As with shuffle/repeat, these preferences last for the current app session.
While an MP3 track is playing or paused, native background music remains
suppressed; stop the MP3 to hear native music when Game Music is ON.

2.1.0 adds the bottom-right mini player. Register MP3 Player from Key Items,
then press SELECT during gameplay, including battles and menus. Owning the
item without registering it does not enable this shortcut. Other registered
items retain their normal SELECT behavior.

Left/right chooses previous, play/pause, or next; A activates it. SELECT, B,
or START closes the overlay while music continues. Gameplay input is captured
while the mini player is open; animations and ongoing game logic continue.
Release held controls when closing before resuming gameplay. Play resumes the
current queue, or starts the first installed nonempty album when no queue exists.
No soundtrack packs shows a clear empty state. The full library remains
available by using the Key Item normally.

2.0.2 removes linear smoothing from cartridge images and aligns their position
to the logical pixel grid in both preview and full-screen views. Original
artwork is preserved. Small label detail remains limited by the 240x160 game
canvas; use View full cartridge for the largest available image.

2.0.1 replaces smoothed text with opaque bitmap lettering, nearest-neighbor
glyph sampling and whole-pixel scrolling. Soundtrack packs do not need updates.

Standalone FireRed Recomp player. No music is bundled in this mod.

Disable the old **MP3 Player - FireRed** (`mp3_player_firered`) before enabling
this version. Import MP3Player-2.2.1.zip, then any of the five independent
Soundtrack ZIPs. Enable the player and your selected packs, then restart the
game. The loader checks each pack's dependency on MP3 Player >=2.0.0.

Your existing MP3_PLAYER Key Item remains compatible. Otherwise buy the player
for $9,800 at the Celadon Department Store's Poke Doll / stone counter. Use it
from Key Items.

- Left/right on tabs: switch tab; Down: enter content.
- Up/down in content: select; Up from first row: return to tabs.
- Left/right in an album song list: jump four rows.
- A: open album or play the selected song; B: back.
- SELECT: mini player when registered; no full-player tab shortcut.
- START: close, keeping playback active.
- Play album queues every song in that pack. View full cartridge opens a large
  artwork screen; A/B returns to the album.
- Now Playing provides pause/resume, previous, next, and Stop / restore game
  music. Settings provide shuffle and repeat playlist/single/off.

Song and album names scroll when selected if too long for their panel. Audio
streams from its owning soundtrack mod. Disable/uninstall packs in the mod
manager and restart to remove them from the collection. No player-save
migration is required; playback settings remain session-local.

Targets the supplied API 2 FireRed engine. Requires engine_internals for the
item/shop hooks. Cartridge artwork is displayed with its original proportions;
the display excludes near-transparent export noise without changing the PNG.

## Pack authors

Declare `"dependencies": ["mp3_player@>=2.0.0"]` and use:

```lua
local player = assert(mod.find('mp3_player'))
assert(player.exports.registerPack(mod, {
  id='my_soundtrack', name='My Soundtrack', icon='assets/cartridge.png',
  tracks={{id='opening', title='Opening', file='music/opening.ogg', duration=90}}
}))
```

Paths are relative to the soundtrack mod. IDs must be unique per pack.
Optional bounds={left,top,right,bottom} describe the visible artwork rectangle.
Use OGG for the tested streaming path. Keep audio and artwork inside the pack.
