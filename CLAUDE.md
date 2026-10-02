# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A clone of Soldat (Michał Marcinkowski, 2002) written from scratch in
OCaml, forked from
[elm-playground](https://github.com/aryx/ocaml-elm-playground)'s
TinySoldat (`~/playground/games/arcade/TinySoldat.ml`), as mini-chrome
(`~/github/mini-chrome`) was from its TinyChrome. It stands on
elm-playground's opam packages (0.3.3+): `elm_playground` (the
Elm-architecture runtime, window, drawing, and the `Physics` layer) and
`tiny_libs` (`physics_2d`, `ai`, `networking`). The only C is SDL (and
Cairo, optionally).

Four programs: `mini-soldat` and `mini-soldat-software` on the desktop,
the same game in a browser (js_of_ocaml, the website's), and
`mini-soldat-server`, where players are to meet to play over the
network (a lobby with rooms for now: `docs/network.md` says what is
there and what is to come; keep it true).

The goal is the real game: its maps, textures, soldier, weapons,
gameplay and feel. Soldat's sources and content are public and are the
reference, checked out outside this repository:

- `~/work/GAMES/opensoldat`: the program, Free Pascal, MIT
- `~/work/GAMES/opensoldat-base`: the content (maps, textures, the
  soldier's sprites and animations, sounds, the weapons' numbers),
  CC BY 4.0

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
(`Soldat_anims`). Still TinySoldat's and so to be replaced by a port:
the gun (one, with the USSOCOM's numbers), the bots, the drawing (a
stick figure, flat polygons).

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
  Pascal's formulas (`tests/game/Unit_soldier.ml`), on a map made by
  hand (`Testutil_map`).

## Commands

```bash
./configure            # opam deps; checks SDL2 and Cairo (--software: no Cairo)
make                   # dune build @default (the web program's page too)
make test              # dune runtest -f, the four suites
make run               # dune exec mini-soldat
make run-software      # dune exec mini-soldat-software
make serve             # the game in a browser, http://localhost:8001/
make website           # the release .bc.js and its page copied to docs/
make serve-website     # docs/ as Github Pages will serve it, http://localhost:8000/
./bin/mini-soldat-server port=23073 bind=127.0.0.1 capacity=32
make build-docker      # what CI runs (OCaml 4.14.4; build-docker-ocaml5 for 5.5.1)
```

One suite, or one test (Testo; each `tests/<suite>/Test.ml` is its own
runner; the suites are `map`, `anim`, `game` and `server`):

```bash
dune build @tests/game/runtest --force
dune exec tests/game/Test.exe -- run -s engine   # tests whose name contains it
```

Program flags are words, `name` or `name=value`
(`./bin/mini-soldat hitboxes ai=engine`), read from `computer.flags`:
`hitboxes` (draw the points the game tests), `ai=engine` (the bots on
`Sense` and `Bot`), and, read by the main before the game starts,
`map=FILE` (a `.pms`; `~/` understood), nothing: Arena2, carried in
the program (`data/maps/Arena2.pms` as base64, `src/map/dune`'s rule).

The keys are Soldat's: a/d, w (jump), s (crouch), x (prone), the left
button (fire), the right one or shift (jets); space starts a round. In
a `-script`, `d:10-70` holds d; the mouse stays at the screen's middle,
so the soldier faces right and aims at itself.

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
URL (`?hitboxes&ai=engine`), and whatever the game prints goes to the
console.

## The website

`docs/` is the site Github Pages serves ("Deploy from a branch",
`/docs`; `.nojekyll`: the files as they are). `docs/index.html` is
written by hand: what the game is, how to play, the notice that the
code is generated by an AI, the credits to Soldat's author; keep the
last two, they are wanted, as in `README.md`. `docs/play.html` and
`docs/MiniSoldat.bc.js` are copies made by `make website` (the page
from `src/main/web/index.html`, the program built with dune's release
profile: 160 KB, against 4 MB in dev) and are committed: run it and
commit them when the game changed and the site should show it.

## Layout

`README.md` has it: `src/map` (the map), `src/anim` (the animations),
`src/game` (the game without its picture), `src/render` (the picture),
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
`src/map`, `src/anim`, `src/game`, `src/render` and `src/net` are, and
must stay
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
