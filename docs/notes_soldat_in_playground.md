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
| *gostek* | the soldier's body: a skeleton of points and sticks (`objects/gostek.po`) with a picture on each limb (`gostek-gfx/`). Polish for "guy" | `Soldat_anims.gostek` (the skeleton), `Soldat_gostek` (the pictures on it) |
| *sprite* | a soldier, not a picture: `TSprite`, in `Sprite[1..MAX_SPRITES]` | `Soldat_soldier.t` (what moves), in `Soldat_model.soldier` (its health, its kills) |
| *part* | a particle: `ParticleSystem` (`shared/Parts.pas`) | `Particles.particle` |
| *constraint* | a stick between two particles, with its rest length | `Particles.stick` |
| *skeleton* | a `ParticleSystem` with constraints: the gostek's, a flag's, a kit's | a `particle array` and its `stick list` |
| *poly* | a triangle of the map, with its kind (`PolyType`) | `Pms.polygon`, `Pms.kind` |
| *perp* | a polygon's edge normal, stored in the map file | `Pms.polygon.perps` |
| *sector* | a square of the grid laid over the map, listing the polygons whose outline crosses it | `Soldat_map.sector` |
| *prop*, *scenery* | a picture placed on the map; the picture's file | `Pms.prop`, `Pms.t.scenery`; drawn by `Soldat_scene` |
| *collider* | a circle that stops bullets | `Soldat_map.t.colliders` |
| *thing* | what lies on the map and can be picked up or carried: flags, kits, dropped weapons (`TThing`) | *to come* |
| *spark* | a short-lived particle for the eye: blood, smoke, shells (`TSpark`) | *to come* |
| *waypoint* | a node of the graph bots walk along | `Pms.waypoint` (read, not used yet) |
| *tick* | a step of the game: 60 a second (`DEFAULT_GOALTICKS`) | a frame of the Playground: `update`, 60 a second |
| *cvar* | a named setting (`net_port`, `sv_maxplayers`: `shared/Cvar.pas`) | a flag, `name=value` on the command line or after `?` in a URL |
| *smod* | the archive of the game's content (`soldat.smod`), read through PhysFS | files embedded as base64 (what is small and always needed), or got under a base, a folder or the web (`Soldat_assets`) |

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
| `Update_Frame` (`client/UpdateFrame.pas`), the server's loop (`server/ServerLoop.pas`) | `Soldat_update.tick` |
| `RenderFrame` (`client/GameRendering.pas`), OpenGL through `client/Gfx.pas` | `Soldat_view.view`, a list of the Playground's shapes |
| `client/Input.pas`, `client/ControlGame.pas`: SDL's events | `computer.keyboard`, `computer.mouse` |
| `TControl`, a soldier's keys this tick, set by the keyboard, a bot or the network | `Soldat_soldier.control`, in `Soldat_model.intent` |
| the window, the timer, the loop: SDL, `client/Client.pas` | `Playground_platform.run_app` |
| a client and a server built from `shared/` with `{$IFDEF SERVER}` | libraries: `src/game` linked by the game and, one day, by the server |

The gain in code comes mostly from here: no slot management, no
`{$IFDEF}`, and the window, the drawing, the sound and the sockets are
the Playground's.

## Units and coordinates

| | Soldat | Here |
|---|---|---|
| time | a tick, 1/60 s; speeds are per tick, accelerations per tick squared (`TimeStep := 1`) | the same: a frame is a tick |
| length | a pixel of its view, 640 across | the same; the camera's zoom makes 640 of them the screen's width |
| y | grows downwards | the same in the map and the game; the Playground's grows upwards: turned over when drawing (`Soldat_view.at`) and when reading the mouse (`Soldat_update.human`), nowhere else |
| gravity | `Grav = 0.06` a tick squared (`shared/Game.pas`), times each system's `GravityMultiplier` | `Soldat_soldier.grav` |

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

**Not the rigid-body solver.** TinySoldat's soldier was an upright box
in a `Physics.world` (`Solver`, `Contact`, `Broadphase`): nothing in
Soldat is a rigid body. The soldier is now the particle above, and
the `Physics.world` is gone, with its cost (a time proportional to the
map's walls, each frame: 2.6 ms on Arena2, now 0.02).

## The map and what touches it

| Soldat (`shared/PolyMap.pas`) | Here |
|---|---|
| `LoadMapFile` (`shared/MapFile.pas`) | `Pms.parse` |
| `TPolyMap.LoadData` | `Soldat_map.of_pms` |
| the sectors (`Round(Pos.x / SectorsDivision)`, never the outermost ring) | `Soldat_map.sector`: the file's own grid, Pascal's rounding |
| `PointInPoly` (the same side of the three edges), `PointInPolyEdges` (the inner side of the three perps) | `Soldat_map.in_wall`, `in_edges`: Soldat's two tests kept as they are, since they differ on an edge and the file's perps are the map author's. `Collide.point_in_polygon` is the same idea |
| `ClosestPerpendicular` (the nearest edge's perp, and how far), over `PointLineDistance` (`shared/Calc.pas`) | `Soldat_map.closest_perp`, `point_line_distance` (`Collide.nearest_on_outline` gives the point, not the perp) |
| `RayCast`: a segment against the sectors' polygons | `Soldat_map.clear`: the segment looked at every 4 units, each point in its sector's walls; `in_bullet_wall` for its use on one point |
| `LineCircleCollision` (`shared/Calc.pas`): a bullet's path against a collider | `Collide.segment_circle` |
| which kind stops what (`EXCLUDED1`, the `Team` and `Flag` tests of `RayCast`) | `Soldat_map.stops_soldier`, `stops_bullet` (no teams, no flags yet) |
| `Bounciness`: the length of a polygon's third perp | `Pms.polygon.perps.(2)` (not used yet) |
| `TVector2`, `Vec2Add`, `Vec2Subtract`, `Vec2Scale`, `Vec2Dot`, `Vec2Length`, `Vec2Normalize` (`shared/Vector.pas`) | `Vec2.add`, `sub`, `scale`, `dot`, `length`, `normalize` |

## The soldier

Read in `shared/mechanics/Sprites.pas` (`TSprite`),
`shared/mechanics/Control.pas` (`ControlSprite`) and `shared/Anims.pas`,
and ported: `Soldat_soldier` (the particle, the keys, the map),
`Soldat_anims` and `Poa` (the animations), `Soldat_ragdoll` (dead).

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

| Soldat | Here |
|---|---|
| the particle of `SpriteParts` | `x`, `y`, `vx`, `vy`, `fx`, `fy` in `Soldat_soldier.t`, stepped by Soldat's Euler (`euler`) |
| `Skeleton`, alive: 20 points placed from the animations | `skeleton`, placed each tick (`place_skeleton`), and `old_skeleton`, a tick before: kept, as there, since a tick's order shows it (it is placed before the map moves the particle) and a death needs both |
| `Skeleton`, dead: Verlet and constraints | `Soldat_ragdoll`: a `particle array`, `Particles.step`, `Particles.relax ~iterations:1` |
| a stick cut (a head, a leg shot off: `Constraints[i].Active := False`) | `Soldat_ragdoll.t.cut`: the sticks' numbers, left out of what `Particles.relax` is given (`holding`); which, by the health a hit left (`cuts`) |
| `Weapon`, `SecondaryWeapon: TGun`, `TertiaryWeapon` (the grenades) | `weapon`, `secondary : gun` (the table's row and four counters), `grenades` |
| `Control: TControl` (the keys and where the mouse is, in the map) | `Soldat_soldier.control` |
| `Position`: stand, crouch, prone | `stance` |
| `LegsAnimation`, `BodyAnimation`: a copy of an animation with its current frame | `Soldat_anims.playing`: which, its frame, its count |
| `OnGround`, `OnGroundPermanent` (the same, over two ticks) | fields of the soldier |
| `JetsCount`, from the map's `StartJet` | `jets`, from `Soldat_map.t.jet` |
| `Health`, `DeadMeat`, `RespawnCounter`, `CeaseFireCounter` | `Soldat_model.soldier`'s `health`, `dead`, `safe` |

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

| Soldat | Here |
|---|---|
| `CheckMapCollision` (a point of the soldier) | `Soldat_soldier.check_map`, with its friction rules |
| `CheckRadiusMapCollision` (the circle) | `check_radius` |
| `CheckMapVerticesCollision` (near a corner: a push of 1 away) | `check_vertices` |
| `CheckSkeletonMapCollision` (a dead body's points) | `Soldat_ragdoll.out_of_walls` (`Particles.keep_out` pushes to the nearest point of the outline; Soldat goes back where the point was, less its depth: kept as Soldat's) |
| what the deadly, hurting, healing and exploding polygons do (`HandleSpecialPolyTypes`) | `touched`, the kinds a tick met, and `Soldat_update.wall_damage` |

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

| Soldat | Here |
|---|---|
| `TAnimation.LoadFromFile` | `Poa.animation`; the files in `data/anims/`, packed into the program at build time (`Gen_anims`: the singles Soldat keeps them in, 180 KB) |
| `ParticleSystem.LoadPOObject` | `Poa.skeleton` |
| the 44 global animations, their speeds and loops (`LoadAnimObjects`) | `Soldat_anims.all`, `point`, `frames` |
| `TAnimation.DoAnimation` (a frame every `Speed` ticks; the last frame held, or back to the first) | `Soldat_anims.advance` |
| `LegsApplyAnimation`, `BodyApplyAnimation` (change only to another animation; never out of prone) | `Soldat_soldier.legs_apply`, `body_apply` |

**Aiming** (`Soldat_soldier.aim_skeleton`). The mouse's place in the map is in the soldier's controls.
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
`server/configs/weapons.ini`. Ported in step 4: `Soldat_weapons` (the
table), `Soldat_soldier` (the trigger, the reload, the change, the
throw), `Soldat_bullets` (what flies and what it does).

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

| Soldat | Here |
|---|---|
| `Guns: array[1..23] of TGun`, built in Pascal then read from `weapons.ini` | `Soldat_weapons`: `data/weapons.ini` carried in the program and read (`parse`, `of_ini`), 12 rows of `t` (the 10 primaries, the USSOCOM, the grenade); what is only in the Pascal (`ClipReload`, `FireMode`, the bullet's lifetime) beside it |
| the gun's counters (`FireIntervalCount`, `ReloadTimeCount`, `StartUpTimeCount`, `AmmoCount`) | `Soldat_soldier.gun`: `fire_count`, `reload_count`, `startup_count`, `ammo` |
| the trigger, the change, the reload's key, the shotgun's shells (`ControlSprite`, C:426-760), the counters at a tick's end (`TSprite.Update`, S:923) | `Soldat_soldier.weapons`, `weapon_timers` |
| `TSprite.Fire`: the direction (from the hand, point 15, to the cursor), the inaccuracy (moving, the weapon's spread; less crouched and prone), the bullet's velocity (the weapon's speed along it, plus half the soldier's); two for the Eagles, six for the shotgun and its kick; the body's recoil | `Soldat_soldier.fire`, `move_acc`, `recoil`: what leaves is put in `shots` |
| `Random` (the scatter) | `random : unit -> float`, given to `Soldat_soldier.tick`: the game's seed (`play.seed`, `Lehmer.next`), so a round replays |
| `TSprite.ThrowGrenade`: the `Throw` animation's frame is the throw's strength | `Soldat_soldier.throw_grenade` |
| a bullet: `TBullet`, and its particle in `BulletParts` (Euler, gravity 2.25 times `Grav`, damping 0.99) | `Soldat_model.bullet`, stepped at the end of `Soldat_bullets.update` |
| the bullet's styles (plain, grenade, shotgun, M79; and flame, punch, arrow, cluster, knife, LAW, thrown knife, M2) | `Soldat_weapons.style`: `Plain`, `Thrown`, `Pellets`, `Explosive`, `Arrow` (it stays in a wall for `ARROW_RESIST` ticks, harmless: `Soldat_bullets.arrow_resist`; the flaming one flies as it, without its fire); the others *to come*, or never |
| `TBullet.Update`: against the map, the colliders, the soldiers, the things, in that order, on the segment from where it is to where it will be; then it moves | `Soldat_bullets.update`; what is nearest along the way counts (`limit`) |
| against the map (`CheckMapCollision`): the segment sampled every 2.5 pixels, `PointInPolyEdges` in the sector's polygons; a ricochet (`V * 25/35 + Perp * 10/35`) or the end; a grenade bounces (0.88) | `against_map`, on `Soldat_map.sector`, `in_edges`, `closest_perp` |
| against a soldier (`CheckSpriteCollision`): `LineCircleCollision` with circles of radius 7 (`PART_RADIUS`) at 7 points of its skeleton (head 12, shoulders 11 and 10, hips 6 and 5, knees 4 and 3): which one says head, chest or legs | `line_circle` (ours: Soldat's gives where the segment *enters*, `Collide.segment_circle` its nearest point to the centre) at the same 7 points |
| through a body: a bullet fast enough goes on, slower (0.9, 0.75, 0.66) | the same rule, `through` what `HitBody` is |
| a push: the victim's velocity plus the bullet's times the weapon's `Push` (`NextPush`, a tick or more later: the ping) | `push`, at once; a body that dies of it leaves with it (`Soldat_ragdoll.of_soldier ~push`) |
| `HealthHit`, `Die`: the health taken, the death's kind by what is left (-90: a limb; -400: five), a kill counted (one less for oneself) | `Soldat_bullets.hurt`, `Soldat_ragdoll.cuts` |
| an explosion (`ExplosionHit`): within a radius (grenade 85, M79 64, cluster 35), damage `1 / (distance + 1)` times the weapon's, a push away, a kick to the ragdolls' points, and the other grenades near set off | `Soldat_bullets.explode`, `Soldat_ragdoll.blast` |
| the reload: at 0 ammo, a count-down holding the gun; `ClipOut` then `ClipIn` and `SlideBack` animations at 80% and 30% of it | `weapon_timers`, and in `control` |
| bink (being hit shakes one's aim) and recoil (0 for every weapon but in realistic mode) | *to come*: both move the cursor, which is the player's here |
| the bow and its flaming arrows (`Guns[BOW]`, `Guns[BOW2]`), nobody's choice: found on the map in a Rambomatch | `Soldat_weapons.id`'s `Bow` and `Bow2`, `is_bow`; `Reload_bow` its reload's animation; never thrown away |
| the knife, the chainsaw, the LAW, the fist, the flamer (`Guns[KNIFE]`...): the punch's 11th frame (`Control.pas:784`), the knife thrown (`:752`), the LAW's crouch (`Sprites.pas:4243`) | `Soldat_weapons.id`'s `Knife`, `Chainsaw`, `Law`, `Flamer`, `Thrown_knife`; styles `Melee`, `Flame`, `Flying_knife`; `Soldat_soldier.weapons`, `law_ready`; `secondaries` |
| the bonuses (`BonusStyle`, `Vest`; `HealthHit`, `Sprites.pas:3323`), their kits (`Things.pas:2041`) and when they appear (`ServerLoop.pas:378`); cluster grenades (`Bullets.pas:2321`) | `Soldat_model.bonus`, `soldier.bonus`, `vest`; `Soldat_bullets.hurt`, `burst`; `Soldat_things.Bonus`; `Soldat_update.tick`; the flag `bonus=N` |
| the rifle's butt, the stationary gun, a soldier burning | *to come*, or never |

## The things

`shared/mechanics/Things.pas`. A thing is a small skeleton of 2 or 4
points let loose (Verlet), which freezes once it lies still: a dropped
weapon is a stick (`karabin.po`), a kit a braced square (`kit.po`), a
flag a square (`flag.po`). 27 kinds: the three flags, 14 weapons
dropped, the bow, the medikit and the grenade kit, five bonus kits,
the parachute, the stationary gun. `CreateThing`'s 25 near-identical
cases are a table: for each kind its skeleton, its damping, its
gravity, its radius, how long it stays.

| Soldat | Here |
|---|---|
| `TThing`, its `Skeleton` | `Soldat_things.t`: a kind (`Weapon of gun`, `Medikit`, `Grenade_kit`), a `particle array`, its sticks: `Particles.step`, `relax` |
| `CreateThing`'s cases | `rifle` (a weapon's scale of `karabin.po`, its damping, its weight), `box` (`kit.po`), `physics` |
| `TThing.Update`, `CheckMapCollision`: a point in a wall back where it was less its depth; at rest (`StaticType`) when two points touched and it moves under 0.63 | `tick`, `out_of_walls`, `still` (Soldat's own rule, not `Particles.keep_out`, as for the ragdoll) |
| `TSprite.DropWeapon`, the throw in `CreateThing` | `Soldat_soldier.t.dropped` (thrown at the 19th frame of `Throw_weapon`, or `let_go` dying), made a thing by `Soldat_things.weapon` |
| picked up (`CheckSpriteCollision`, the server's): the nearest soldier within the thing's radius; a weapon only by one with empty hands | `Soldat_things.reach`, and the rule in `Soldat_update.tick` |
| where things appear: the map's spawn points whose team is above 4 (5 and 6 the flags, 7 grenade kits, 8 medikits, 9 to 13 the bonus kits, 14 the yellow flag, 15 the bow, 16 the stationary gun) | `Soldat_map.t.medikit_spawns`, `grenade_spawns`, `bow_spawns`; `Soldat_things.kits` (`SpawnThings`), `again` (`Respawn`, `SpawnBoxes`) |
| a flag (`OBJECT_ALPHA_FLAG`, `OBJECT_BRAVO_FLAG`): `flag.po`, four points; standing, its foot stopped and its top pulled up (16 times gravity); held, its first point on its holder's waist (point 8), its top pulled up (14 times) | `Soldat_things.kind`'s `Flag team`, `flag_shape`, `tick_flag`; `holder`, `in_base` (within 75 of its place: `Soldat_map.t.alpha_flag`, `bravo_flag`, the file's spawn points 5 and 6) |
| taken (`CheckSpriteCollision`): by the nearest living soldier within 19, past its first 90 ticks; its own team's sends it home at once unless it is there; left 25 seconds on the ground it goes home. A capture (`TThing.Update`): carried within 28 of its carrier's own flag standing at home | the rule in `Soldat_update.tick` (`flag`), `play.captures`, `play.news` (Soldat's big message), the sounds `Capture` and `Ctf_score` |
| the bow on the map (`OBJECT_RAMBO_BOW`: taken by empty hands only, 100 ticks after it appeared; let go by the dead; made again each second if neither on the map nor in hands, `ServerLoop.pas:642`) | `Soldat_things.bow`, `is_bow`: a weapon on the ground as any other, wider to reach (20) and one the bots walk to; `Soldat_update.bow`, and its tick |
| the parachute, the stationary gun; a thing hit by a bullet or an explosion | *to come*, or never |

## The sparks

`shared/mechanics/Sparks.pas`, the client's alone and for the eye
alone: a particle (Euler, a gravity of its own, damping 0.998) with a
life in ticks and a style, a bare number from 1 to 73: smoke, blood,
the shells and the clips each weapon drops, explosions, ricochets,
dirt, the jets' fire, the weather.

| Soldat | Here |
|---|---|
| `PlaySound` and `CreateSpark` where a thing happens, in the client's branches of the rules (`{$IFNDEF SERVER}`: about 300 calls) | the rules say what happened, as values (`Soldat_event.t`: a shot, a bullet in a wall, a sound); sparks and sounds are made of them after |
| `TSpark`, `SparkParts` (Euler, gravity / 1.4, damping 0.998) | `Soldat_sparks.t`, a list in the round's state; `tick` |
| a style, a number from 1 to 73 | `Soldat_sparks.kind`, 16 cases (the numbers beside them in the `.ml`) |
| each `CreateSpark` (a shot's shell, a hit's blood, a wall's chips, an explosion's three, the jets' fire) | `Soldat_sparks.of_event`, with their numbers |
| `Random`, for how far each flies | a seed of the sparks' own (`play.spark_seed`), apart from the game's: with or without them, the same round |
| `CheckMapCollision` (a shell bounces, clinks, is gone at its sixth; blood leaves a splat) | in `tick` |
| `r_maxsparks` (557) | `Soldat_sparks.most` (558; 150 in a browser), the flag `sparks=N` |
| the camera shaken by an explosion (in `TSpark.Update`) | `Soldat_sparks.wobble`, added to the camera |
| `TSpark.Render`: a picture, an alpha by the life left, a scale, a turn | `Soldat_sparks_view`: `bitmap |> rotate |> fade |> move`; a tint is a picture made once |
| the weather, shredded clothes, a helmet shot off, the cigar, a burning soldier, a hot shell's smoke | *to come*, or never. The Playground's `Juice` (`tiny_libs.juice`) was not needed |

## The rules, and the bots

| Soldat | Here |
|---|---|
| the modes (`GAMESTYLE_*`): deathmatch, pointmatch, teammatch, capture the flag (the default), rambo, infiltration, hold the flag | `Soldat_model.mode`, all seven; the map's own (`mode_of`: capture the flag where it has the two flags' places) or the flag `mode=` (`mode_words`) |
| the yellow flag (`OBJECT_POINTMATCH_FLAG`), a Pointmatch's doubled kill (`Sprites.pas:1705`), the points time gives in Hold the Flag and Infiltration (`ServerLoop.pas:598`), Infiltration's 30 for the objective (`Things.pas:879`) | `Soldat_things.yellow` (`Flag 0`), `Soldat_update.tick`; `play.captures` holds the teams' points |
| the aim's cursor (`InterfaceGraphics.pas:2283`: `interface-gfx/cursor`, scaled by the inaccuracy; the menu's arrow otherwise), the system's hidden | `Soldat_view.view_cursor`; `Playground_platform.set_cursor Hidden` in the main |
| the minimap (`MapGraphics.pas:774`: the map's polygons untextured, its width and height making 260 of 640; `InterfaceGraphics.pas:2492`: its dots; F3, not shown at first) | `Soldat_scene.minimap` (rastered once, kept), `Soldat_view.view_minimap`, `model.minimap` |
| the kill console and the scores' table (`InterfaceGraphics.pas`), the weapons' interface pictures (`interface-gfx/guns/`) | `play.log`, `soldier.deaths`; `Soldat_view.view_log`, `view_board` (Tab or b), `icon` |
| a Rambomatch's rules: while somebody is Rambo the others do nothing to each other (`HealthHit`, `Sprites.pas:3326`); a kill counts if the bow made it or Rambo died of it (`Die`, `:1785`); the bow gives a health back every 3 ticks (`:1276`); first to 30 (`sv_rm_limit`) | `Soldat_bullets.hurt` (its world's `rambo`), `Soldat_model.rambo`, `rambo_limit`, `Soldat_update.tick` |
| the bots in a Rambomatch (`AI.pas:587`, `:613`, `:992`): Rambo seen is the target; who has not the bow fires at nobody else; near the bow, the weapon is thrown away | `Soldat_bots.control` |
| a team (`Player.Team`: Alpha 1, Bravo 2), its colour (`$D20F05`, `$151FD9`), its spawn points, its kills or its flags (`TeamScore`), the limits (`sv_tm_limit` 60, `sv_ctf_limit` 10) | `Soldat_soldier.t.team`, `Soldat_model.team_shirt`, `Soldat_map.t.alpha_spawns` and `bravo_spawns`, `Soldat_model.score`, `team_limit`, `capture_limit`; `Soldat_update.winner` |
| friendly fire off (`HealthHit` leaves at once for one's own team's bullets) | `Soldat_bullets.hurt` |
| a team's walls (`TeamCollides`: polygons 10 to 17, a team's bullets or a team's players) | `Soldat_map.stops_soldier ~team`, `stops_bullet ~team` |
| the bots in teams (`ControlBot`): the nearest in sight of its own team is no target and hides who is behind; a path a team (`PathNum`), the other's with the flag; it runs home from who has not its flag; a flag gone to by five rules | in `Soldat_bots.control` |
| the other team's own pictures (`gostek-gfx/team2/`: only the head differs), the flag's cloth as a textured quad (`PolygonsRender`), the flag thrown (the space bar), the walls for who carries a flag, respawn in waves | *to come* |
| a round's end: a kill limit (10) or a time limit (10 minutes), then the scores for 320 ticks, then the next map | `Soldat_model.kill_limit`, `time_limit`, `play.time_left`, `Soldat_update.winner`; then the same map again: the next map *to come* |
| respawn: 180 ticks after dying (in team modes, in waves), at a spawn point taken by chance (`RandomizeStart`) | `Soldat_update.respawn_ticks`, and the game's chance |
| the tick's order (`server/ServerLoop.pas`): the soldiers' particles stepped, each soldier updated (its keys, or its bot's), each bullet updated (its collisions), the bullets' particles stepped, each thing updated; the client adds the sparks | `Soldat_update.tick`, in that order |
| a bot (`shared/AI.pas`, `ControlBot`): it only presses keys and moves the mouse, in the same `TControl` a player fills | `Soldat_bots.control`: a `Soldat_soldier.control` |
| `Brain`: its target, who shot it, its waypoints, its counters | `Soldat_model.brain`, one a bot in `play.brains` |
| its way: no path-finding. It goes to the nearest waypoint, picks one of its connections at random, and holds the keys that waypoint says (left, right, up, down, jets): the map's author walked it | `Soldat_map.t.waypoints` (`Pms.waypoint`), `Soldat_bots.closest` (`FindClosest`). elm-playground's `ai` (`Sense`, `Bot`) is not what Soldat's bots are made of (they read the round at once); one bot is kept on it as an example, `Soldat_engine_bot` (the flag `ai=engine`) |
| its target: the nearest enemy its head sees (a ray on the map, 651 pixels at most); who shot it, before any other (`PissedOff`) | `sees`; `soldier.hit_by`, set by `Soldat_bullets.hurt` |
| its fight (`SimpleDecision`): by how far the target is across, in 8 distances: back away, stop and crouch, jump, fire always or one tick in two or in four | `bucket` (`CheckDistance`), and the cases in `control` |
| its aim: where the target is going, raised for the distance, with an error up and down of at most its `Accuracy` in pixels | the same |
| `Random`, all along | the game's `random`, as a shot's scatter |
| its character, a `.bot` file: accuracy, favourite weapon, how often it throws a grenade, whether it camps, whether it shoots the dead | `Soldat_bots.character`, `characters`: `data/bots/`, carried in the program |
| going to a kit (`GoToThing`, a thing's `Interest`), running from a grenade, the jets when falling | in `control` |
| hiding behind a collider (`ColliderDistance`), the fists, the teams' paths, the difficulty, the chat | *to come*, or never |

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
| the camera's rule above | `Soldat_update.follow`: a point of the model, three lines; `Camera2d.view` shows through it |
| 640 by 480, y down | the Playground's screen is 1000 by 1000, y up: a zoom of the screen's width over 640 (`Soldat_model.zoom`), y turned over |
| the sky: two colours, from the top to the bottom of the map's range (25 sectors each way), the screen's width | bands of `rectangle`s, 64 of them (no gradient in the Playground) |
| a polygon: the map's texture (512 by 512, repeated), each corner with its u, v and its colour, which multiplies the texture | `Soldat_raster.triangle`, into a tile of pixels: the same arithmetic a graphics card does (barycentric weights, the texture's pixel times the blended colour). **Nothing** in the Playground draws a textured or shaded triangle: the game does, once, and shows the pixels (`Soldat_scene`, tiles of 256 units and 512 pixels, made as the camera comes near). In flat colours (the corners' mean times the texture's mean, `Texture_tints`) until a tile is ready, and at graphics 1 and 2 |
| the edges (`r_smoothedges`): along each outer edge of the map, a strip of `textures/edges/`, to soften it | *to come* |
| a transparent polygon (alpha 0): a wall one cannot see | not drawn |
| a prop: its picture (`scenery-gfx/`), placed, turned, scaled each way, tinted, with an alpha, in one of three layers; pure green is transparent | `Soldat_raster.sprite`, into the same tiles: Soldat's own matrix (turned about the point one unit under its corner), read backwards, a pixel of the tile to its place in the picture. Green made transparent by `Soldat_assets` |
| the soldier: 15 pictures and more (`gostek-gfx/`: `morda` the head, `klata` the chest, `biodro` the hip, `udo` the thigh, `noga` the lower leg, `stopa` the foot, `ramie` the arm, `reka` the forearm, `dlon` the hand), each hung between two points of the skeleton (the head from 9 to 12, a thigh from 6 to 3...), turned along them, some stretched (the thighs, the forearms), tinted the shirt's, the trousers', the skin's or the hair's colour, mirrored when facing left | `Soldat_gostek`: its table (`parts`, from `GostekGraphics.inc`), `place` (`DrawGostekSprite`'s matrix, as where the picture's middle goes and the angle), `bitmap w h picture |> rotate |> move`. A picture per (part, tint, side), made once (`picture`). *To come*: the hair, the vest, the chain, the blood, the second team |
| the pictures are 4.5 times bigger than drawn (`mod.ini`'s `DefaultScale`): a head of 27 pixels is 6 units | `Soldat_gostek.size`: the `w` and `h` given to `bitmap` |
| the weapon in the hands (between points 16 and 15), its clip, its fire; the other on the back (5 to 10) | `Soldat_gostek.in_hands`, `on_back`: parts like the others, from a table of the weapons' lines (`look`); their pictures are files (`Soldat_assets`), the pistol's the program's |
| a bullet's trail, a grenade's picture, an explosion's 16 pictures | `Soldat_view.view_bullet` (a streak; `frag-grenade`, `m79-bullet`), `view_explosion` (a disc: the pictures come with the sparks) |
| the interface (`client/InterfaceGraphics.pas`): bars for health, ammo, jets (a picture cut at a fraction), the cursor, the kills' console, the chat, the scores, the weapons' menu, the minimap | `Soldat_view.view_interface`, `view_menu`: shapes outside the camera's group, `rectangle`s for the bars, `words` for the texts and the menu (chosen by keys). *To come*: its pictures, the cursor, the console, the minimap |
| an atlas of pictures, colour keys, premultiplied alpha, mipmaps (`client/Gfx.pas`) | the Playground's backends: Cairo, its own rasterizer, or SVG in a browser |

## The sound

`client/Sound.pas`: 163 samples (`sfx/*.wav`), played through OpenAL.
A sound has a place: it is heard at `1 - distance / 750`
(`SOUND_MAXDIST`) of its volume, nothing beyond, and to the left or
the right by how far it is across. Three loop (the jets, the chainsaw,
the flamer); the rest play once.

| Soldat | Here |
|---|---|
| `SFX_*`, 163 numbers, and their files (`LoadSounds`) | `Soldat_sfx.t`, the 48 the game plays (89 files: a step is one of four), `file` |
| a sample loaded | `Soldat_sound.sound`: its bytes from the content (`Soldat_assets`, `sfx/NAME.wav`), `Audio.wav`, frozen with `Audio.recorded`, kept. `Audio.wav` reads 16-bit only and 38 of the 82 are 8-bit: `Soldat_sound.to_16_bit` rewrites those first |
| `PlaySound (sample, place)` in the rules | a `Sound` event; the tick's are `play.sounds`, played by `Soldat_update.update` |
| `FPlaySound`: `1 - distance / 750` of its volume from the listener, nothing beyond; its side | `Soldat_sound.heard`, then `Audio.play (sound |> Audio.louder volume |> Audio.pan side)` |
| a shot or an explosion far away, heard as another sample that grows with the distance (`SFX_DIST_*`) | `Soldat_sound.play`, the same rule |
| a loop on a channel, stopped (the jets) | `Audio.loop name sound`, `Audio.stop name`: `Soldat_sound.jets`, one name a soldier |
| 128 sounds at once | at most 12 started a tick (5 in a browser), the loudest; the mixer has 32 (`Mixer.max_playing`) |
| in a browser | the same mixer, through the page's `AudioContext`; the files fetched while the title shows (`Soldat_sound.warm`) |
| a bullet's whizz past the listener, the minigun's start and end, a collider hit, the hum after a grenade (and its muffling of everything), the chat's and the menu's | *to come* |

## Files and content

| Soldat | Here |
|---|---|
| `soldat.smod`, an archive read through PhysFS; a map's own archive mounted over it | a file embedded as base64 (`scripts/build/file_to_base64_ml.ml`), what is small and always needed: a map, the skeleton, the animations, the weapons' numbers |
| | or got when wanted, the rest (99 maps, 95 MB of textures and scenery): `Soldat_assets`, over `Audio.fetch path_or_url k`, which gives a file's bytes at once natively and a URL's later in a browser |
| PNG, BMP, GIF, through stb_image | `Png.decode` (elm-playground's) and `Bmp.decode` (ours) to an `Rgba_image.t`, natively; plain pixels in a browser (`Soldat_assets.picture`) |
| a colour key (pure green, or black) made transparent when loading | `Pixels.map` on the decoded picture |

## What the Playground lacks

Found while reading both sides; each is a place where either the game
does with less, or elm-playground gains something (there, then
required here). In the order they would hurt:

| Lacking | Needed for | Without it |
|---|---|---|
| a textured triangle, shaded by its corners | the map as Soldat draws it | drawn by the game into pictures (`Soldat_raster`, `Soldat_scene`): done, without changing the Playground |
| an image tinted | the soldier's shirt, trousers, skin; the props' colours | a picture made per tint, once: done for the soldier (`Soldat_gostek.picture`) |
| an image mirrored | a soldier facing left | Soldat has a second picture for most parts; the others are made turned over, once: done |
| an image's `fade` on Cairo (it is ignored there; the software platform and the browser do it) | a soldier fading in, the props' alpha | the alpha put into the pixels |
| more than 32 pictures kept in a browser (each new `bitmap` is encoded as a PNG; only the last 32 were kept, by age) | three soldiers use up to 50, the textured map 14 tiles more: 64 in a frame | mended in elm-playground (after 0.3.5): a table with a budget of pixels, as its Cairo platform has. It was 9 frames a second, it is 60 (`docs/architecture.md`) |
| part of an image | the interface's bars, an atlas | rectangles; a picture each |
| a BMP decoder | part of the scenery, the edges | `Bmp`, here: 24 bits and 8 bits with a palette, which is all of Soldat's |
| a PNG decoder that is fast in a browser (`Png.decode` compiled by js_of_ocaml is quadratic: 14 s for 257 KB) | the textures and the scenery, fetched | the website's pictures as plain pixels, made when it is built (`Gen_assets`, `name.rgba`): twice the bytes, nothing to decode |
| 8-bit WAV | 38 of the 82 sounds played | rewritten as 16-bit when first played (`Soldat_sound.to_16_bit`) |
| a picture tinted when drawn | a spark's two colours, the jets' | a picture a tint, made once |
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
