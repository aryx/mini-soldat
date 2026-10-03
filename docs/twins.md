# Twins and layers

mini-soldat is Soldat's Pascal adapted to OCaml on elm-playground. Its
most interesting parts (the soldier's physics, the bots, the sparks,
the menus) are ports: they follow the Pascal, and use little of the
Playground beyond its window. This page is the plan to make the game
also a showcase of the Playground's libraries, and a thing to learn
from, in two ways. Keep it true as twins are written.

## A twin

Where mini-soldat has a part of its own and the Playground has a
library for it, the part gets a **twin**: the same job done with the
Playground's library, beside Soldat's, chosen while the game runs. The
port stays the default: the feel is Soldat's. A twin is small, says in
its opening comment which functions of the library it stands on, and
is what a reader of the Playground's `.mli` would write first.

## A layer

`g` goes round the levels of the picture, from skeletons in flat
colours to Soldat's textures. Every other part gets the same: a key
that goes round its levels, from nothing to Soldat's own, the twin
being one of them. Put every layer at its lowest and the game is
bare: sticks that move and shoot. Add a layer at a time and each
thing a game is made of comes in by itself, to be seen, heard and
compared.

| layer | key | flag | 0 | 1 | 2 | 3 |
|---|---|---|---|---|---|---|
| the picture | `g` | `graphics=` | | skeletons, flat colours | the soldiers' pictures | the map's texture and scenery |
| the sound | `v` | `audio=` | silence | every sound as loud, wherever it is | **the Playground's `Space`**: its attenuation and its pan | Soldat's: quieter by the distance, to a side |
| the effects | `j` | `effects=` | none | **the Playground's `Juice`**: `Emitter`'s particles, `Trauma`'s shake, `Follow`'s camera | Soldat's sparks | |
| the bots | `i` | `ai=` | they stand | **the Playground's `ai`**: `Sense`, `Bot`, `Pathfind`, `Behavior` | Soldat's bots | |
| the physics | `p` | `physics=` | the dead stay as they fell, things do not fall | Soldat's: ragdolls and things on `Particles` | | |
| the interface | `u` | `interface=` | none | the gauges and the scores | Soldat's: the kill console, the pictures, the cursor, the table | |

`basic` puts them all at their lowest. `z` (or the flag `twins`) puts
every layer that has a twin at it, all the Playground's libraries at
once, and `z` again puts them back at Soldat's own: the two games to
compare, a key apart. A level just chosen is said at the bottom of the
screen for a moment.

Where a layer lives says what it may touch. The picture, the sound and
the interface are the view's: a level changes nothing of a round, and
works on a server's round too. The bots and the physics are the
rules': they are a round's (`Soldat_model.play`), a level changes what
happens, and on a server they are the server's. The effects are in
between: the particles are seen only, but live in the round.

## The twins

| part | Soldat's, here | the twin, on the Playground | state |
|---|---|---|---|
| the bots | `Soldat_bots` (from `AI.pas`) | `Soldat_engine_bot`: `Sense` (what it has seen, remembered, forgotten), `Bot` (late, and not every tick), `Pathfind.astar` over the map's waypoints, a `Behavior` tree for what to do | done |
| the effects | `Soldat_sparks` (from `Sparks.pas`), the camera of `Soldat_update.follow` | `Soldat_juice`: `Emitter.burst` and `step`, `Trauma.add`, `decay` and `offset`, `Follow.smooth` | done |
| the sound's place | `Soldat_sound.heard` (from `Sound.pas`) | `Space.attenuation`, `Space.pan` | done |
| things on the ground | `Soldat_things` on `Particles` | rigid bodies: the `Physics` layer, or `Body`, `Collide`, `Solver` | to come |
| a dead body | `Soldat_ragdoll` on `Particles` | `Joint2d` between bodies | to come |
| the network | `Soldat_room`: the server plays, `Prediction`, `Interpolation` | two players in lockstep (`Lockstep`, `Rollback`): a round replays from its inputs already; `Sim_net` in the tests | to come |
| the menus | text shapes by hand | the `gui` library (`Immediate`, `Layout`) for the lobby | to come |

## The book

A literate book of mini-soldat, a chapter a part, each with its twin
as a section ("the bots, Soldat's way"; "the bots, on `Pathfind` and
`Behavior`"), is to follow once the twins give it its shape. Its
form is to decide: noweb kept in step by syncweb (as efuns's), or
Markdown quoting the code.

1. The game in a page: Model, View, Update (`Playground`, `Scene2d`)
2. The map (`Pms`, `Soldat_map`)
3. The soldier: one particle and a skeleton (`Particles`)
4. Weapons and bullets
5. Things, flags, kits (twin: rigid bodies)
6. The bots (twin: the `ai` library)
7. A round's rules and the seven modes
8. The picture (`Camera2d`, `bitmap`); the sparks (twin: `Juice`)
9. The sound (`Audio`; twin: `Space`)
10. The network (`Wire`, `Server`, `Prediction`, `Interpolation`; twin: `Lockstep`)
11. The interface (twin: `gui`)
12. The layers: the same game, a layer at a time
