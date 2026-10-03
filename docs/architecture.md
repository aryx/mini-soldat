# The architecture

How mini-soldat is put together: its libraries, what a tick does, how a
frame gets from the game's values to pixels on a screen, where its
content comes from, and what each layer keeps from one frame to the
next. For what each piece is in Soldat's own sources, see
`notes_soldat_in_playground.md`; for the steps it was made in,
`plans/done/plan_soldat.md`; for what is not here, `omitted.md`.

## The whole of it, on a page

```
   Soldat's content                    the keys, the mouse
   (data/, or a checkout)                      |
        |                                      v
        |   at build time            +------------------+
        +--------------------------> |    src/game      |  a tick: the soldiers move
        |   Gen_anims, Gen_pictures, |  (Soldat_update) |  and fire (Soldat's rules), the
        |   base64: carried in the   +------------------+  bullets fly, the dead tumble
        |   program                            |
        |                                      v   a value: Soldat_model.model
        |   when the game runs       +------------------+
        +--------------------------> |   src/render     |  a frame: that value as
            Soldat_assets: files,    |  (Soldat_view)   |  shapes
            from a folder or the web +------------------+
                                               |
                                               v   a list of the Playground's shapes
                                     +------------------+
                                     |  elm-playground  |  one of three backends
                                     +------------------+
                                      /        |        \
                                  Cairo   its own      SVG, in
                                         rasterizer    a browser
```

The game is a Model-View-Update program, as every program of the
Playground's is: one value says everything about a round
(`Soldat_model.model`); `Soldat_update.update` gives the next value
from this one and the inputs, sixty times a second; `Soldat_view.view`
gives a list of shapes from a value. The Playground does the rest: the
window, the loop, the keys, the drawing.

## The libraries

Each folder of `src/` is a library; they depend on each other
downwards only.

| Library | What | Lines |
|---|---|---|
| `src/map` | a `.pms` file read (`Pms`); the map the game plays on: its walls, its sectors, its spawn points (`Soldat_map`) | 900 |
| `src/anim` | the animations' and the skeleton's files read (`Poa`); the 44 animations (`Soldat_anims`) | 390 |
| `src/assets` | files got while the game runs, and decoded (`Soldat_assets`, `Bmp`) | 320 |
| `src/game` | the game without its picture: the weapons' numbers (`Soldat_weapons`), a soldier and its guns (`Soldat_soldier`), a dead one (`Soldat_ragdoll`), what lies on the ground (`Soldat_things`), the state (`Soldat_model`), the bullets and the explosions (`Soldat_bullets`), the bots' cast (`Soldat_cast`), the slots of the parts made twice (`Soldat_parts`, `Soldat_state`: `src/orig` has Soldat's, `src/twin` their twins, `docs/twins.md`), what a tick gave to hear and see (`Soldat_event`), the sparks (`Soldat_sparks`), the sounds (`Soldat_sfx`; `Soldat_sound` plays them), a tick and a round, its teams and its flags (`Soldat_update`) | 4,720 |
| `src/render` | the picture: a soldier's and its weapons' (`Soldat_gostek`), the map's (`Soldat_scene`, `Soldat_raster`), the sparks' (`Soldat_sparks_view`), the whole and the interface (`Soldat_view`) | 1,320 |
| `src/net` | the messages between a player and the server (`Soldat_protocol`) | 200 |
| `src/server` | the lobby (`Soldat_lobby`) and its sockets (`Soldat_server`) | 240 |
| `src/main` | the programs | 100 |

About 8,300 lines, and 2,600 of tests. What matters in the split:

- **`src/game` knows no picture and no keyboard.** `Soldat_update.tick`
  takes what the player wants (an `intent`: keys and where the cursor
  is, what a bot returns too) and gives the next round. Its chance (a
  shot's scatter) is a seed in the round's state, not `Random`. So
  tests call it, a round replays the same, and a server will run it.
- **What a browser's program links is pure OCaml**: no `unix`. Only
  `src/server` uses sockets, and the game never links it.
- **The platform is chosen when linking.** elm-playground's platform is
  a virtual library with three implementations; `src/main` links the
  same `MiniSoldat.ml` against each: Cairo (`mini-soldat`), its own
  rasterizer (`mini-soldat-software`), a browser (`web/`).

## A tick

`Soldat_update.tick`, in Soldat's own order:

1. each living soldier: its keys (the player's, or a bot's:
   `Soldat_bots.control`, from what it sees of the round as the tick
   began and from its own mind, kept beside the soldiers; for the bot
   of `ai=engine`, `Bot.step` over its senses) and its
   move, `Soldat_soldier.tick`, which is itself: the particle's step,
   the keys as forces and animations, the trigger (a shot: what leaves
   the soldier is in its `shots`), the skeleton placed and aimed, the
   animations advanced, the collision with the map, the weapon's
   counters;
2. each bullet, the tick's new ones too (`Soldat_bullets.tick`):
   tested along where it is going (the map's walls: a ricochet or the
   end; its colliders; the soldiers' seven circles, living or dead),
   what it hits hurt, pushed, killed at once, so that the next bullet
   finds it so; an explosion and the grenades it sets off; then moved;
3. what the walls do to who touches them;
4. the things: each falls or lies still; the nearest living soldier in
   reach takes it if it may (empty hands a weapon, the hurt a medikit);
   a kit taken appears again elsewhere; a flag follows its carrier, is
   taken, sent home or captured; the weapons let go of this
   tick (thrown away, or by who just died) become things;
5. the dead tumble, and come back at a place taken by chance;
6. what all of that gave to hear and see. Each part above only *says*
   what happened (`Soldat_event`: a shot, a step, a bullet in a wall),
   where Soldat's code plays a sound or makes a spark on the spot. From
   those: the sparks (`Soldat_sparks.of_event`, then their own step),
   with a chance apart from the game's, and the tick's sounds
   (`play.sounds`);
7. the camera, shaken by an explosion.

A tick is still a function. The one thing that *does* something is
after it, in `Soldat_update.update`, the Playground's side:
`Soldat_sound.play` on the tick's sounds, heard from where the player
is.

The model's order of modules is the game's: `Soldat_things` knows
soldiers only as `Soldat_soldier.t`, `Soldat_model` holds things and
brains, `Soldat_bullets` and `Soldat_bots` read the model, and
`Soldat_update` alone puts them together.

Everything is in Soldat's units and coordinates: a tick a frame, a
soldier 20 tall, y downwards. A point is tested against the walls of
its own sector of the map alone, so a tick costs the same on a map of
100 polygons and on one of 700: about 0.02 ms.

## The content

Three ways in, chosen by size and need:

| | What | How | Size |
|---|---|---|---|
| **carried**, packed when the program is built | the first map (Arena2) | the file as base64 (`scripts/build/file_to_base64_ml.ml`) | 40 KB |
| | the 44 animations and the skeleton | `Gen_anims`: 1.2 MB of text as the singles Soldat keeps them in | 180 KB |
| | the soldier's 23 pictures | `Gen_pictures`: decoded, as their pixels | 60 KB |
| **got**, when the game runs | a map's texture, its scenery; a map by its name | `Soldat_assets`, under a base: `data/`, or a checkout of Soldat's whole content, or `assets/` beside a page | a map: 1 to 2 MB |
| **turned into pixels**, for the website | the same pictures | `Gen_assets` at `make website`: `name.rgba`, since a browser must not decode a PNG with our decoder | twice the PNG |

A file got comes at once natively and later in a browser, so nothing
waits for one: the code asks each frame and has it or not
(`Loading`, `Missing`, `Here`), and draws what it can meanwhile. With
no file at all the game still runs, its map in flat colours.

## A frame, from values to pixels

This is the part with the most layers, and where the time goes.

### What the game hands over

`Soldat_view.view` turns the round into a list of the Playground's
*shapes*. A shape is a value, a description, not a drawing:

```ocaml
type shape = { x; y; angle; scale; alpha; form }
and form =
  | Circle of color * number          | Rectangle of color * number * number
  | Polygon of color * (number * number) list
  | Words of color * string           | Group of shape list
  | Image of number * number * string           (* a picture by its URL *)
  | Bitmap of number * number * Rgba_image.t    (* a picture by its pixels *)
  | ...
```

A frame of mini-soldat is about this list, back to front:

```
Camera2d.view camera          one Group: everything of the map, moved and zoomed
  the sky                     66 Rectangles (no gradient in the Playground)
  the map, behind             Bitmaps: the tiles under the camera
  the bullets                 a Rectangle each; a grenade a Bitmap
  the things                  a Bitmap each: a weapon's picture, a kit's
  the sparks                  a Bitmap each, faded: up to 558 (150 in a browser);
                              an explosion is 6 big ones
  the soldiers                16 Bitmaps each (a picture a limb), 1 to 4 more for
                              its weapons (in hand, its clip, its fire; on the back)
  the map, in front           Bitmaps: tiles again, over the soldiers
the scores, the time left,    Words and Rectangles, outside the camera
the interface
```

The game's y goes down and the Playground's up: `Soldat_view.at`
turns a point over, here and nowhere else. The camera is a `Group`
moved by minus where it looks and scaled so that 640 of the game's
units are the screen's width.

### A picture is not a shape

`Circle`, `Rectangle`, `Polygon` say all there is to draw. A `Bitmap`
says "these pixels, this big, here": the pixels are an
`Rgba_image.t`, a block of bytes in memory (4 a pixel: red, green,
blue, alpha) that the shape only points to. Two things follow.

**The Playground draws a picture as it is.** It does not tint one,
mirror one, cut a part out of one, or fill a triangle with one. Soldat
does all four, on a graphics card. So mini-soldat makes the pictures
it needs, itself, once:

| Soldat wants | mini-soldat makes | Kept in |
|---|---|---|
| a limb's picture times the shirt's colour, mirrored when facing left | that picture, tinted, turned over: one per (limb, colour, side) | `Soldat_gostek.made` |
| the map's texture on its triangles, shaded by their corners, and the scenery turned and scaled | *tiles*: squares of the map of 256 units, drawn by hand into 512 by 512 pixels (`Soldat_raster`: the arithmetic a card does) | `Soldat_scene`, 96 tiles at most, the nearest the camera |

**A backend knows a picture by itself.** Not by its bytes: by which
value it is (`==`). Each backend must turn a picture into something of
its own before it can draw it, and that costs far more than drawing
it, so it keeps what it made, looked up by the picture itself. Hence
the rule everything above obeys: *the same picture is the same value,
frame after frame*. `Soldat_gostek.picture` and `Soldat_scene` give
back the very one they gave before. A program that built its pictures
anew each frame, equal byte for byte, would have every one converted
again each frame.

### The three backends

| | Cairo (`mini-soldat`) | its own rasterizer (`mini-soldat-software`) | a browser (`web/`) |
|---|---|---|---|
| a `Rectangle`, a `Polygon` | a Cairo path, filled | scanlines into a framebuffer | an SVG element |
| a frame | every shape drawn again | the same | the tree of SVG elements compared with the last frame's, what changed patched (a virtual DOM) |
| a `Bitmap`, the first time | converted to a Cairo surface: each pixel repacked and multiplied by its alpha | nothing: drawn from the pixels | encoded as a PNG, by the browser (a canvas, `toDataURL`), into a `data:` URL: SVG has nothing else for pixels in memory |
| that costs | a pass over its pixels | | about 9 ms for a tile, 0.2 for a limb |
| and after | the surface found in a table, by the picture | | the URL found in a table, by the picture |
| it keeps | 16 million pixels' worth | | the same |
| drawing it | fast | slow: every pixel of every tile, by OCaml | the browser's own, fast |

The software platform has no conversion and no cache, and pays at
each frame instead: a screen of tiles is every one of their pixels
blended in OCaml, 170 ms a frame (40 with the flat map). It is there
to compare and to test (its frames are the same on every machine);
Cairo's is the one to play with.

### What each layer keeps

From a file to the screen, a picture is made or converted several
times, and each time kept:

```
barrel.png, a file            Soldat_assets.files        its bytes, once got
   |  decoded, green made transparent
   v
an Rgba_image.t               Soldat_assets.pictures     by folder and name
   |  drawn into tiles, with the texture and the triangles
   v
a tile, an Rgba_image.t       Soldat_scene               96, by layer, column, row
   |  given to the Playground as a Bitmap, every frame
   v
a Cairo surface | a PNG's URL    the backend's table     by the picture itself
   |
   v
the screen
```

None of this is in the model, and no rule of the game reads any of
it: a round is the same whether its pictures have come or not. It is
all memory that can be thrown away and made again.

### A toy, and what a table changes

`scripts/perf/bitmap_toy/BitmapToy.ml` is the smallest program with
this problem: `n` small pictures, each its own, going round in a
circle. The model is the pictures, made once; a frame moves them and
no more.

```ocaml
let view computer pictures =
  Array.to_list (Array.mapi (fun i image ->
      let a = angle i computer.time in
      bitmap 40. 40. image |> move (r i *. cos a) (r i *. sin a)) pictures)
```

Until this game needed otherwise, elm-playground's web platform kept
the PNG of the last 32 pictures it had been given, in a list, the
newest first. Measured in Chrome (`scripts/perf/web_probe.js`):

| n | frames a second | PNG encoded a frame |
|---|---|---|
| 16 | 60 | 0 |
| 32 | 60 | 0 |
| **33** | 60 | **33** |
| 64 | 60 | 64 |
| 128 | 39 | 128 |

One picture more than the list holds, and not one picture is spared:
all 33 are encoded again, every frame. A list kept by age does not
keep "the 32 most useful":

```
the list holds 32, the frame draws 1, 2, ... 33, in turn

draw 33   not in the list: encoded, put first; the oldest, 1, falls out
draw 1    (next frame) not in the list: encoded; 2 falls out
draw 2    not in the list: encoded; 3 falls out
...       every picture is wanted just after it fell out
```

mini-soldat at its third step drew 64 pictures a frame (14 tiles, 50
limbs): 40 PNG encoded a frame, 2.4 ms each, 9 frames a second.

The cure is the one elm-playground's Cairo platform had been given the
same day for the same reason (a page of text drawn a picture a letter,
in mini-chrome): a table found by the picture itself, with a budget of
pixels, all dropped when it is full. With it:

| n | frames a second | PNG encoded a frame |
|---|---|---|
| 33 | 60 | 0 |
| 64 | 60 | 0 |
| 128 | 60 | 0 |
| 512 | 57 | 0 |

and mini-soldat's 64 are encoded once: 60 frames a second in a
browser. That change is in elm-playground after 0.3.5
(`Playground_platform.bitmap_url`), the first this game asked of it.

What remains true of any such table: it is found by the picture
itself, so the rule above stands (the same value each frame), and it
has a budget, so a program making new pictures without end (a video)
fills it and pays at each frame.

### The other thing a browser could not do

A browser's program is OCaml compiled to JavaScript, and
elm-playground's PNG decoder, instant natively, takes there a time
that grows as the square of the file: 26 ms for 4 KB, 94 ms for 35 KB,
14 seconds for 257 KB. A map's texture and scenery would take
minutes. So in a browser a picture is never decoded: the website has
each one as plain pixels (`name.rgba`: a width, a height, then 4
bytes a pixel), made by `Gen_assets` when it is built.

### Seeing the layers: the key g

The game can be drawn as each step of its making drew it:

| | The soldiers | The map | Shapes a frame |
|---|---|---|---|
| 1 | their skeletons' sticks | flat polygons | 30 rectangles a soldier, 134 polygons |
| 2 | their pictures | flat polygons | 17 bitmaps a soldier, 134 polygons |
| 3 | their pictures | its texture and scenery | 17 bitmaps a soldier, 14 tiles |

`g` goes round them, `graphics=N` starts at one; the picture is one of
six layers, each with its key and its levels (`docs/twins.md`). The flags `sticks`
and `hitboxes` add the skeleton and the points the game tests, over
any of them.

## The server

`mini-soldat-server` is a program apart, of `src/net` and
`src/server`: a lobby with rooms over WebSocket, on elm-playground's
event loop. Its rule is a value too (`Soldat_lobby.receive`: a message
in, the lobby and the messages to send out), the sockets around it.
Nothing in the game talks to it yet; `network.md` has what is there
and what is to come.

## How it is checked

| What | How |
|---|---|
| the files' readers (`Pms`, `Poa`, `Bmp`) | their worked examples, on Soldat's own files; what they refuse |
| the soldier's moves | numbers worked out by hand from Soldat's formulas, on a floor made by hand (`tests/game/Unit_soldier.ml`) |
| a round | played without drawing it; replayed, the same |
| where a limb's picture goes, a triangle drawn | positions and pixels worked out by hand (`tests/render`) |
| every map | `scripts/perf/Frame_bench` reads and plays all 99 |
| a frame, natively | `-dump-frame n file.png`, with SDL's dummy driver: no screen needed |
| a page, in a browser | `scripts/perf/web_probe.js`: a real Chrome, its frames and the PNG it encodes, each second |
