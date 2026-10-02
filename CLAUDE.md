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
`tiny_libs` (`physics_2d`, `ai`). The only C is SDL (and Cairo,
optionally).

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

## Commands

```bash
./configure            # opam deps; checks SDL2 and Cairo (--software: no Cairo)
make                   # dune build
make test              # dune runtest -f
make run               # dune exec mini-soldat
make run-software      # dune exec mini-soldat-software
make build-docker      # what CI runs (OCaml 4.14.4; build-docker-ocaml5 for 5.5.1)
```

One suite, or one test (Testo; each `tests/<suite>/Test.ml` is its own
runner; the one suite for now is `game`):

```bash
dune build @tests/game/runtest --force
dune exec tests/game/Test.exe -- run -s engine   # tests whose name contains it
```

Program flags are words, `name` or `name=value`
(`./bin/mini-soldat hitboxes ai=engine`), read from `computer.flags`:
`hitboxes` (draw what the physics sees), `ai=engine` (the bots on
`Sense` and `Bot`).

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

## Layout

`README.md` has it: `src/map` (the map), `src/game` (the game without
its picture), `src/render` (the picture), `src/main` (the program, and
`software/` the same source on the software platform), each folder a
library (`(wrapped false)`, modules named `Soldat_*`), in the order
they depend on each other. The game is a Model-View-Update program:
`Soldat_model.model`, `Soldat_update.update`, `Soldat_view.view`, all
pure; nothing mutable outside `update_play`'s own arrays.

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
- No content of `opensoldat-base` is copied here without its
  attribution (CC BY 4.0, its `Credits.md`); a port of Soldat's Pascal
  says so and keeps the MIT notice.
