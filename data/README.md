# data/

Content of Soldat's, copied here from
[opensoldat/base](https://github.com/opensoldat/base), the game's
content as its community publishes it: **CC BY 4.0**, by Transhuman
Design (Michał Marcinkowski) and the OpenSoldat contributors (its
`Credits.md` names those known). The files are as they are there,
unchanged.

| File | From | What |
|---|---|---|
| `maps/Arena2.pms` | `shared/maps/Arena2.pms` | "Soldat Arena Two - version 2.2", the map the game starts on, embedded in the program (`src/map/dune`) |
| `anims/*.poa` (44) | `shared/anims/` | the soldier's animations, those Soldat loads (`shared/Anims.pas`): packed into the program at build time (`src/anim/dune`) |
| `objects/gostek.po` | `shared/objects/gostek.po` | the soldier's skeleton: 24 points, 30 sticks |
| `gostek-gfx/*.png` (21) | `shared/gostek-gfx/` | the soldier's pictures, one a limb and its mirror: packed into the program at build time as their pixels (`src/render/dune`) |
| `weapons.ini` | `server/configs/weapons.ini` | the weapons' numbers (damage, fire interval, clip, reload, speed...): packed into the program at build time (`src/game/dune`), read when it starts |
| `bots/*.bot` (16) | `server/configs/bots/` | the bots' characters: a name, colours, a favourite weapon, how well it aims, how it fights: packed into the program at build time (`src/game/dune`) |
| `textures/objects/medikit.png`, `grenadekit.png` | `shared/textures/objects/` | the two kits lying on a map: read when the game runs |
| `sfx/*.wav` (82) | `shared/sfx/` | the sounds the game plays, of Soldat's 157 (`Soldat_sfx.files`): read when one is first played |
| `sparks-gfx/*.png` (10), `sparks-gfx/explosion/*.png` (26) | `shared/sparks-gfx/` | the sparks' pictures: smoke, blood, a chip, the jets' fire; an explosion's 16 and its smoke's 10 |
| `weapons-gfx/*-shell.png` (11) | `shared/weapons-gfx/` | each weapon's spent shell |
| `weapons-gfx/*.png` (50) | `shared/weapons-gfx/` | the eleven weapons in a soldier's hands, each with its mirror (`-2`), its clip (`-clip`, `-clip2`) and its muzzle's fire (`-fire`); a grenade and the M79's shell. Read when the game runs; the USSOCOM's two (`colt1911`, `colt1911-2`) are packed into the program too |
| `textures/poziomka.png` | `shared/textures/` | Arena2's texture: read when the game runs |
| `scenery-gfx/*` (13) | `shared/scenery-gfx/` | Arena2's scenery: barrels, crates, grass, roots, a net; three of them still `.bmp` |

The game looks for the pictures it does not carry (the weapons', the
textures, the scenery) under a *base*, `data/` by default: a checkout
of the whole of Soldat's content does as well (`base=`), with every
map's. The website has them as plain pixels (`docs/assets/`, made by
`make website`).

Everything else of mini-soldat is LGPL 2.1; this folder is not.
