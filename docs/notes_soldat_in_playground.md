# Soldat in the Playground: the mapping

mini-soldat is Soldat's Pascal adapted to OCaml and to
[elm-playground](https://github.com/aryx/ocaml-elm-playground)'s API
and libraries (`CLAUDE.md`, "The approach"). This note is the
dictionary between the two: for each term, concept and piece of code
of Soldat's, what it is here. It says what is known, with where it was
read; what is not ported yet is marked *to come*, with what it will
stand on.

Soldat's sources are `~/work/GAMES/opensoldat` (paths below are in
it), its content `~/work/GAMES/opensoldat-base`; the Playground is
`~/playground` (its libraries are `tiny_libs`, its 2D API
`elm_playground`). `docs/opensoldat.md` has the files, module by
module; this note has the ideas.

## Soldat's words

| Soldat says | Meaning | Here |
|---|---|---|
| *gostek* | the soldier's body: a skeleton of points and sticks (`objects/gostek.po`) with a picture on each limb (`gostek-gfx/`). Polish for "guy" | `Soldat_ragdoll` for now (9 particles, dead soldiers only); *to come*: the real skeleton |
| *sprite* | a soldier, not a picture: `TSprite`, in `Sprite[1..MAX_SPRITES]` | `Soldat_model.soldier` |
| *part* | a particle: `ParticleSystem` (`shared/Parts.pas`) | `Particles.particle` |
| *constraint* | a stick between two particles, with its rest length | `Particles.stick` |
| *skeleton* | a `ParticleSystem` with constraints: the gostek's, a flag's, a kit's | a `particle array` and its `stick list` |
| *poly* | a triangle of the map, with its kind (`PolyType`) | `Pms.polygon`, `Pms.kind` |
| *perp* | a polygon's edge normal, stored in the map file | `Pms.polygon.perps` |
| *sector* | a square of the grid laid over the map, listing the polygons that touch it | `Pms.t.sectors` |
| *prop*, *scenery* | a picture placed on the map; the picture's file | `Pms.prop`, `Pms.t.scenery` (read, not drawn yet) |
| *collider* | a circle that stops bullets | `Pms.collider` (read, not used yet) |
| *thing* | what lies on the map and can be picked up or carried: flags, kits, dropped weapons (`TThing`) | *to come* |
| *spark* | a short-lived particle for the eye: blood, smoke, shells (`TSpark`) | *to come* |
| *waypoint* | a node of the graph bots walk along | `Pms.waypoint` (read, not used yet) |
| *tick* | a step of the game: 60 a second (`DEFAULT_GOALTICKS`) | a frame of the Playground: `update`, 60 a second |
| *cvar* | a named setting (`net_port`, `sv_maxplayers`: `shared/Cvar.pas`) | a flag, `name=value` on the command line or after `?` in a URL |
| *smod* | the archive of the game's content (`soldat.smod`), read through PhysFS | files embedded as base64 (`src/map/dune`), or fetched (*to come*) |

## The shape of the program

Soldat keeps its world in global arrays of fixed size, changed in
place: `Sprite[i]`, `Bullet[i]`, `Thing[i]`, `Spark[i]`, the particle
systems `SpriteParts`, `BulletParts`, `SparkParts`, and `Map`. The
Playground runs a Model-View-Update program: one value for the world,
a function from a world and the inputs to the next world, a function
from a world to shapes.

| Soldat | Here |
|---|---|
| the global arrays, mutated each tick | one immutable value, `Soldat_model.play` |
| `Active: Boolean` in each slot of an array | a list or an array of exactly what exists |
| `Update_Frame` (`client/UpdateFrame.pas`), the server's loop (`server/ServerLoop.pas`) | `Soldat_update.update` |
| `RenderFrame` (`client/GameRendering.pas`), OpenGL through `client/Gfx.pas` | `Soldat_view.view`, a list of the Playground's shapes |
| `client/Input.pas`, `client/ControlGame.pas`: SDL's events | `computer.keyboard`, `computer.mouse` |
| `TControl`, a soldier's keys this tick, set by the keyboard, a bot or the network | `Soldat_model.intent` |
| the window, the timer, the loop: SDL, `client/Client.pas` | `Playground_platform.run_app` |
| a client and a server built from `shared/` with `{$IFDEF SERVER}` | libraries: `src/game` linked by the game and, one day, by the server |

The gain in code comes mostly from here: no slot management, no
`{$IFDEF}`, and the window, the drawing, the sound and the sockets are
the Playground's.

## Units and coordinates

| | Soldat | Here |
|---|---|---|
| time | a tick, 1/60 s; speeds are per tick, accelerations per tick squared (`TimeStep := 1`) | the same: a frame is a tick |
| length | a pixel of its view | twice that for now (`Soldat_map.scale`), until the soldier is Soldat's |
| y | grows downwards | grows upwards: turned over when a map is read |
| gravity | `Grav = 0.06` a tick squared (`shared/Game.pas`), times each system's `GravityMultiplier` | `Soldat_map.gravity`, the toy's 800 pixels a second squared, for now |

*To come* with the soldier's port: Soldat's own units (a scale of 1,
gravity 0.06), y turned over in one place only, when drawing and when
reading the mouse.

## The physics

Soldat's physics is one small unit, `shared/Parts.pas`: particles,
two ways to step them, and sticks. elm-playground's
`libs/physics/2d/Particles` (Jakobsen's particles and sticks) is the
same idea, and its formulas match.

**The soldier that moves** is one particle of `SpriteParts`, stepped
by `ParticleSystem.Euler`:

```
velocity := velocity + forces / mass * TimeStep^2     (forces include Grav * GravityMultiplier)
pos      := pos + velocity
velocity := velocity * EDamping
```

with `TimeStep = 1`, `GravityMultiplier = 1`, `EDamping = 0.99`
(`shared/Anims.pas`). The keys add to `forces` (`shared/mechanics/Control.pas`).
That is semi-implicit Euler with a damping: three lines here, or
`Integrate.semi_implicit_euler` on a `Body`.

**A skeleton let loose** (a dead soldier's body, a flag, a kit) is
stepped by `ParticleSystem.Verlet`, then its constraints satisfied
once. A living soldier's skeleton is not simulated at all: it is put
where its animations say, each tick (see "The soldier" below).

```
pos' := pos * (1 + VDamping) - oldpos * VDamping + forces / mass * TimeStep^2
```

which is `Particles.step`:

```
pos' := pos + (1 - drag) * (pos - old) + dt^2 * accel
```

with `drag = 1 - VDamping`, `dt = 1`, `accel` the gravity.

| Soldat | Value | Here |
|---|---|---|
| `ParticleSystem.Verlet` | | `Particles.step ~drag ~accel ~dt:1.` |
| `VDamping` of a soldier's skeleton | 0.9945 (`CreateSprite`) | `~drag:0.0055` |
| its `GravityMultiplier` | 1.06 | `~accel:(0., 1.06 *. grav)` |
| `ParticleSystem.SatisfyConstraints` | one pass | `Particles.relax ~iterations:1` |
| `OneOverMass = 0`, a particle nothing moves | | `pinned = true` |
| `ParticleSystem.Euler` | `EDamping` 0.99 (soldiers, bullets), 0.998 (sparks) | a few lines of our own |
| `BulletParts.GravityMultiplier` | 2.25 | the bullets' gravity |
| `SparkParts.GravityMultiplier` | 1 / 1.4 | the sparks' |
| `NUM_PARTICLES` | 560 slots a system | an array as long as needed |

One difference found: a stick with one end pinned. Soldat moves the
free end by half the error each pass (`Vec2Scale(D, Delta, 0.5 * Diff)`,
whatever the other end is); `Particles.relax` moves it by all of it.
If a ragdoll that hangs from a pinned point feels different, that is
why, and the place to add an option.

**Not the rigid-body solver.** TinySoldat's soldier is an upright box
in a `Physics.world` (`Solver`, `Contact`, `Broadphase`): nothing in
Soldat is a rigid body. The port moves the soldier to the particle
above, and the `Physics.world` goes away, with its cost (a time
proportional to the map's walls, each frame).

## The map and what touches it

| Soldat (`shared/PolyMap.pas`) | Here |
|---|---|
| `LoadMapFile` (`shared/MapFile.pas`) | `Pms.parse` |
| `TPolyMap.LoadData` | `Soldat_map.of_pms` |
| `PointInPoly`, `PointInPolyEdges` (a point on the inner side of the three perps) | `Collide.point_in_polygon` |
| `ClosestPerpendicular` (the nearest edge, and how far), over `PointLineDistance` (`shared/Calc.pas`) | `Collide.nearest_on_outline` |
| `CollisionTest`: the point's sector (`Round(Pos.x / SectorsDivision)`), its polygons, the first one the point is in, and the vector to push it out by (the perp, 1.5 times the depth) | `Particles.keep_out`, given the sector's polygons only: *to come*, today every wall is looked at |
| `RayCast`: a segment against the sectors' polygons | `Collide.segment_polygon`, today against every wall (`Soldat_map.clear`) |
| `LineCircleCollision` (`shared/Calc.pas`): a bullet's path against a collider | `Collide.segment_circle` |
| which kind stops what (`EXCLUDED1`, the `Team` and `Flag` tests of `RayCast`) | `Soldat_map.stops_soldier`, `stops_bullet` (no teams, no flags yet) |
| `Bounciness`: the length of a polygon's third perp | `Pms.polygon.perps.(2)` (not used yet) |
| `TVector2`, `Vec2Add`, `Vec2Subtract`, `Vec2Scale`, `Vec2Dot`, `Vec2Length`, `Vec2Normalize` (`shared/Vector.pas`) | `Vec2.add`, `sub`, `scale`, `dot`, `length`, `normalize` |

## The soldier

Read in `shared/mechanics/Sprites.pas` (`TSprite`),
`shared/mechanics/Control.pas` (`ControlSprite`) and `shared/Anims.pas`.
None of it is ported yet: this is what the port has to be.

**Two things, one of which moves.** A soldier has no position of its
own: it is particle number `Num` of `SpriteParts`, a point near its
feet, mass 1. Its body, `Sprite[i].Skeleton`, is a copy of the gostek's
skeleton (24 points, 30 sticks) that, while the soldier lives, is
written over each tick from its two animations:

```
legs points (1-6, 17, 18):   Pos[i] := particle + (Direction * frame.x, frame.y)   of LegsAnimation
body points (7-16, 19, 20):  the same of BodyAnimation, hung from the hip (point 6) by BodyY
```

`Direction` is 1 or -1, the side of the particle the cursor is on:
which way a soldier faces is the mouse's business alone, and running
against it is running backwards. Dead, it is the other way round: the
skeleton is let loose (Verlet, its sticks) and the particle follows
its head (`SpriteParts.Pos[Num] := Skeleton.Pos[12]`). The speed the
ragdoll starts with is what the last living tick left between `Pos`
and `OldPos`.

| Soldat | Here, *to come* |
|---|---|
| the particle of `SpriteParts` | a position and a velocity in the soldier's record, stepped by Soldat's Euler |
| `Skeleton`, alive: 20 points placed from the animations | a function of the soldier (its particle, its two animations and their frames, its direction): computed when needed, not stored |
| `Skeleton`, dead: Verlet and constraints | a `particle array` and its `stick list`: `Particles.step`, `Particles.relax ~iterations:1` |
| a stick cut (a head, a leg shot off: `Constraints[i].Active := False`) | the stick taken out of the list |
| `Control: TControl` (the keys and where the mouse is, in the map) | `Soldat_model.intent`, grown to Soldat's keys |
| `Position`: stand, crouch, prone | a variant |
| `LegsAnimation`, `BodyAnimation`: a copy of an animation with its current frame | which animation, and the frame it is at |
| `OnGround`, `OnGroundPermanent` (the same, over two ticks) | fields of the soldier |
| `JetsCount`, from the map's `StartJet` | the fuel |
| `Health`, `DeadMeat`, `RespawnCounter` | as today |

**A tick**, in Soldat's order (`client/UpdateFrame.pas`, then
`TSprite.Update`), which the port keeps, because the forces of one
tick are what the next tick's step integrates:

1. the Euler step of every soldier's particle;
2. for each soldier: its keys (`ControlSprite`: forces, and which
   animations), its direction, its skeleton placed, its head and hands
   turned to the cursor, its animations advanced, the collision with
   the map, the weapon's timers, the jets refilled, the velocity kept
   under `MAX_VELOCITY` (11).

**The keys are forces, and animations.** `ControlSprite` writes to the
particle's `Forces` (most often sets, not adds), and chooses the legs'
and the body's animations by a chain of cases in a fixed priority:
rolling; down and a side (a roll, or a crouched walk); prone; up and
a side (a side jump); up (a jump); down (a crouch); a side (run, or
run backwards); nothing (stand, or fall). A jump is not an impulse:
the force is applied while the jump's animation is between two of its
frames (9 to 14), after a wind-up. Frame numbers are written all over
the Pascal, so the animations keep their frames numbered from 1.

| Constant (`shared/Constants.pas`) | Value | What |
|---|---|---|
| `RUNSPEED` | 0.118 | the force of a run, on the ground (with `RUNSPEEDUP`, a sixth of it, upwards) |
| `FLYSPEED` | 0.03 | the same in the air |
| `JUMPSPEED` | 0.66 | a jump's, upwards |
| `JUMPDIRSPEED` | 0.30 | a side jump's |
| `CROUCHRUNSPEED` | `RUNSPEED / 0.6` | a crouched walk's |
| `PRONESPEED` | `RUNSPEED * 4` | a crawl's, in pulses |
| `ROLLSPEED` | `RUNSPEED / 1.2` | a roll's |
| `JETSPEED` | 0.10 | the jets', upwards |
| `Grav` (`shared/Game.pas`) | 0.06 | gravity |
| `MAX_VELOCITY` (`Sprites.pas`) | 11 | the fastest, on each axis |
| `SLIDELIMIT` | 0.2 | below it a soldier standing on a floor does not slide |
| `SURFACECOEFX`, `Y` | 0.97 | what the ground leaves of a speed when moving |
| `STANDSURFACECOEFX`, `Y` | 0.0 | and when standing: a full stop |

**The collision with the map** looks at the polygons of one sector
only, the one the point tested is in, and tests points, not a box:
two at the head (3.5 either side, 12 up), two at the feet (2 either
side, 2 down: these say `OnGround`), then a circle of radius 3
(`SPRITE_COL_RADIUS`) against the edges, then the polygons' corners.
Each test is made where the particle will be (`Pos + Velocity`), and
what it corrects is the particle's position and velocity. A polygon's
kind acts here: ice leaves out the standing friction, a bouncy one
gives back the speed times its bounciness, the deadly and hurting
ones take health (in the Pascal on the server only: `{$IFDEF SERVER}`).

| Soldat | Here, *to come* |
|---|---|
| `CheckMapCollision` (a point of the soldier) | `Collide.point_in_polygon` over the sector's polygons, `Collide.nearest_on_outline` for the push; the friction rules are Soldat's own, to port |
| `CheckRadiusMapCollision` (the circle) | `Collide.circle_convex` or the Pascal's edge tests, to compare |
| `CheckMapVerticesCollision` (near a corner: a push of 1 away) | a few lines |
| `CheckSkeletonMapCollision` (a dead body's points) | `Particles.keep_out`, given the sector's polygons |

**The animations.** 44 of them (`shared/Anims.pas`), each a file of
the content (`anims/*.poa`, text: a frame is 20 points, each a number
and x, y, z on four lines; `NEXTFRAME` between frames, `ENDFILE` at
the end), with a speed (ticks a frame) and whether it loops, both set
in the Pascal, not in the file. The names are Polish: `stoi` (stands),
`biega` (runs), `biegatyl` (runs backwards), `skok` (jumps),
`skokwbok` (jumps sideways), `spada` (falls), `kuca` (crouches),
`lezy` (lies), `wstaje` (gets up), `rzuca` (throws), `celuje` (aims).
Read, a point is `x := -3 * x / 1.1`, `y := -3 * z` (`SCALE = 3`; the
file's y is depth, unused). A skeleton is a `.po` file, alike: the
points, `CONSTRAINTS`, then pairs of points, a stick's length being
the distance between its two points as read.

| Soldat | Here, *to come* |
|---|---|
| `TAnimation.LoadFromFile` | a reader of `.poa`, as `Pms` is of `.pms`; the files in `data/anims/`, embedded |
| `ParticleSystem.LoadPOObject` | a reader of `.po`, giving particles and sticks |
| `TAnimation.DoAnimation` (a frame every `Speed` ticks; the last frame held, or back to the first) | a function on (animation, frame, count) |
| `LegsApplyAnimation`, `BodyApplyAnimation` (change only to another animation; never out of prone) | the same two rules |

**Aiming.** The mouse's place in the map is in the soldier's controls.
The head (point 12) is put beside the neck (9) across the line to the
cursor; the two hands (15, 19) are put 7 and 8 units from the hand the
animation holds (16), towards the cursor, unless the body is busy
(reloading, changing weapon, punching, rolling...). A bullet leaves
from point 15.

**Death.** Health under 1 is a death; under -90 the hit took the head
or a leg off (a stick cut); under -400 it took the head, the legs and
the arms. `Respawn` puts the sticks back, the health, the fuel, and
gives 90 ticks during which the soldier cannot fire
(`CeaseFireCounter`).

**What a first port leaves out** of these files, most of their lines:
everything under `{$IFDEF SERVER}` and the network (the delayed
pushes, the snapshots), the bots' part, the sparks and the sounds, the
idle animations (the cigar, the helmet taken off...), the dangling
chain and hair (points 21 to 25), the bonuses, the stationary gun, the
parachute, the flags. `TSprite.Die` is 768 lines of which about 80 are
the ragdoll's; `ControlSprite` is one procedure of 2,090 lines.

## The weapons and the bullets

Read in `shared/Weapons.pas`, `shared/mechanics/Bullets.pas`, the
firing in `TSprite.Fire` (`Sprites.pas`) and
`server/configs/weapons.ini`. Not ported yet.

**One rule to read the Pascal by: the server's branch is the game.**
On a client a hit's damage is multiplied by `srv`, which is 0: only
the server takes health, picks things up, scores, runs the bots and
respawns. The port follows the `{$IFDEF SERVER}` branches for the
rules, and the client's for what is seen and felt (the sparks, the
sounds, the bink, the recoil).

A weapon is a row of numbers (`TGun`), 23 of them: 10 primaries, 4
secondaries, 3 of bonus kits, and fists, grenades, the stationary
gun. The numbers are `weapons.ini`'s (which the server reads over the
compiled ones: they differ for the AK-74 and the Ruger).

| Weapon | Damage | Fire interval | Ammo | Reload | Speed | Notes |
|---|---|---|---|---|---|---|
| Desert Eagles | 1.81 | 24 | 7 | 87 | 19 | two bullets a shot; one shot a press |
| HK MP5 | 1.01 | 6 | 30 | 105 | 18.9 | |
| Ak-74 | 1.11 | 11 | 40 | 150 | 24 | |
| Steyr AUG | 0.71 | 7 | 25 | 125 | 26 | |
| Spas-12 | 1.22 | 32 | 7 | 175 | 14 | 6 pellets, pushes its owner back; reloads a shell at a time |
| Ruger 77 | 2.49 | 39 | 4 | 84 | 33 | one shot a press |
| M79 | 1550 | 6 | 1 | 178 | 10.7 | explodes |
| Barrett M82A1 | 4.45 | 225 | 10 | 70 | 55 | 19 ticks before it fires; binks who it hits |
| FN Minimi | 0.85 | 9 | 50 | 250 | 27 | |
| XM214 Minigun | 0.468 | 3 | 100 | 480 | 29 | 25 ticks before it fires; pushes its owner |
| USSOCOM | 1.49 | 10 | 14 | 60 | 18 | the secondary one starts with |
| Combat Knife, Chainsaw, M72 LAW | | | | | | the other secondaries |
| Grenade | 1500 | | | | | thrown: its speed is the throw animation's frame |

Times are ticks. **Damage is not the number above**: a bullet's hit is
`its speed * Damage * a modifier` for where it hit (head 1.1, chest
0.95, legs 0.85 for most), of a health of 150 (`DEFAULT_HEALTH`). An
Eagle's bullet in the chest: 19 * 1.81 * 0.95, about 33. A bullet
slows down (0.99 a tick) and halves its damage past 500 then 900
pixels, so distance counts.

| Soldat | Here, *to come* |
|---|---|
| `Guns: array[1..23] of TGun`, built in Pascal then read from `weapons.ini` | a table of records; `weapons.ini` read (in `data/`), or the table written out |
| the gun's counters (`FireIntervalCount`, `ReloadTimeCount`, `StartUpTimeCount`, `AmmoCount`) | fields of the soldier's weapon |
| `TSprite.Fire`: the direction (from the hand, point 15, to the cursor), the inaccuracy (bink, moving, the weapon's spread; less crouched and prone), the bullet's velocity (the weapon's speed along it, plus half the soldier's) | a function from a soldier to its bullets |
| a bullet: `TBullet`, and its particle in `BulletParts` (Euler, gravity 2.25 times `Grav`, damping 0.99) | a record with a position and a velocity, stepped by the same Euler |
| the bullet's styles (plain, grenade, shotgun, M79, flame, punch, arrow, cluster, knife, LAW, thrown knife, M2) | a variant |
| `TBullet.Update`: against the map, the colliders, the soldiers, the things, in that order, on the segment from where it is to where it will be; then it moves | `Collide.segment_polygon`, `Collide.segment_circle`; the toy does this today with `Physics.went_through` |
| against the map: the segment sampled every 2.5 pixels, `PointInPolyEdges` in the sector's polygons; a ricochet (`V * 25/35 + Perp * 10/35`) or the end | the sector's polygons, and Soldat's ricochet rule |
| against a soldier: `LineCircleCollision` with circles of radius 7 (`PART_RADIUS`) at 7 points of its skeleton (head 12, shoulders 11 and 10, hips 6 and 5, knees 4 and 3): which one says head, chest or legs | `Collide.segment_circle` at the same 7 points |
| through a body: a bullet fast enough goes on, slower (0.75, 0.66) | the same rule |
| a push: the victim's velocity plus the bullet's times the weapon's `Push` | the same |
| an explosion (`ExplosionHit`): within a radius (grenade 85, M79 64, cluster 35), damage `1 / (distance + 1)` times the weapon's, a push away, a kick to the ragdolls' points, and the other grenades near set off | the toy's blast, with Soldat's numbers and its falloff |
| the reload: at 0 ammo, a count-down holding the gun; `ClipOut` then `ClipIn` animations at 80% and 30% of it | counters, and the animations |
| bink (being hit shakes one's aim) and recoil (0 for every weapon but in realistic mode) | bink with the weapons; recoil later |

## The things

`shared/mechanics/Things.pas`. A thing is a small skeleton of 2 or 4
points let loose (Verlet), which freezes once it lies still: a dropped
weapon is a stick (`karabin.po`), a kit a braced square (`kit.po`), a
flag a square (`flag.po`). 27 kinds: the three flags, 14 weapons
dropped, the bow, the medikit and the grenade kit, five bonus kits,
the parachute, the stationary gun. `CreateThing`'s 25 near-identical
cases are a table: for each kind its skeleton, its damping, its
gravity, its radius, how long it stays.

| Soldat | Here, *to come* |
|---|---|
| `TThing`, its `Skeleton` | a kind, a `particle array`, its sticks: `Particles.step`, `relax`, `keep_out` |
| picked up (`CheckSpriteCollision`, the server's): a soldier within the thing's radius; a weapon only by one with empty hands | a test of distance, in `update` |
| where things appear: the map's spawn points whose team is above 4 (5 and 6 the flags, 7 grenade kits, 8 medikits, 9 to 13 the bonus kits, 14 the yellow flag, 15 the bow, 16 the stationary gun) | `Pms.spawnpoint.team` |
| a flag held: its first point on its holder's back (point 8), the other pulled up | the same |
| a capture: the holder of the enemy's flag within 28 of its own, at home (within 75 of where it appears) | the same |

For a deathmatch: the dropped weapons, the medikits and the grenade
kits are enough.

## The sparks

`shared/mechanics/Sparks.pas`, the client's alone and for the eye
alone: a particle (Euler, a gravity of its own, damping 0.998) with a
life in ticks and a style, a bare number from 1 to 73: smoke, blood,
the shells and the clips each weapon drops, explosions, ricochets,
dirt, the jets' fire, the weather. *To come*, late: a list of them in
the model, drawn as small pictures; the Playground has `Juice`
(`tiny_libs.juice`) for such effects, to look at then.

## The rules, and the bots

| Soldat | Here, *to come* |
|---|---|
| the modes (`GAMESTYLE_*`): deathmatch, pointmatch, teammatch, capture the flag (the default), rambo, infiltration, hold the flag | a variant; deathmatch first, as today |
| a round's end: a kill limit (10) or a time limit (10 minutes), then the scores for 320 ticks, then the next map | the toy's "first to 5"; then Soldat's |
| respawn: 180 ticks after dying (in team modes, in waves) | the toy's 120 frames; then Soldat's |
| the tick's order (`server/ServerLoop.pas`): the soldiers' particles stepped, each soldier updated (its keys, or its bot's), each bullet updated (its collisions), the bullets' particles stepped, each thing updated; the client adds the sparks | `Soldat_update.update_play`, in that order |
| a bot (`shared/AI.pas`, `ControlBot`): it only presses keys and moves the mouse, in the same `TControl` a player fills | as today: a bot returns an `intent` |
| its way: no path-finding. It goes to the nearest waypoint, picks one of its connections at random, and holds the keys that waypoint says (left, right, up, down, jets): the map's author walked it | `Pms.waypoint`; the Playground's `ai` (`Sense`, `Bot`) for what it may know and how fast it reacts, if wanted beside it |
| its target: the nearest enemy its head sees (a ray on the map, 651 pixels at most) | `Soldat_map.clear` |
| its fight (`SimpleDecision`): by how far the target is across, in 8 distances: back away, stop and crouch, jump, fire always or one tick in two or in four | a table |
| its aim: where the target is going, raised for the distance, with an error up and down of at most its `Accuracy` in pixels | the same |
| its character, a `.bot` file: accuracy, favourite weapon, how often it throws a grenade, whether it camps, whether it shoots the dead | the 16 files, in `data/`, read |

## The frame, drawn

Read in `client/GameRendering.pas`, `client/MapGraphics.pas`,
`client/GostekGraphics.pas` and `.inc`, `client/Gfx.pas`. Soldat draws
everything as textured, tinted quads and triangles, through OpenGL.

**The order** (`RenderFrame`), which `Soldat_view` follows: the sky,
the background polygons and their edges, the props of layer 0, the
bullets, the soldiers, the things, the sparks, the props of layer 1,
the other polygons and their edges (over the soldiers), the props of
layer 2, the interface.

**The view** is 640 by 480 of Soldat's units (`DEFAULT_WIDTH`,
`DEFAULT_HEIGHT`; up to 854 wide on a wide window), y downwards, the
camera the point at its centre. Each tick the camera goes 0.14
(`CAMSPEED`) of the way to the player and is moved by the mouse:

```
Cam := Cam + 0.14 * (Player - Cam) + (Mouse - Centre) / 7      (AimDistCoef = 7, at 640 wide)
```

so that at rest it is about one mouse's offset from the player: one
sees as far ahead as one points. Soldat draws between two ticks
(positions interpolated by how far the next tick is); the Playground
calls `update` once a frame, so there is nothing to interpolate.

| Soldat | Here |
|---|---|
| the camera's rule above | `Camera2d.t` in the model, its rule three lines of `update`; `Camera2d.view`, `to_world` for the mouse. Today `Camera2d.follow`, a little different: *to come*, Soldat's |
| 640 by 480, y down | the Playground's screen is 1000 by 1000, y up: a camera zoom, or `window.screen_size` |
| the sky: two colours, from the top to the bottom of the map's range (25 sectors each way), the screen's width | bands of `rectangle`s (no gradient in the Playground); or a picture one pixel wide, stretched |
| a polygon: the map's texture (512 by 512, repeated), each corner with its u, v and its colour, which multiplies the texture | `polygon`, one colour: the corners' mean times the texture's mean (`Texture_tints`). **Nothing** in the Playground draws a textured or shaded triangle |
| the edges (`r_smoothedges`): along each outer edge of the map, a strip of `textures/edges/`, to soften it | *to come*, with the textures |
| a transparent polygon (alpha 0): a wall one cannot see | not drawn |
| a prop: its picture (`scenery-gfx/`), placed, turned, scaled each way, tinted, with an alpha, in one of three layers; pure green is transparent | `bitmap w h picture |> rotate |> move`: *to come*. The tint and the green are to be put into the pixels first (`Pixels.map`) |
| the soldier: 15 pictures and more (`gostek-gfx/`: `morda` the head, `klata` the chest, `biodro` the hip, `udo` the thigh, `noga` the lower leg, `stopa` the foot, `ramie` the arm, `reka` the forearm, `dlon` the hand), each hung between two points of the skeleton (the head from 9 to 12, a thigh from 6 to 3...), turned along them, some stretched (the thighs, the forearms), tinted the shirt's, the trousers', the skin's or the hair's colour, mirrored when facing left | `bitmap` again, a picture per (part, tint, side), made once: *to come*. The table of parts (`GostekGraphics.inc`, 131 lines) becomes a table here |
| the pictures are 4.5 times bigger than drawn (`mod.ini`'s `DefaultScale`): a head of 27 pixels is 6 units | the `w` and `h` given to `bitmap` |
| the weapon in the hands (between points 16 and 15), its clip, its fire | the same, three more pictures |
| the interface (`client/InterfaceGraphics.pas`): bars for health, ammo, jets (a picture cut at a fraction), the cursor, the kills' console, the chat, the scores, the weapons' menu, the minimap | shapes outside the camera's group: `rectangle`s for the bars, `words` for the texts |
| an atlas of pictures, colour keys, premultiplied alpha, mipmaps (`client/Gfx.pas`) | the Playground's backends: Cairo, its own rasterizer, or SVG in a browser |

## The sound

`client/Sound.pas`: 163 samples (`sfx/*.wav`), played through OpenAL.
A sound has a place: it is heard at `1 - distance / 750`
(`SOUND_MAXDIST`) of its volume, nothing beyond, and to the left or
the right by how far it is across. Three loop (the jets, the chainsaw,
the flamer); the rest play once.

| Soldat | Here, *to come* |
|---|---|
| a sample loaded | `Audio.wav bytes` (16-bit only: 63 of Soldat's are 8-bit, to convert or to teach `Wav`) |
| played at a place | `Audio.play (sound |> Audio.louder volume |> Audio.pan side)`, the volume and the side by Soldat's rule |
| a loop on a channel, stopped | `Audio.loop name sound`, `Audio.stop name`, or `Audio.keep_playing` each frame |
| 128 sounds at once | 32 (`Mixer.max_playing`) |
| in a browser | the same mixer, through the page's `AudioContext` |

## Files and content

| Soldat | Here |
|---|---|
| `soldat.smod`, an archive read through PhysFS; a map's own archive mounted over it | a file embedded as base64 (`scripts/build/file_to_base64_ml.ml`), what is small and always needed: a map, the skeleton, the animations, the weapons' numbers |
| | or fetched when wanted, the rest (99 maps, 95 MB of textures and scenery): `Audio.fetch path_or_url k` gives a file's bytes natively and a URL's in a browser; `image w h url` shows a picture as it is, by its URL alone |
| PNG, BMP, GIF, through stb_image | `Png.decode`, `Gif.decode`, `Jpeg.decode` to an `Rgba_image.t`. No BMP: 58 pictures of scenery and the 31 edges are BMP, to convert or to read |
| a colour key (pure green, or black) made transparent when loading | `Pixels.map` on the decoded picture |

## What the Playground lacks

Found while reading both sides; each is a place where either the game
does with less, or elm-playground gains something (there, then
required here). In the order they would hurt:

| Lacking | Needed for | Without it |
|---|---|---|
| a textured triangle, shaded by its corners | the map as Soldat draws it | flat colours (today); or the map drawn once into pictures by our own code, shown with `bitmap` |
| an image tinted | the soldier's shirt, trousers, skin; the props' colours | a picture made per tint, once |
| an image mirrored | a soldier facing left | a picture made per side, once |
| an image's `fade` on Cairo (it is ignored there; the software platform and the browser do it) | a soldier fading in, the props' alpha | the alpha put into the pixels |
| more than 32 pictures kept in a browser (each new `bitmap` is encoded as a PNG; only the last 32 are kept) | a soldier is 15 pictures and more: three soldiers and the scenery are past it | pictures by URL (`image`), which cannot be tinted; or the limit raised |
| part of an image | the interface's bars, an atlas | rectangles; a picture each |
| a BMP decoder | part of the scenery, the edges | converted once, in `data/` |
| 8-bit WAV | 63 sounds | converted once |
| a gradient | the sky | bands |
| the mouse's cursor hidden | Soldat's own cursor | both shown |
| a WebSocket to any server (`Transport` opens one to a relay: `ws://`, no path, the first two bytes `02 n` taken as a seat) | the game talking to `mini-soldat-server` | works as it is: our messages never start with `02`; `wss://` is the one thing missing |

## The network

| Soldat | Here |
|---|---|
| UDP, through Valve's GameNetworkingSockets (`shared/network/Net.pas`) | WebSocket (`Server`, `Relay_client`, `Transport`): what a browser has |
| a message: a packed record opening with its number (`MsgID_*`) | `Soldat_protocol`: a first byte, then fields written with `Wire` |
| a server is one game; the list of servers is another program's (`server/LobbyClient.pas`) | one server, many rooms (`Soldat_lobby`) |
| a client says where its own soldier is (`TMsg_ClientSpriteSnapshot_Mov`: position, velocity, keys) | *to come*, and a choice: that, or the server owning the game (`Snapshot`, `Prediction`, `Interpolation`) |
| `shared/Demo.pas`: a game recorded and played back | *to come*; a pure `update` and recorded inputs replay a game by themselves |

## To come

What is planned, and in which order, is `docs/plan.md`. This note is
kept true as parts are ported: a row marked *to come* gets its module
when it has one.
