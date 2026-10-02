# Soldat's own sources and assets

mini-soldat is to become a real Soldat: its maps, its textures, its
soldier, its weapons, its feel. Both halves of the original are public
and are the reference to work from. They are not in this repository;
on the author's machine they are checked out at:

| What | Where | Upstream | License |
|---|---|---|---|
| the program (Free Pascal, about 67,000 lines of its own) | `~/work/GAMES/opensoldat` | https://github.com/opensoldat/opensoldat | MIT (Transhuman Design 2001-2020, OpenSoldat contributors) |
| the game's content (229 MB) | `~/work/GAMES/opensoldat-base` | https://github.com/opensoldat/base | CC BY 4.0 (see its `Credits.md`) |

mini-soldat itself is LGPL 2.1. Code written here after reading the
MIT sources keeps their copyright notice where it is a port; content
copied here from `base` keeps its attribution.

## The content (`opensoldat-base/shared/`)

So yes, the assets are there:

| Folder | Files | What |
|---|---|---|
| `maps/` | 99 `.pms` | the maps: polygons, scenery, spawn points, waypoints |
| `textures/` | 57 `.png`, 32 `.bmp` | what a map's polygons are filled with (and `edges/`) |
| `scenery-gfx/` | 389 `.png`, 58 `.bmp` | the props a map places: trees, crates, bushes |
| `gostek-gfx/` | 124 `.png` | the soldier, a sprite per limb (and `team2/`, `ranny/`: wounded) |
| `weapons-gfx/` | 105 `.png` | the guns held, their bullets and shells |
| `sparks-gfx/` | 72 `.png` | smoke, blood, `explosion/`, `flames/` |
| `interface-gfx/` | 50 `.png` | the bars, the cursor, the guns' menu |
| `objects/` | 6 `.po` | skeletons, points and sticks: `gostek.po` the soldier, `flag.po`, `kit.po`, `para.po` |
| `anims/` | 51 `.poa` | the soldier's poses frame by frame: `biega` (runs), `stoi` (stands), `skok` (jumps), `celuje` (aims)... the names are Polish |
| `sfx/` | 164 `.wav` | shots, steps, explosions, the radio |
| `txt/` | | weapons' names, the translations |

and beside `shared/`: `server/configs/weapons.ini` (each weapon's
numbers: damage, speed, fire interval, ammo, reload time;
`weapons_realistic.ini` its realistic mode), `server/configs/bots/`
(16 `.bot`, a character each: accuracy, favourite weapon, how often it
throws a grenade, what it says), `client/configs/` (the keys).

## The program, and where each part lands here

Soldat's sources are in three folders: `shared/` (the game: what the
client and the server both run), `client/` (the window, the drawing,
the sound, the menus) and `server/` (the dedicated server, its
scripting). 60 ticks a second (`Constants.pas`'s `DEFAULT_GOALTICKS`).

| Here | Soldat | What it is there |
|---|---|---|
| `src/map/Pms` | `shared/MapFile.pas` | a `.pms` read (`TMapFile`, `LoadMapFile`), field for field |
| `src/map/Soldat_map` | `shared/PolyMap.pas`, `client/MapGraphics.pas` | its polygons in sectors, a point or a ray tested against them, which kind stops what (`TPolyMap`); the map as vertices to draw |
| `src/anim/Poa`, `Soldat_anims` | `shared/Anims.pas`, `shared/Parts.pas` | the animations' and the skeletons' files read (`TAnimation.LoadFromFile`, `LoadPOObject`); the 44 animations, their speeds and loops (`LoadAnimObjects`), a frame advanced (`DoAnimation`) |
| `src/game/Soldat_weapons` | `shared/Weapons.pas`, `server/configs/weapons.ini` | the weapons' table (`TGun`, `CreateWeapons`), the file read over it (`LoadWeapons`) |
| `src/game/Soldat_soldier` | `shared/mechanics/Sprites.pas`, `shared/mechanics/Control.pas`, `shared/Parts.pas` | a soldier's tick (`TSprite.Update`): its particle's step (`Euler`), its keys (`ControlSprite`), its skeleton placed, its collision with the map (`CheckMapCollision`, `CheckRadiusMapCollision`, `CheckMapVerticesCollision`); its weapon: `TSprite.Fire`, `ThrowGrenade`, the reload |
| `src/game/Soldat_ragdoll` | `shared/Parts.pas`, `shared/mechanics/Sprites.pas` | a dead soldier's skeleton: Verlet and constraints (`ParticleSystem`), `CheckSkeletonMapCollision`; the constraints a death cuts (`TSprite.Die`) |
| `src/game/Soldat_bullets` | `shared/mechanics/Bullets.pas`, `shared/mechanics/Sprites.pas` | a bullet (`TBullet.Update`: its way against the map, the colliders and the soldiers; `ExplosionHit`); a hit (`TSprite.HealthHit`, `Die`) |
| `src/game/Soldat_engine_bot` | nothing | one bot on elm-playground's `Sense` and `Bot` (the flag `ai=engine`): an example of that library, beside Soldat's |
| `src/game/Soldat_model` | `shared/mechanics/Sprites.pas`, `shared/Game.pas` | a soldier (`TSprite`), what it wants to do (`TControl`); the round |
| `src/game/Soldat_things` | `shared/mechanics/Things.pas` | what lies on the map (`TThing`): a weapon let go of, the kits; their fall, where they appear, who is in reach |
| `src/game/Soldat_bots` | `shared/AI.pas`, `shared/Waypoints.pas`, `shared/SharedConfig.pas`; `server/configs/bots/` | the bots (`ControlBot`, `SimpleDecision`, `GoToThing`), along the map's waypoints; a bot's file read (`LoadBotConfig`) |
| `src/game/Soldat_update` | `client/UpdateFrame.pas`, `server/ServerLoop.pas`, `shared/Game.pas` | a tick's order; what the special polygons do (`HandleSpecialPolyTypes`); a thing picked up; the respawn; the kill and time limits |
| `src/render/Soldat_gostek` | `client/GostekGraphics.pas`, `GostekGraphics.inc` | the soldier drawn: the table of its parts, each a picture between two points of the skeleton (`RenderGostek`, `DrawGostekSprite`) |
| `src/render/Soldat_scene`, `Soldat_raster` | `client/MapGraphics.pas`, `client/Gfx.pas` | the map drawn: its textured polygons, its props in three layers (there by OpenGL each frame; here once, into tiles) |
| `src/assets/Soldat_assets`, `Bmp` | `client/Gfx.pas` (stb_image), PhysFS | the content's files got and decoded |
| `src/render/Soldat_view` | `client/GameRendering.pas`, `InterfaceGraphics.pas` | the frame drawn, in its order: the map, the soldiers, the interface |
| `src/main/MiniSoldat` | `client/Client.pas` | the program |
| `src/net/Soldat_protocol` | `shared/network/Net.pas` | the messages, each a packed record opening with its number (`MsgID_*`) |
| `src/server/Soldat_lobby`, `Soldat_server`, `main/MiniSoldatServer` | `server/Server.pas`, `ServerLoop.pas`, `Main.pas`; `server/LobbyClient.pas` | the dedicated server, one game each; the list of servers is another program's, which each server registers with |
| nothing yet | `shared/mechanics/Sparks.pas`, `client/Sound.pas`, `shared/network/Network*.pas`, `shared/Demo.pas`, `server/scriptcore/` | the sparks, the sound, the game's own messages (sprites, bullets, things), the demos, the server's scripting |

Each module's opening comment says the same for itself.
