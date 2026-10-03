# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A clone of Soldat (Michał Marcinkowski, 2002) written from scratch in
OCaml, forked from
[elm-playground](https://github.com/aryx/ocaml-elm-playground)'s
TinySoldat (`~/playground/games/arcade/TinySoldat.ml`), as mini-chrome
(`~/github/mini-chrome`) was from its TinyChrome. It stands on
elm-playground's opam packages (0.3.5+): `elm_playground` (the
Elm-architecture runtime, window, drawing, and the `Physics` layer) and
`tiny_libs` (`physics_2d`, `ai`, `networking`). The only C is SDL (and
Cairo, optionally).

Four programs: `mini-soldat` and `mini-soldat-software` on the desktop,
the same game in a browser (js_of_ocaml, the website's), and
`mini-soldat-server`, where players meet to play over the network
(a lobby, and rooms whose rounds the server plays: `docs/network.md`
says what is there and what is to come; keep it true).

The goal is the real game: its maps, textures, soldier, weapons,
gameplay and feel. Soldat's sources and content are public and are the
reference, checked out outside this repository:

- `~/work/GAMES/opensoldat`: the program, Free Pascal, MIT
- `~/work/GAMES/opensoldat-base`: the content (maps, textures, the
  soldier's sprites and animations, sounds, the weapons' numbers),
  CC BY 4.0

`docs/architecture.md` is the program's shape: its libraries, a tick, a
frame from the game's values to the screen's pixels on each backend,
and what each layer keeps from a frame to the next. Keep it true when
a layer changes.

`docs/opensoldat.md` says what is in them and which of Soldat's files
each module here stands for; each module's opening comment says it too
("In Soldat: ..."). Read the Pascal before writing a part, and keep
both true when a module is added or changes role.

## The approach

Yoann's direction (2026-10-02), to follow in every part:

- **Adapt Soldat's Pascal to OCaml and to the Playground's API**: a
  part is written from its Pascal (the constants, the order things are
  done in, the corner cases), not reinvented. In far less code: OCaml,
  values instead of global arrays, and the Playground doing the
  drawing, the window, the sound and the network.
- **The same game feel**: the keys, the movements, the animations, the
  weapons' numbers as in Soldat. When in doubt, Soldat's numbers
  (`shared/Constants.pas`, `weapons.ini`), at its 60 ticks a second.
- **The physics is elm-playground's** (`~/playground/libs/physics/`,
  `tiny_libs.physics_2d`), Soldat's logic encoded on it and on the
  Playground's `Physics` layer. Soldat's own physics is a small Verlet
  particle system with stick constraints (`shared/Parts.pas`: a
  soldier is one particle that moves, in `SpriteParts`, and a skeleton
  of particles and sticks, `GostekSkeleton`, for its body), which is
  what `Particles` is (`step`, `relax`, `keep_out`).
- **elm-playground itself may be changed if really needed** (a
  textured triangle, a missing primitive): there, in `~/playground`,
  then `make install` and a later version required here. Not before
  trying with what it has.

`docs/notes_soldat_in_playground.md` is the dictionary between the two
(Soldat's words, its physics' formulas next to `Particles`', each
function of its map next to `Collide`'s, the soldier, the weapons, the
frame, the sound, and what the Playground lacks): read it before
porting a part, and when a part is ported move its rows from *to
come* to the module that has them. `docs/plan.md` is the order of the
steps and the rules they follow (Soldat's units, a pure `src/game`
taking one `intent` per soldier, no `Random` in a tick, the server's
branches of the Pascal for the rules): a step done is moved to its
"Done".

Ported so far (`docs/plan.md`'s "Done"): the maps (`Pms`,
`Soldat_map`), the soldier's moves (`Soldat_soldier`), its animations
(`Soldat_anims`), its look (`Soldat_gostek`), the map's look
(`Soldat_scene`, `Soldat_raster`), the weapons (`Soldat_weapons`, the
guns in `Soldat_soldier`, `Soldat_bullets`, the cuts of
`Soldat_ragdoll`), the things (`Soldat_things`), Soldat's bots
(`Soldat_bots`), a round's rules (`Soldat_update`: a deathmatch, a
team match, capture the flag, with the flags of `Soldat_things`, a
Rambomatch, with the bow), the sparks
(`Soldat_sparks`, `Soldat_sparks_view`) and the sounds (`Soldat_sfx`,
`Soldat_sound`). Of
TinySoldat one thing is kept, on purpose: `Soldat_engine_bot`, a bot on
elm-playground's `Sense` and `Bot` (the flag `ai=engine` puts it in a
round in place of the last of Soldat's), as an example of that library
next to a bot written Soldat's way. It is not a port: keep it small,
its mind reading its senses and nothing else.

How a port is written here, as `Soldat_soldier.ml` is:

- its header says what it is adapted from and keeps OpenSoldat's
  notice (the MIT License: `LICENSE-OpenSoldat.md`);
- it follows the Pascal's order and says where each part comes from
  (`S:2623`: `Sprites.pas`, line 2623 of the checkout), so that the
  two can be read side by side; the constants keep the Pascal's names,
  in small letters (`runspeed`, `slidelimit`);
- the game's coordinates are Soldat's, y downwards: its signs are kept
  (`fy <- -.jumpspeed` is a force upwards). Only `Soldat_view.at` and
  `Soldat_update.human` turn y over;
- animations' frames and skeletons' points are numbered from 1, as in
  the Pascal, which names them all along (`s.legs.frame > 8`,
  `Soldat_soldier.point s 12` the head);
- a soldier's record has mutable fields, written by `tick` alone, on a
  copy: the Pascal changes `Sprite[i]` in place a hundred times a tick
  and is ported as such; from outside a tick is a function;
- the `{$IFDEF SERVER}` branches are the rules, the client's what is
  seen; what is left out (the network, the sparks, the sounds, the
  idle animations...) is said in the `.mli`;
- its numbers are checked by tests worked out by hand from the
  Pascal's formulas (`tests/game/Unit_soldier.ml`, `Unit_weapons.ml`),
  on a map made by hand (`Testutil_map`). When a test and the hand
  disagree, read the Pascal and the data again before touching either:
  step 4's four disagreements were all the hand's (the Barrett's
  modifiers are 1; a standing soldier is held against the shotgun's
  kick; a grenade is found in a wall the tick after; an explosion
  cuts limbs only within 1.7 units);
- a sound or a spark is never made in a rule: where the Pascal calls
  `PlaySound` or `CreateSpark` (its `{$IFNDEF SERVER}` lines), the port
  emits a `Soldat_event.t` (`Soldat_soldier.emit`, `Soldat_bullets.emit`,
  a `?heard` list for the things and the dead), and `Soldat_update.tick`
  turns the tick's events into sparks (`Soldat_sparks.of_event`, with
  the sparks' own seed, never the game's) and sounds (`play.sounds`).
  `Soldat_sound.play`, called by `update` after the tick, is the only
  line that does something; a new sound is a case of `Soldat_sfx.t`
  and its file copied to `data/sfx/` (`scripts/perf/Sfx_files.exe`
  lists them; a test checks each is there);
- chance is a function given (`~random`), drawn from the round's seed
  (`Soldat_model.play.seed`, `Lehmer`): never `Random`. A test gives
  `fun () -> 0.5`, which is no scatter at all.

Content the program carries is packed at build time by a small
program of its own (`src/anim/Gen_anims`, `src/render/Gen_pictures`,
each run by a dune rule over files of `data/`): the animations as
singles, the pictures as pixels, in base64. A picture is drawn with
the Playground's `bitmap`, which neither tints nor mirrors: the one
wanted is made once (`Soldat_gostek.picture`) and the very same value
given each time, since a backend knows a picture by itself
(`docs/architecture.md`). What is not always needed is a file instead,
asked through `Soldat_assets` when it is drawn and not drawn until it
has come: a map's texture and scenery, the weapons' pictures
(`data/weapons-gfx/`; only the pistol's are packed).

## Commands

```bash
./configure            # opam deps; checks SDL2 and Cairo (--software: no Cairo)
make                   # dune build @default (the web program's page too)
make test              # dune runtest -f, the six suites
make loc               # lines of OCaml, and the budget's (loc-v: a library a line)
make run               # dune exec mini-soldat
make run-software      # dune exec mini-soldat-software
make serve             # the game in a browser, http://localhost:8001/
make website           # the release .bc.js, its page, its content (docs/assets/)
make serve-website     # docs/ as Github Pages will serve it, http://localhost:8000/
./bin/mini-soldat-server port=23073 bind=127.0.0.1 capacity=32
make build-docker      # what CI runs (OCaml 4.14.4; build-docker-ocaml5 for 5.5.1)
```

One suite, or one test (Testo; each `tests/<suite>/Test.ml` is its own
runner; the suites are `map`, `anim`, `assets`, `game`, `render` and
`server`):

```bash
dune build @tests/game/runtest --force
dune exec tests/game/Test.exe -- run -s Bots     # tests whose name contains it
```

Program flags are words, `name` or `name=value`
(`./bin/mini-soldat hitboxes bots=5`), read from `computer.flags`:
`hitboxes` (draw the points the game tests), `sticks` (the skeletons
over the soldiers), `waypoints` (the map's, the bots' paths, with the
keys each says to hold), and, read by the main before the game starts:
`server=HOST[:PORT]`, `nick=NAME`, `room=NAME` (the round is a
`mini-soldat-server`'s: `Soldat_online`, `docs/network.md`; without
`room=`, the lobby's screen),
`secondary=knife|saw|law`, `bonus=N` (bonus kits appear, 1 seldom
to 5 often; none without it, as in Soldat),
`mode=dm|pm|tdm|ctf|rm|inf|htf` (`Soldat_model.mode_words`; the map's own without it: capture the flag where
the map has the two flags' places), `bots=N` (how many to play with
and against: 3), `ai=engine` (the last of
them the bot on `Sense` and `Bot`), `mute` (no sound), `sparks=N` (at
most N sparks: 558, or 150 in a browser),
`map=FILE` (a `.pms`; `~/` understood), `map=NAME` (`maps/NAME.pms`
under the base, got as any content: a `Loading` scene until it comes),
nothing: Arena2, carried in the program (`data/maps/Arena2.pms` as
base64, `src/map/dune`'s rule); `base=DIR` where the content is
(`data` natively, `assets` beside the page in a browser;
`base=~/work/GAMES/opensoldat-base/shared` has every map's);
`weapon=N` (the weapon to appear with, by its key in Soldat's menu: 1
the Desert Eagles ... 9 the Minimi, 0 the minigun);
`graphics=N` (1 to 3: `Soldat_model.graphics_name`; the key `g` goes
round them).

The content got while the game runs (`Soldat_assets`: a map's texture
and scenery, a map by its name) comes at once natively and later in a
browser: nothing may wait for it. One asks each frame and has it or
not (`Loading`, `Missing`, `Here`); until then the map is drawn in
flat colours. This, the tiles drawn of it (`Soldat_scene`), the
pictures tinted once (`Soldat_gostek`, `Soldat_sparks_view`) and the
recordings read (`Soldat_sound`) are the only memories outside the
model, and no rule of the game reads them.
In a browser a picture is fetched as plain pixels (`name.rgba`, made
by `Gen_assets` at `make website`), never as PNG: elm-playground's
`Png.decode` is quadratic there.

The keys are Soldat's: a/d, w (jump), s (crouch), x (prone), the left
button (fire), the right one or shift (jets), r, q, e, f, 1 to 0, and
c (the second weapon: USSOCOM, knife, chainsaw, LAW), Tab or b (the
scores as a table);
space starts a round, m on the title asks for the next map
(`Soldat_model.maps`: those whose content is in `data/`). In
a `-script`, `d:10-70` holds d, `at(300;120):3-200` puts the mouse
there (the screen's units, from its middle, y upwards) and `click:60-90`
holds its button; without an `at` the mouse is at the screen's middle
and the soldier aims at itself. The camera leans a mouse's offset
towards it: with the mouse at (mx, my), the player is drawn near
(500 - mx, 500 + my) of a dumped 1000 by 1000 frame.

`dune exec scripts/perf/Frame_bench.exe -- ~/work/GAMES/opensoldat-base/shared/maps/*.pms`
reads every map of Soldat's, plays 300 ticks on each and prints a
tick's time: the check that a change to `Pms`, `Soldat_map` or the
soldier still takes them all (a few seconds; 0.01 to 0.1 ms a tick).

The Playground's own flags start with a dash, and make a change
checkable without a screen: `-dump-frame n file.png` writes the nth
frame and exits, `-script "space:2,d:10-70,w:30"` presses keys at
frames (space at frame 2, d held from 10 to 70), `-size WxH` sets the
window's size. With SDL's dummy drivers, no display is needed:

```bash
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
  ./bin/mini-soldat-software -dump-frame 260 /tmp/bots.png -script "space:2"
```

The file comes right after `-dump-frame n`. The software platform's
frame is the same on every machine (Cairo's is not, to the pixel), so
it is the one to compare.

The web program is checked in a real browser, headless:
`google-chrome --headless=new --screenshot=out.png --window-size=1000,1000
--virtual-time-budget=3000 file://$PWD/_build/default/src/main/web/index.html`
for a frame, and elm-playground's `scripts/web/chrome_cdp.js` to press
keys and read the page's console and frame rate (its keys are
separated by spaces, so it cannot press space as it is: a copy
splitting on commas was used). In a browser the flags come from the
URL (`?hitboxes&bots=5`), and whatever the game prints goes to the
console.

## The website

`docs/` is the site Github Pages serves ("Deploy from a branch",
`/docs`; `.nojekyll`: the files as they are). `docs/index.html` is
written by hand: what the game is, how to play, the notice that the
code is generated by an AI, the credits to Soldat's author; keep the
last two, they are wanted, as in `README.md`. `docs/play.html`,
`docs/MiniSoldat.bc.js` and `docs/assets/` are made by `make website`
(the page from `src/main/web/index.html`; the program built with
dune's release profile, 660 KB against 4 MB in dev; the content of
`data/` the game fetches, its pictures as plain pixels) and are
committed: run it and commit them when the game or its content changed
and the site should show it. To time a page in a real browser, the
frames and the pictures encoded each second: `node
scripts/perf/web_probe.js URL SECONDS` (a headless Chrome over its
DevTools protocol; it presses space and holds d). Kill what it leaves
with `pkill -f "[g]oogle-chrome.*headless"`: a leftover Chrome keeps a
connection to the local server and the next run hangs.

## Layout

`README.md` has it: `src/map` (the map), `src/anim` (the animations),
`src/assets` (the content's files), `src/game` (the game without its
picture), `src/render` (the picture: `Soldat_view`, `Soldat_gostek`
the soldier's, `Soldat_scene` and `Soldat_raster` the map's),
`src/main` (the program, and
`software/` and `web/` the same source on the software platform and in
a browser), `src/net` (the protocol), `src/server` (the lobby, the
server, and `main/` its program), each folder a library (`(wrapped
false)`, modules named `Soldat_*`), in the order they depend on each
other. The game is a Model-View-Update program: `Soldat_model.model`,
`Soldat_update.update`, `Soldat_view.view`. `Soldat_update.tick` is
the game's step and knows neither keyboard nor screen: it takes the
player's `intent` and where it looks; `update` reads those from the
Playground's `computer` and calls it. A round replays the same from
the same intents (a test says so): nothing in a tick is random.

What the browser's program links must be pure OCaml (no `unix`):
`src/map`, `src/anim`, `src/game`, `src/render`, `src/net` and
`src/online` are, and must stay
so; `src/server` is not and is never linked by the game. The server's
rule is a value too (`Soldat_lobby.receive`: a message in, the lobby
and the messages to send out), the sockets only in `Soldat_server`, so
it is tested by calling it. Anything read from the network goes
through `Soldat_protocol`'s decoders, which refuse what does not parse
(the server then closes that connection); a new message gets its bytes
in the `.mli`'s worked example and in `tests/server/Unit_protocol.ml`.
The server listens on 127.0.0.1 unless told otherwise.

Working on elm-playground at the same time: `make && make install`
there (in `~/playground`), then build here.

## The budget

`src/` is to stay near 10,000 lines, a tenth of OpenSoldat's Pascal
(Yoann, 2026-10-03): `make loc` says where it stands
(`scripts/stats/loc.py`, mini-chrome's). Not a hard limit: clear code
comes first. A file's opening comments (the notice, what the module
is, its worked example, where it comes from) are not counted, so that
a cap is never a reason to teach less; nor are the tests.
`docs/omitted.md` is the other side of the number: what of OpenSoldat
is not here, and what it would take. Keep it true when a part is
ported or left out.

## Conventions

- Comments are plain, without the `claude:` prefix: the whole project
  is written by Claude Code (as in mini-chrome).
- A new file starts with the "Claude Code / Copyright (C) 2026 Yoann
  Padioleau" LGPL header, as the others.
- `changes.txt` (org-mode) gets a line for each feature or change of
  infrastructure, under the version being worked on.
- Tests are Testo's, with Alcotest's checks; a suite is
  `tests/<suite>/` with `Test.ml`, `Unit_*.ml` and their `.mli`.
- A new module has an `.mli` whose opening comment teaches: what it
  is, a worked example, where it comes from (the people, the dates, the
  RFCs, only what is certain), and what it is in Soldat's sources
  (`Soldat_protocol.mli`, `Soldat_lobby.mli`). The modules copied from
  TinySoldat have none yet: they are to be rewritten.
- No content of `opensoldat-base` is copied here without its
  attribution (CC BY 4.0, its `Credits.md`): it goes in `data/`, with
  a line in `data/README.md`. A port of Soldat's Pascal says so and
  keeps the MIT notice.
