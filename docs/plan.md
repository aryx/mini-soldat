# The plan

From three toy soldiers on Soldat's maps to Soldat, by the approach in
`CLAUDE.md`: Soldat's Pascal adapted to OCaml and to the Playground,
in far less code, with the same feel in the hands, on elm-playground's
physics. What each piece of Soldat is here, or will be, is
`docs/notes_soldat_in_playground.md`; this is the order.

Written on 2026-10-02 after reading the Pascal (about 20,000 lines of
`shared/` and `client/`) and the Playground's API side by side. To be
kept true: a step done is moved to "Done" with what it turned out to
be.

## Done

- The project: three programs (Cairo, software, browser), the website,
  the tests, the CI.
- `mini-soldat-server`: a lobby with rooms, over WebSocket. Nothing in
  the game talks to it yet.
- Soldat's maps: any `.pms` read and played on, in flat colours, a
  camera following the player. Arena2 carried in the program.

What is still the toy's, and so what the steps below replace: the
soldier (a rigid box, speeds invented, the map made twice as big to
fit it), its one gun and its grenades, its ragdoll of 9 points, its
bots, every picture.

## The rules of the road

1. **Each step ends with a game one can play**, on the desktop and on
   the website, and with its tests. No step leaves the game broken for
   the next to mend.
2. **From the Pascal, not from memory**: the constants, the order of a
   tick, the frame numbers, the corner cases are read there and said
   where they came from. The *server's* branches are the rules (on a
   client, damage is multiplied by zero); the client's are what is
   seen and heard.
3. **Soldat's units from step 1 on**: a tick is a frame, a unit is a
   unit (`Soldat_map.scale` goes), gravity is 0.06. y is turned over in
   one place, when reading a file and the mouse and when drawing.
4. **`src/game` stays pure**, without drawing and without the keyboard:
   a tick takes one `intent` per soldier, wherever it comes from (the
   keys, a bot, the network). That is what lets the server run the
   game in step 8, and what the tests call.
5. **No `Random` in a tick**: Soldat draws its bullets' spread from
   `Random`. Here a seeded generator in the model (`tiny_libs.random`),
   so that a game replays the same, in a test and across a network.
6. **What is left out is said**: most of the Pascal's lines are the
   network, the server's bookkeeping, the bots' chat, the sparks, the
   idle animations (a cigar lit, a helmet taken off). Each step names
   what it leaves for later.
7. **elm-playground is changed only when the game cannot do without**,
   there, with its own tests; the list of what it lacks is at the end
   of the note.

## The steps

### 1. The soldier moves as Soldat's does

*What one feels*: running, the wind-up before a jump, the side jump,
the crouch, going prone and crawling, the roll, the backflip, the
jets and their fuel, standing still on a slope and sliding on ice.
Drawn as a stick figure: the skeleton's own sticks.

- The particle: Soldat's Euler step, its forces, `MAX_VELOCITY`.
- The animations: a reader of `.poa` and `.po` (44 animations, the
  gostek's 24 points and 30 sticks), their speeds and loops as in
  `Anims.pas`; the two animations a soldier has (legs, body), their
  frames numbered from 1. The files are 1.3 MB of text: turned at
  build time into a compact table the program carries.
- The keys: `ControlSprite`'s chain of cases, in its priority, with
  its constants; `Position` (stand, crouch, prone); the direction from
  the cursor. Soldat's keys: left, right, jump, crouch, prone, jets.
- The collision: the feet, the head, the circle and the corners
  against the polygons of the point's sector (`Pms`'s sectors, used at
  last), the friction rules; ice and bouncy polygons, since they are
  in that code.
- The camera's own rule, and Soldat's view: 640 by 480 units.
- Gone: the `Physics.world`, the soldier's box, the map made twice as
  big, and with them the time each wall costs each frame.
- Kept from the toy for now: its gun (re-scaled) and its bots (they
  press the new keys). Its grenades wait for step 4.
- Left out: the idle animations, the parachute, the dangling chain.

*Checked by*: numbers worked out by hand from the Pascal (the fall's
top speed, a run's, how high a jump goes, how long the fuel lasts) as
tests; all 99 maps still played on (`Frame_bench`), now in a time that
does not grow with the map; and by playing it next to the real game.

### 2. The soldier looks as Soldat's does, alive and dead

*What one sees*: the gostek, its limbs' pictures on its skeleton, in
its colours, turning its head and its arms to the cursor, facing left
or right; shot, a ragdoll of its own skeleton, a leg or the head off
on a hard hit.

- The table of parts (`GostekGraphics.inc`): which picture between
  which two points, its pivot, whether it stretches, its tint.
- The pictures: the 48 of `gostek-gfx/` needed, tinted and mirrored
  once into the pictures drawn.
- Aiming: the head and the two hands placed by the cursor.
- Death: the skeleton let loose (`Particles.step`, `relax`, `keep_out`
  with the sector's polygons), the sticks cut by the hit's strength;
  respawn, and its 90 ticks without fire.
- **The first place elm-playground may have to change**: a browser
  keeps only the last 32 pictures given to `bitmap`, and three
  soldiers are past that. To measure first; then either the limit
  raised there, or the pictures given by URL.
- Left out: the vest, the hair and the helmets, the blood on the
  limbs, the other team's pictures.

*Checked by*: a frame compared, point for point, with where the Pascal
puts the skeleton for a given animation frame; frames dumped and
looked at.

### 3. The map looks as Soldat's does

*What one sees*: the map's texture on its polygons, shaded by their
corners, the soft edges, the scenery in its three layers, the sky as
Soldat grades it.

- The decision this step starts with: a textured, shaded triangle is
  not something the Playground can draw. Either it gains one (a new
  shape, in its three backends: the real fix, and useful to it), or
  the map is drawn once by our own code into pictures shown with
  `bitmap` (nothing to change there; big pictures, whose cost on Cairo
  and in a browser is to be measured). A day of measuring before
  choosing.
- The scenery: the props with their pictures, turned, scaled, tinted,
  green made transparent; the BMP ones converted once.
- The content no longer fits in the program: a map's texture is half a
  megabyte. So here the files are fetched (a folder beside the program
  natively, the website's in a browser), with a list of what there
  is, and any of the 99 maps can be chosen, in a browser too.
- The polygons' other kinds: deadly, hurting, healing, lava; the
  colliders.

*Checked by*: Arena2 and ctf_Ash next to the real game's screenshots.

### 4. The weapons

*What one feels*: Soldat's ten primaries and four secondaries with
their numbers, the reload, the two-shot Eagles, the shotgun's kick,
the Barrett's wait, grenades by how long the throw is held, the M79;
being hit and pushed, a headshot.

- The table: `weapons.ini` read; the gun's counters.
- Firing: the direction from the hand, the inaccuracy (moving, the
  weapon's spread, bink), the bullet's speed with half the soldier's.
- The bullet: its Euler step, against the map (the ricochet), the
  colliders, the soldiers (7 circles: head, chest, legs), damage as
  speed times the weapon's times the place's, going through a body,
  the push; the explosion and its falloff.
- Changing weapon, throwing it away, reloading, with their animations;
  the weapon drawn in the hands, its clip, its fire.
- The interface: health, ammo, jets, grenades; the menu to choose a
  weapon in.
- Left out: the knife, the chainsaw, the LAW, the flamer, the bow, the
  stationary gun, realistic mode and its recoil.

*Checked by*: damage worked out by hand (an Eagle's bullet in the
chest is 19 x 1.81 x 0.95) as tests; a fight replayed from its seed.

### 5. A deathmatch as Soldat's

- The things: a weapon dropped, the medikits and the grenade kits
  where the map puts them, picked up.
- The rules: the kill limit and the time limit, respawn after 3
  seconds, the scores, the next map.
- The bots: Soldat's (`ControlBot`), along the map's waypoints, with
  the 16 characters of its `.bot` files; the toy's go.
- Left out: the bonus kits, the bots' chat.

### 6. Heard, and alive

- The sounds: the 163 samples, heard by where they are; the 8-bit
  ones converted.
- The sparks: blood, shells and clips, smoke, the explosions, the
  ricochets, the jets' fire, the dirt.

### 7. Teams and flags

Team deathmatch and capture the flag (Soldat's default mode): the
flags as things, the teams' spawn points and polygons, the other
team's pictures, friendly fire. Then, if wanted, the other modes.

### 8. Over the network

As `docs/network.md` has it: the lobby's screen in the game; a room
that is a game the server steps; the game's messages; then the choice
it describes (the server owning the game, or each client its own
soldier, as Soldat). Rule 4 above is what makes this a step and not a
rewrite. It can be started earlier, beside the others, as far as the
lobby's screen.

## The order, and what could change it

1 comes first whatever else: every later step stands on Soldat's
units and its soldier. 2 follows because a stick figure is hard to
judge a feel by. 3 and 4 can swap: 3 first if the look matters most
(and it settles how content is fetched, which 4's pictures and 6's
sounds then use), 4 first if the play does.

## To decide

- **A budget of lines**, as mini-chrome has. The Pascal behind steps 1
  to 7 is about 39,000 lines (`shared/` without its network, and
  `client/`); a first guess for all of `src/` here is 10,000.
- **Step 3's choice**: a textured triangle in elm-playground, or the
  map drawn into pictures by the game.
- **3 before 4, or 4 before 3.**
- **A reference to compare with**: playing the real game beside ours
  is the check of a feel. Building OpenSoldat here (Free Pascal) and
  making it print a soldier's position each tick for given keys would
  turn "it feels the same" into a test; it is a day's work that is not
  the game.
- **The content on the website**: fetching maps, textures and sounds
  means publishing Soldat's content (CC BY 4.0, credited) under
  `docs/`, about 100 MB if all of it; or only what a few maps need.
