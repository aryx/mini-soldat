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

What is still TinySoldat's and so to be replaced by a port: the
soldier (a rigid box in a `Physics.world`, its speeds invented, with
the map twice as big to fit it: `Soldat_map.scale`), its one gun, its
bots, its drawing. The rigid-body world costs a time proportional to
the map's walls each frame (`scripts/perf/Frame_bench`: 12 ms on the
biggest maps, more in a browser); Soldat looks only at the sector a
point is in, which the port brings.

## Commands

```bash
./configure            # opam deps; checks SDL2 and Cairo (--software: no Cairo)
make                   # dune build @default (the web program's page too)
make test              # dune runtest -f, the three suites
make run               # dune exec mini-soldat
make run-software      # dune exec mini-soldat-software
make serve             # the game in a browser, http://localhost:8001/
make website           # the release .bc.js and its page copied to docs/
make serve-website     # docs/ as Github Pages will serve it, http://localhost:8000/
./bin/mini-soldat-server port=23073 bind=127.0.0.1 capacity=32
make build-docker      # what CI runs (OCaml 4.14.4; build-docker-ocaml5 for 5.5.1)
```

One suite, or one test (Testo; each `tests/<suite>/Test.ml` is its own
runner; the suites are `map`, `game` and `server`):

```bash
dune build @tests/game/runtest --force
dune exec tests/game/Test.exe -- run -s engine   # tests whose name contains it
```

Program flags are words, `name` or `name=value`
(`./bin/mini-soldat hitboxes ai=engine`), read from `computer.flags`:
`hitboxes` (draw what the physics sees), `ai=engine` (the bots on
`Sense` and `Bot`), and, read by the main before the game starts,
`map=FILE` (a `.pms`; `~/` understood), `map=toy` (TinySoldat's
screen, what the game's tests play on), nothing: Arena2, carried in
the program (`data/maps/Arena2.pms` as base64, `src/map/dune`'s rule).

`dune exec scripts/perf/Frame_bench.exe -- ~/work/GAMES/opensoldat-base/shared/maps/*.pms`
reads every map of Soldat's, plays 300 frames on each and prints a
frame's time: the check that a change to `Pms` or `Soldat_map` still
takes them all (two minutes).

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

`README.md` has it: `src/map` (the map), `src/game` (the game without
its picture), `src/render` (the picture), `src/main` (the program, and
`software/` and `web/` the same source on the software platform and in
a browser), `src/net` (the protocol), `src/server` (the lobby, the
server, and `main/` its program), each folder a library (`(wrapped
false)`, modules named `Soldat_*`), in the order they depend on each
other. The game is a Model-View-Update program: `Soldat_model.model`,
`Soldat_update.update`, `Soldat_view.view`, all pure; nothing mutable
outside `update_play`'s own arrays.

What the browser's program links must be pure OCaml (no `unix`):
`src/map`, `src/game`, `src/render` and `src/net` are, and must stay
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
