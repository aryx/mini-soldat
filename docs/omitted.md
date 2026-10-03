# What is not here

mini-soldat aims at a tenth of the code it is adapted from, and
`make loc` says where it stands. A tenth of what, though, and for how
much of the game? This page is the other side of that number: what of
OpenSoldat mini-soldat does not have, so that the comparison can be
judged. Keep it true when a part is ported.

## The two numbers

| | lines |
|---|---|
| OpenSoldat's own Pascal (`shared/`, `client/`, `server/`; not `3rdparty/`) | 109,196 |
| mini-soldat's `src/` without its twins (`.ml` and `.mli`, comments and blank lines included) | 10,846 |
| of which its files' opening comments, not counted in the budget | 1,853 |
| **the budget's count** (`make loc`) | **8,993 of 10,000** |

But 109,196 is not all Soldat. More than half of it is not the game:

| what OpenSoldat's lines are | lines | here |
|---|---|---|
| bindings to libraries: Steam (15,462), OpenGL (20,772), FreeType, OpenAL, PhysFS, stb, an anti-cheat's client | 39,004 | none: elm-playground is the window, the drawing and the sound (it is not counted here either) |
| the server's scripting engine (`server/scriptcore/`: a Pascal interpreter and its API, for server owners' scripts) | 16,440 | none |
| **the game itself** | **53,752** | **10,846** |

So the honest comparison is 10,846 lines against 53,752, about a
fifth, not a tenth; or 8,993 against 53,752, 16%, with the budget's
count. And those lines do not do all that the 53,752 do: below.

## The game itself, part by part

| part | OpenSoldat | lines | mini-soldat | lines | what is not here |
|---|---|---|---|---|---|
| the mechanics: the soldier, bullets, things, weapons, animations, the map, the bots, a round's rules | `shared/mechanics/` (Sprites, Bullets, Things, Control, Sparks), `Weapons`, `Anims`, `AI`, `Waypoints`, `Game`, `PolyMap`, `MapFile`, `Parts`, `Calc`, `Vector`, `Constants` | 19,782 | `src/map`, `src/anim`, `src/game` (without its sound) | 5,987 | see the list below |
| the picture | `client/Gfx` (the OpenGL layer: 3,191), `GameRendering`, `MapGraphics`, `GostekGraphics`, `BinPack`, `WeatherEffects`, `gfx.inc` | 7,441 | `src/render` | 1,403 | the weather; the map's smoothed edges; the other team's own soldier pictures; hair, chains, headgear and the cigar; shredded clothes; a texture atlas (the Playground keeps the pictures) |
| the interface and the menus | `client/InterfaceGraphics`, `GameMenus`, `GameStrings` | 3,821 | a part of `Soldat_view` | about 200 | most of it. Here: the kill console, the scores as a table (Tab), the weapons' pictures in the menu, Soldat's cursor, the minimap (F3). Not here: Soldat's own gauges' pictures and its interface styles, the team menu, the escape menu, the vote and kick menus, the sniper line, translations |
| the sound | `client/Sound` | 615 | `Soldat_sound`, `Soldat_sfx` | 516 | 55 of Soldat's 163 sounds are named (100 files); the music; a bullet's whizz; the muffling after an explosion |
| the network | `shared/network/` | 8,681 | `src/net`, `src/online`, `src/server` | 1,743 | another design altogether (the server plays, WebSocket): no UDP, no deltas, no lag compensation, no spectators, no anti-cheat |
| the client's program | `client/Client`, `ControlGame`, `ClientGame`, `UpdateFrame`, `ClientCommands`, `Input`, `FileClient` | 3,983 | `src/main`, a part of `Soldat_update` | about 250 | key bindings and a config file, the console and its commands, screenshots, downloading a server's maps, the launcher |
| the server's program | `server/` without its scripting | 5,411 | a part of `src/server` | about 300 | admin over the network (rcon), bans, votes, the server's commands, a map list and its rotation, the lobby server it reports to, a file server |
| settings, commands, demos, logs | `shared/Cvar`, `Command`, `Demo`, `SharedConfig`, `LogFile`, `Console`, `Util`... | 4,018 | flags (`name=value`) | a few lines | every setting but a dozen flags; demos (a game recorded and played back); logs |

## Of the mechanics, what is not here

- **Modes**: Soldat's seven are here. Not here: a Pointmatch's points
  for several kills in a row; survival, realistic and advance modes;
  bullet time.
- **Weapons**: the stationary gun; the flame bow's fire; realistic
  mode's table of numbers. Bink and recoil (they move the cursor).
- **A soldier on fire** (what a flame or a flaming arrow does after
  the hit), and the flames' looks: a flame here is a disc.
- **The soldier**: the idle animations (the cigar, wiping, taking the
  helmet off...), the helmet shot off, the parachute, the mercy kill,
  the stock of a rifle used as a club, throwing a flag.
- **Things**: a thing hit by a bullet or thrown by an explosion; the
  parachute; the yellow flag.
- **Bots**: hiding behind a collider, the difficulty setting, the
  chat lines, favourite secondary weapons (they keep the USSOCOM).
- **Rounds**: respawning in waves, a vote for the next map, more than
  the two maps carried (any of Soldat's is read, given its file).
- **Chance** inside a tick is the round's seed's, where Soldat's is
  the machine's: a cluster grenade's five bits spread evenly, a wall's
  harm comes every tenth tick.

## What the rest would take

An estimate, mine and rough, of the OCaml each omitted part would take
written as the rest is (on the Playground, values instead of global
arrays): about a third of its Pascal, as the ported parts came out,
less where the Playground already does the work.

| omitted | estimate, lines of OCaml |
|---|---|
| the stationary gun, a soldier on fire, the flame bow's fire | 200 |
| the soldier's idle animations, the helmet shot off, the parachute, the mercy kill, the rifle's stock, throwing a flag | 200 |
| a thing hit by a bullet or an explosion; the bots' hiding, difficulty and chat; waves, the next map voted | 250 |
| the picture's rest: weather, smoothed edges, the other team's pictures, headgear and cigar, shredded clothes | 250 |
| the interface's rest and the menus (3,821 lines of Pascal; the kill console, the scores' table and the weapons' pictures are here) | 750 |
| the sound's rest: the 108 other sounds, a bullet's whizz, the muffling | 80 |
| the network's rest: only what changed, lag compensation, spectators, a connection found again | 500 |
| the client's program: key bindings, a config file, a console and its commands | 400 |
| the server's administration: rcon, bans, votes, commands, a map list | 600 |
| settings as named values, logs, demos (a round replays from its inputs: little) | 400 |
| the server's scripting engine | not estimated: 16,440 lines of Pascal for an interpreter; an OCaml server would be extended in OCaml |
| **all but the scripting** | **about 3,600** |

So the whole game, without the scripting and on elm-playground, would
be about 14,000 lines: a quarter of the 53,752 that are the game in
OpenSoldat, an eighth of its 109,196. The target of 10,000 is for what
is here; `docs/plan.md` says what may come next.

## What the tenth is, then

Counting only the parts mini-soldat has a real port of (the
mechanics, the picture without its OpenGL layer, the sound): 24,647
lines of Pascal against 7,906 here, a third. The rest of the ratio
is what is left out (the interface, the menus, the administration, the
settings, the scripting) and what elm-playground does in place of the
bindings.
