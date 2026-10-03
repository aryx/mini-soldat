# Twins and layers

mini-soldat is Soldat's Pascal adapted to OCaml on elm-playground. Its
most interesting parts (the soldier's physics, the bots, the sparks,
the menus) are ports: they follow the Pascal, and use little of the
Playground beyond its window. This page is the plan to make the game
also a showcase of the Playground's libraries, and a thing to learn
from, in two ways. Keep it true as twins are written.

## A twin

Where mini-soldat has a part of its own and the Playground has a
library for it, the part is made twice: Soldat's, adapted from its
Pascal, and a **twin**, the same job done with the Playground's
library, as a reader of that library's `.mli` would write it first.
The port stays the default: the feel is Soldat's.

## Three folders, three programs

| folder | what is in it |
|---|---|
| `src/game`, `src/map`, `src/render`... | the shared code: what is made once (the map, the soldier, the weapons, the bullets, a round's rules, the picture) |
| `src/orig` | Soldat's own of the parts made twice: `Soldat_bots`, `Soldat_sparks` and their pictures, `Soldat_fall`, `Soldat_tumble`, `Soldat_online` (a round on a server) |
| `src/twin` | their twins: `Soldat_engine_bot`, `Soldat_juice`, `Soldat_bodies`, `Soldat_limbs`, `Soldat_space`, `Soldat_lockstep`, `Soldat_gui` |

The shared code names neither folder. A part is a record of functions,
and `Soldat_parts` has a *slot* for each, Soldat's and the twin's; a
program fills the slots of the folders it is linked with when it
starts (`Soldat_orig.register`, `Soldat_twin.register`), and a round
asks the slot for the one its layer's level says, or for the other
when that one is not there. What a part keeps from a tick to the next
(a bot's mind, the sparks) is an open type of `Soldat_state`, to which
each part adds its own case. So there are three programs of one shared
code:

| program | linked with | what it is |
|---|---|---|
| `mini-soldat` | both | the whole game: a key goes from Soldat's to the twin while it runs |
| `mini-soldat-orig` | `src/orig` | what is adapted from the Pascal, and nothing else: the same round as `mini-soldat`'s, to the pixel |
| `mini-soldat-twin` | `src/twin` | the shared code on elm-playground's libraries alone: its bots, its effects, its rigid bodies, its lockstep |

`make loc` counts `src/twin` apart: the budget is the port's.

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
| the physics | `p` | `physics=` | the dead stay as they fell, things do not fall | **the Playground's `Physics`**: a thing is one rigid body, a dead soldier ten held by joints | Soldat's: ragdolls and things on `Particles` | |
| the interface | `u` | `interface=` | none | the gauges and the scores | **the Playground's `Gui`**: the lobby's and the title's buttons and menus | Soldat's: the kill console, the pictures, the cursor, the table |

The network is not a layer with a key (a round cannot change its
network while it is played) but a way to start: `server=HOST` for
Soldat's way, a server that plays; `net=host` and `net=join` for the
twin, two players in lockstep.

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
| the sound's place | `Soldat_sound.heard` (from `Sound.pas`) | `Soldat_space`: `Space.attenuation`, `Space.direction` | done |
| things on the ground | `Soldat_things` on `Particles` | `Soldat_bodies`: a kit or a weapon as one body of the `Physics` layer (`body`, `immovable` for the map's walls, `simulate`) | done |
| a dead body | `Soldat_tumble`: its skeleton's points and sticks, on `Particles` | `Soldat_limbs`: ten rigid limbs of the `Physics` layer held by nine `Physics.pin`, and a slack `Physics.rope` between any two others for them not to collide | done; a limb cut off is not there |
| the network | `Soldat_room`: the server plays, `Prediction`, `Interpolation` | `Soldat_lockstep`: two players, no server, only the keys sent (`Lockstep.step`, `packet`, `receive`, `checksum`, `desync`); `Sim_net` as the network in its tests; and with the flag `rollback`, the other's keys guessed and the round played again when the guess was wrong (`Rollback.create`, `step`, `model`) | done |
| the menus | text shapes by hand | `Soldat_gui`: the lobby and the title on `Gui` (immediate mode: `Gui.button`, `Gui.menu`, `Gui.draw`) | done; the weapons' menu of the dead is Soldat's |

## The book

A literate book of mini-soldat, a chapter a part, each with its twin
as a section ("the bots, Soldat's way"; "the bots, on `Pathfind` and
`Behavior`"). Decided (Yoann, 2026-10-03): noweb kept in step by
syncweb, as efuns's; and not yet: once the code is stable and all that
is to be added is in, so that its chunks' markers are put once.

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

## Found on the way, of elm-playground

Each twin's `.mli` has a section "Limits met here, and what is done
about each", with the numbers that showed the limit, and its code says
"Limit" where it works around one: `Soldat_bodies` (five, of any rigid
body), `Soldat_limbs` (two more, of a jointed one), `Soldat_lockstep`
(five), `Soldat_gui`, `Soldat_juice`, `Soldat_engine_bot`,
`Soldat_space`. The two that a change to elm-playground would remove:


- **One step a tick.** `Physics.simulate` is one step of a sixtieth of
  a second, and a body that goes farther in a step than it is thick
  (a weapon 2 thick falling 4 a tick, a limb) is then deeper in the
  floor than it is wide: the collision's test pushes it out sideways,
  and it is thrown away at thousands of units a second. The twins take
  four small steps a tick instead, by asking for a step on speeds four
  times smaller under a gravity sixteen times smaller, four times
  (`Soldat_bodies.small_steps`). A `?steps` in `Physics.simulate`
  would say it better.
- **No way to say "these two do not collide"** but a joint: the limbs
  of one body are given ropes that are never taut.
