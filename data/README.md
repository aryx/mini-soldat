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
| `weapons-gfx/colt1911.png`, `colt1911-2.png` | `shared/weapons-gfx/` | the USSOCOM in a soldier's hands, and its mirror |
| `textures/poziomka.png` | `shared/textures/` | Arena2's texture: read when the game runs |
| `scenery-gfx/*` (13) | `shared/scenery-gfx/` | Arena2's scenery: barrels, crates, grass, roots, a net; three of them still `.bmp` |

The game looks for the last two under a *base*, `data/` by default: a
checkout of the whole of Soldat's content does as well (`base=`), with
every map's. The website has them as plain pixels (`docs/assets/`,
made by `make website`).

Everything else of mini-soldat is LGPL 2.1; this folder is not.
