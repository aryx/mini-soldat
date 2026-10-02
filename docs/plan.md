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

- **Step 1, the soldier moves as Soldat's does** (2026-10-02).
  `Soldat_soldier`, adapted from `Sprites.pas` and `Control.pas`: the
  particle and Soldat's Euler step, the keys as forces and animations
  in `ControlSprite`'s order (run, jump, jump sideways, crouch, prone
  and crawl, roll, backflip, jets), the collision by points in the
  map's own sectors with its friction rules, ice and bouncy polygons.
  `Soldat_anims`: the 44 animations and the gostek's skeleton, packed
  into the program at build time. The game is in Soldat's units, y
  downwards; a soldier is drawn as its skeleton's sticks, and dead is
  that skeleton let loose; Soldat's camera and its 640 units across.
  What it turned out to be, beyond what was planned:
  - a tick costs 0.02 ms on Arena2 (it was 2.6) and 0.1 on the biggest
    map (12.5): the sectors;
  - the file's sectors list a wall where its *outline* is, not its
    inside: a soldier is stopped at a wall's skin, as in Soldat, and
    the grid could not have been made again here without changing
    that;
  - the toy's screen (`map=toy`) went: nothing of it fits Soldat's
    units. The tests have a floor made by hand instead;
  - the ragdoll is already the real skeleton (planned for step 2),
    without the cut sticks; the spawn protection came with it, the
    bots being deadly otherwise;
  - the numbers checked are worked out by hand from the Pascal's
    formulas, and agree: a fall's top speed 5.94 a tick, a run's 2.9,
    a jump on the ground for its first 8 ticks then 85 up. Whether
    that *is* Soldat still wants the real game beside it: see "To
    decide".
  Left out, as planned: the head and the arms turned to the cursor,
  the idle animations, the parachute, the chain and the hair, what
  deadly and hurting polygons do, the background polygons.

- **Step 2, the soldier looks as Soldat's does** (2026-10-02).
  `Soldat_gostek`, adapted from `GostekGraphics.pas` and its table:
  the 16 parts of a soldier's body and its helmet, each a picture of
  Soldat's (`data/gostek-gfx`) hung between two points of the
  skeleton, turned along them, its pivot on the first, the thighs and
  the forearms stretching, mirrored when it faces left (a second
  picture, or its own turned over); tinted the shirt's, the trousers'
  and the skin's colours; the jets' feet when it flies; the pistol's
  picture in its hands. The head and the hands turn to the cursor
  (`Soldat_soldier.aim_skeleton`), and a bullet leaves from the hand.
  Dead, the same pictures on the skeleton let loose. The pictures are
  packed into the program at build time as their pixels (82 KB), and
  each one needed is tinted and turned over once.
  What it turned out to be:
  - the Playground neither tints nor mirrors a picture: each is made
    once per colour and side, as planned. Three soldiers use 25 to 29
    pictures at a time and 52 in all;
  - **in a browser** that is just under the 32 pictures elm-playground
    keeps: 55 to 60 frames a second, with a pause of up to 50 ms when
    a soldier turns (its other side's pictures are made, and push the
    oldest out). It will not hold with more soldiers: see "To decide";
  - a head or a leg shot off (a stick cut) did not come: no weapon
    yet hits hard enough (it takes a health under -90, and the pistol
    takes 30 a bullet). It goes with the weapons, step 4.
  Left out, as planned: the hair, the vest, the chain, the blood on a
  wounded soldier's limbs, the second team's pictures.

- **Step 3, the map looks as Soldat's does** (2026-10-02). The choice
  it started with: the map is drawn by the game, once, into pictures
  (`Soldat_raster`: textured triangles shaded by their corners,
  Gouraud's way, and the scenery's sprites placed as Soldat places
  them), in tiles of 256 units made as the camera comes near and shown
  with `bitmap` (`Soldat_scene`): the map's texture on its polygons,
  its scenery in its three layers. Nothing of elm-playground changed
  for it. The content is files now (`Soldat_assets`): `data/` natively,
  or any folder laid out as Soldat's (the flag `base`, e.g. a checkout
  of opensoldat-base: all 99 maps with their textures and scenery,
  `map=ctf_Ash` by name); `assets/` beside the page in a browser.
  Until a file has come and a tile is drawn, the flat colours of
  before are shown, and with no file at all they are what one gets.
  Also: the deadly, hurting, healing and exploding polygons act on a
  soldier's health; the colliders stop bullets; a `.bmp` reader for the
  scenery never redrawn as PNG (`Bmp`).
  And the key g (the flag `graphics`): the game as each step drew it,
  1 the skeletons on flat colours, 2 the soldiers' pictures, 3 the
  map's texture and scenery.
  What it turned out to be:
  - **in a browser** two things of elm-playground's web platform stood
    in the way. Its PNG decoder compiled to JavaScript takes a time
    that grows as the square of the file (14 s for 257 KB): the
    website's pictures are turned into plain pixels when it is built
    (`Gen_assets`, `name.rgba`). And it kept the last 32 pictures given
    to `bitmap`, where the textured map with three soldiers is 64: 9
    frames a second. That one was mended there, the first change this
    game asked of elm-playground: a table with a budget of pixels, as
    its Cairo platform had since the same day (60 frames a second;
    `docs/architecture.md` has the story and a toy that shows it). It
    is in elm-playground after 0.3.5: built with an older one the
    game is the same, and slow in a browser at graphics 3;
  - the software platform draws big pictures slowly: `mini-soldat`
    (Cairo) is the one to play with.
  Left out: the soft edges along the map's outline (`textures/edges/`),
  what a polygon's kind does to a bullet (a ricochet: step 4), animated
  scenery (none in Soldat's own content), the website's other maps
  (only Arena2's content is there: "To decide").

What is still the toy's, and so what the steps below replace: the
soldier's gun (one, with the USSOCOM's numbers and its picture) and
its bots.

## The rules of the road

1. **Each step ends with a game one can play**, on the desktop and on
   the website, and with its tests. No step leaves the game broken for
   the next to mend.
2. **From the Pascal, not from memory**: the constants, the order of a
   tick, the frame numbers, the corner cases are read there and said
   where they came from. The *server's* branches are the rules (on a
   client, damage is multiplied by zero); the client's are what is
   seen and heard.
3. **Soldat's units and coordinates**: a tick is a frame, a unit is a
   unit, gravity is 0.06, and y goes downwards, in `src/map` and
   `src/game` alike: the Pascal's signs and numbers are kept as they
   are. y is turned over in two places only, both the Playground's
   side: the picture (`Soldat_view.at`) and the mouse
   (`Soldat_update.human`).
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
- A head or a leg off on a hard hit: the ragdoll's sticks cut by the
  hit's strength (a health under -90, under -400), which an M79 or a
  grenade reaches.
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

1, 2 and 3 came first: Soldat's units and its soldier, then its look,
which settled how content is fetched (4's pictures and 6's sounds use
it). 4 is next: the play.

## To decide

- **A budget of lines**, as mini-chrome has. The Pascal behind steps 1
  to 7 is about 39,000 lines (`shared/` without its network, and
  `client/`); a first guess for all of `src/` here is 10,000.
- **A reference to compare with**: playing the real game beside ours
  is the check of a feel. Building OpenSoldat here (Free Pascal) and
  making it print a soldier's position each tick for given keys would
  turn "it feels the same" into a test; it is a day's work that is not
  the game.
- **The version of elm-playground required**: the website wants the
  one after 0.3.5 (its web platform keeping every picture: step 3).
  `dune-project`, `configure` and the Dockerfile still say 0.3.3, which
  builds; to raise once that change is in a tagged version.
- **elm-playground's PNG decoder in a browser**: `Png.decode` compiled
  by js_of_ocaml takes 26 ms for 4 KB, 94 ms for 35 KB, 14.5 s for
  257 KB: quadratic, where natively it is instant. Worked around here
  (pixels instead of PNG on the website, 2.3 MB for Arena2 where the
  PNG are 1.2), but worth mending there: it would let the website
  serve Soldat's files as they are.
- **The content on the website**: fetching maps, textures and sounds
  means publishing Soldat's content (CC BY 4.0, credited) under
  `docs/`, about 100 MB if all of it; or only what a few maps need.
