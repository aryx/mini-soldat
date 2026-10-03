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

- **Step 4, the weapons** (2026-10-02). `Soldat_weapons`: Soldat's
  own `weapons.ini` read (carried in the program), the ten primaries,
  the USSOCOM and the grenade. In `Soldat_soldier`, adapted from
  `ControlSprite`, `TSprite.Fire`, `ThrowGrenade` and the weapon's part
  of `TSprite.Update`: a weapon in the hands and one on the back, the
  trigger (held, or once a pull), the clip and its reload with their
  animations, the shotgun loaded shell by shell, the Barrett's and the
  minigun's wait, the scatter by how one moves and stands, the two
  Eagles, the six pellets and their kick, the recoil animations, the
  change of weapon, a grenade thrown harder the longer it is held.
  `Soldat_bullets`, adapted from `Bullets.pas`: a bullet against the
  map (the ricochet), the colliders and the soldiers' seven circles,
  the nearest first; damage as speed x Damage x the place's; the push;
  going through a body; weaker beyond 500 and 900 units; a grenade
  bouncing; the explosion, its falloff, its push, the grenades it sets
  off, the dead thrown. `Soldat_ragdoll`: the sticks a hard death cuts
  (a head, a thigh; five at -400). Drawn: each weapon in the hands with
  its clip and its muzzle's fire, the other on the back, a grenade, an
  explosion (a disc); an interface (health, ammunition, jets,
  grenades) and Soldat's menu of weapons, by keys (1 to 9 and 0) on
  the title and while dead. The keys: R, Q, E. A seed in the round's
  state gives the scatter: no `Random`, a round replays.
  What it turned out to be:
  - the damage worked out by hand before reading closely was wrong
    four times, and the tests said so: the Barrett's modifiers are all
    1 (245 anywhere, not 232 in the chest); a soldier standing on the
    ground is held against the shotgun's kick, which is for the air;
    an explosion cuts limbs only within 1.7 units (it strikes "point
    1", so it is all five or none): a grenade that lands near kills
    and leaves the body whole;
  - where the Pascal is not followed. A bullet that ends in a wall
    there explodes at once and is tested against the soldiers after: an
    M79 on a soldier against a wall explodes twice; here what is
    nearest counts, once. And a push is felt at once (there a tick or
    more later, by the ping), so a body killed by a blast is given the
    blast's push, as one sees there;
  - the weapons' pictures (50, 400 KB of pixels) are files, asked when
    drawn (`Soldat_assets`), not packed in the program: the program
    stays at 610 KB in a browser; only the pistol's are carried;
  - a tick costs what it did (0.02 ms on Arena2, the bots firing);
  - the game's lines went from 1,320 to 2,380 (`src/game`), the tests
    from 64 to 81.
  Left out, beyond what was planned (the knife, the chainsaw, the LAW,
  the flamer, the bow, the stationary gun, realistic mode): bink (a
  hit shaking the aim: it moves the cursor, which is the player's
  here); the rifle's butt and the fist; a weapon thrown away (with the
  things, step 5); the grenades on the belt; the interface's own
  pictures and the cursor; the explosion's pictures (with the sparks,
  step 6). The bots hold an MP5 and a Steyr and throw nothing.

- **Step 5, a deathmatch as Soldat's** (2026-10-02). `Soldat_bots`,
  adapted from `AI.pas`: Soldat's own bots. Seeing nobody, a bot
  follows the map's waypoints (the keys its author said to hold from
  each to the next, a connection taken by chance); seeing somebody (a
  line from head to head, 651 units at most), the ladder of
  `SimpleDecision` by how far across the target is: backing away,
  standing, crouching, jumping, firing always or one tick in two or
  four; its aim led, raised for the bullet's fall, and off by its
  accuracy; grenades by its character's frequency; a kit gone to when
  hurt or short; a grenade run from; the jets when falling. Each has a
  character, one of Soldat's 16 `.bot` files (carried in the program):
  its name, its colours, its favourite weapon, its accuracy, whether
  it camps or shoots the dead. `Soldat_things`, adapted from
  `Things.pas`: a weapon let go of (the key F, or dying) is two
  particles and a stick, thrown the way one aims, falling, lying
  still, picked up by empty hands with the rounds it had, gone after
  20 seconds; medikits and grenade kits where the map puts them, taken
  by who needs them, appearing again elsewhere. The round: the first
  to 10 kills, or the best after 10 minutes; the dead back after 3
  seconds at a place taken by chance; three bots by default (`bots=N`),
  a round's cast its number's; the scores ranked, the time left.
  What it turned out to be:
  - of TinySoldat's bots one is kept, on purpose: the one on
    elm-playground's `Sense` and `Bot` (`Soldat_engine_bot`; the flag
    `ai=engine` puts it in a round in place of the last of Soldat's),
    as an example of that library beside a bot made Soldat's way: it
    knows only what it has seen and acts on it a fifth of a second
    late, where Soldat's reads the round each tick. The one written by
    hand, which saw through the walls, went;
  - a bot does not find its way, it follows keys someone drew: on a
    map without waypoints (the tests' floors) it stands until somebody
    comes. The flag `waypoints` draws them, with their keys;
  - a bot's `Random` is everywhere (which connection, whether to fire
    this tick, how far off to aim): all of it is the round's seed now,
    and a round still replays;
  - a tick went from 0.02 to 0.07 ms on Arena2: three bots each
    looking at everyone along a ray;
  - the game's lines went from 2,380 to 3,350 (`src/game`), the tests
    from 81 to 92.
  Left out: the next map (the same one again: the website has only
  Arena2's content); the bonus kits and the bots' chat, as planned;
  the fist (empty hands do nothing but pick up); a bot hiding behind
  a collider; the bots' difficulty (it is "normal"); a thing hit by a
  bullet or thrown by a blast; the kills' console.

- **Step 6, heard, and alive** (2026-10-02). The rules now say what
  happened in a tick as values (`Soldat_event`: a shot, a step, a
  bullet in a wall), where Soldat's code plays a sound or makes a
  spark between two lines of its rules; from them come the sparks
  (`Soldat_sparks`, adapted from `Sparks.pas` and every `CreateSpark`
  of the client's branches: a shot's shell and its puff, a clip let
  go, blood along a bullet's way, the chips and the smoke of a wall,
  a ricochet's sparks, an explosion's fire, ring and big smoke, the
  jets' fire, a runner's dust; 16 of Soldat's 73 styles) and the
  tick's sounds (`Soldat_sfx`: 44 of them, 82 of Soldat's recordings),
  played by `Soldat_sound` as Soldat's `FPlaySound` does: quieter with
  the distance, to a side, a far fight heard as a rumble, the jets a
  loop. Drawn by `Soldat_sparks_view` with Soldat's pictures: its 16
  of an explosion in place of the disc; and the camera shakes.
  What it turned out to be:
  - the sparks are in the round's state, with a seed of their own: a
    test says the same round is played with them and without;
  - the Playground reads 16-bit recordings and 38 of the 82 are 8-bit:
    rewritten here when first played, 30 lines; its `Audio` did the
    rest (a recording, louder, panned, looped) as it was;
  - **in a browser** both cost. 250 sparks are 250 elements of the
    page moved every frame; and a sound made louder and panned is
    computed again whole at each play (the Playground's `louder` and
    `pan`: 2.6 ms for an explosion natively, far more there), where
    one played as it is costs nothing. There: at most 150 sparks and 5
    new sounds a tick, each recording kept at four loudnesses and
    played from the middle, without left and right; an explosion's 26
    pictures at half their size. A headless Chrome without a graphics
    card then gives 40 to 60 frames a second in a fight, as it does
    with no sound at all; before, 20 in the second of an explosion
    (flags `sparks=N` and `mute` to compare);
  - the website's content went from 2.8 to 9.2 MB (the sounds 2.4, the
    sparks' pictures 3.3);
  - where the sparks are drawn matters: Soldat draws them under the
    map's polygons, so that a drop of blood falling into the ground is
    not seen again; over them, it rains through the floor;
  - the hand was wrong again, once: a soldier dropped from 60 units
    lands at 2.16 a tick, under the 2.2 from which a fall is heard
    (its speed keeps 0.99 of itself each tick);
  - the game's lines went from 3,350 to 4,370 (`src/game`), the tests
    from 92 to 99.
  Left out: the weather, clothes shredded and a helmet shot off, a
  bullet's whizz past one's head, the minigun's start and end, the
  hum and the muffling after a grenade, a collider's sound, the menu's
  and the chat's.

- **Step 7, teams and flags** (2026-10-03). A soldier has a team (Alpha
  red, Bravo blue): its own team's bullets do nothing to it, a team's
  walls stop its own only, it appears at its team's places. A round
  has a mode: a deathmatch, a team match (a team's kills, to 60) or
  capture the flag (to 10), the map's own (capture the flag where it
  has the two flags' places) or asked (`mode=`). The flag is a third
  kind of thing (`Soldat_things`, from `Things.pas`): four points, a
  pole held up by a force on its top and a cloth; taken by the other
  team's nearest soldier, its foot then at its carrier's waist;
  dropped when its carrier dies; sent home by one of its own, or by
  itself after 25 seconds; a capture when brought to one's own flag
  standing at home. The bots play it (`ControlBot`'s team parts): a
  path a team, the other's with the flag, a flag gone to from near,
  one's own picked up, a carrier escorted. With `ctf_Ash` and its
  content in `data/`, and the key m on the title for the next map.
  What it turned out to be:
  - the bots do capture: in ten minutes of three against three on
    ctf_Ash, twenty flags taken, a dozen returned, three brought home;
  - a flag stands *leaning*: its cloth has no stiffness, its corner
    falls to the ground and pulls the top its way. It is what the
    skeleton gives, there as here;
  - a bot whose nearest soldier in sight is of its own team sees no
    enemy behind it: Soldat's rule, kept;
  - the game's lines went from 4,370 to 4,720 (`src/game`), the tests
    from 99 to 106.
  Left out: the other modes (pointmatch, rambo, infiltration, hold the
  flag); the second team's own heads (`gostek-gfx/team2`, the only
  pictures that differ); the flag's cloth drawn with its picture (it
  is a polygon in its team's colour); a flag thrown; the walls for who
  carries a flag; respawn in waves.

- **Step 8, over the network** (2026-10-03). The server owns the game:
  a room is a round it steps 60 times a second (`Soldat_room`), its
  soldiers bots' until a player takes one. A player's program
  (`Soldat_online`, the flag `server=`) sends its keys, numbered, and
  is sent the round 30 times a second (`Soldat_wire`: the game as
  bytes); it plays its own soldier at once (elm-playground's
  `Prediction`, on `Soldat_soldier.tick`) and draws the others between
  two rounds (its `Interpolation`); sparks and sounds are made on each
  program from what the server says happened. The same from a browser.
  `docs/network.md` has how it is made, what of elm-playground it
  stands on, and what is not there.
  What it turned out to be:
  - rule 4 held: the server runs `Soldat_update.tick` as it is, given
    one more argument (each player's keys); and a soldier's tick being
    a function is what made the prediction thirty lines;
  - the Playground's `Multiplayer` did not fit (keyboards only, a fixed
    number of players, no server of its own): the libraries under it
    did;
  - a platform says how to connect only once it has started: the
    connection is made at the first frame.
  Since: the weapon chosen (a message, Weapon), tests of the
  player's side (tests/server/Unit_online.ml), the lobby's screen.
  Left out, and not small: deltas
  (125 KB a second a player), lag compensation, reconnection, TLS for
  the public website.

- After the steps: a **Rambomatch** (`mode=rm`), Soldat's fourth mode.
  The bow (`Bow`, and `Bow2` its other arrows, without their fire) is
  a weapon found on the map (the map's place for it, a soldier's if it
  has none), taken by empty hands and never thrown away; its arrow
  takes 252 of a soldier's 150 and stays in the wall it meets. While
  somebody is Rambo the others cannot hurt each other; a kill counts
  when the bow made it or Rambo died of it; the bow gives health back;
  first to 30. Soldat's bots throw their weapon away near the bow, and
  fire at Rambo alone. `tests/game/Unit_rambo.ml`.

- After the steps: **the other weapons and the bonus kits**. The
  second weapon chosen (the key `c`, `secondary=`): the knife (a blow,
  or thrown), the chainsaw, the LAW (fired crouched or lying only);
  empty hands punch. The five bonus kits (`bonus=N`, off without it,
  as in Soldat): the Flame God and its flamer, the predator, the
  berserker, the vest, cluster grenades. Three new styles of bullets:
  a blow (it lives a tick, along the hand), a flame, the knife
  flying. `tests/game/Unit_goodies.ml`. Not there: a soldier burning
  after a flame; the bots choosing these weapons.

- After the steps: **the three other modes** (`mode=pm`, `htf`,
  `inf`), on the yellow flag (`Flag 0`) and the two teams' flags;
  **any mode in a room** (its name: `Arena2.rm`; left and right in the
  lobby), the second weapon and the bonus kits over the network; and
  **an interface**: who killed whom (the kill console), the scores as
  a table (Tab), the weapons' pictures in the menu.

- After the steps: **twins and layers** (`docs/twins.md`): the game as
  a showcase of the Playground's libraries and a thing to learn from.
  Six layers with their keys and levels; three twins (the bots, the
  effects, the sound's place). To come there: rigid bodies, a
  lockstep game, the `gui` library, and the book.

Nothing is the toy's any more but the twins (`docs/twins.md`).

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

All eight are in "Done". What each left out is said there, and for the
network in `docs/network.md`.

## The order, and what could change it

1, 2 and 3 came first: Soldat's units and its soldier, then its look,
which settled how content is fetched (4's pictures used it, 6's sounds
will). 4 was the play, 5 who one plays against and what lies on the
ground, 6 what is heard and what flies about, 7 the teams and the
flags, 8 the network.

## To decide

- **A budget of lines**: decided (2026-10-03). 10,000 for `src/`, a
  tenth of OpenSoldat's 109,196 lines of Pascal, a file's opening
  comments not counted (`make loc`, as mini-chrome's). Not a hard
  limit: clear code first. `docs/omitted.md` says what is not here,
  what of the 109,196 is not the game at all (bindings, the server's
  scripting), and what the rest would take.
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
