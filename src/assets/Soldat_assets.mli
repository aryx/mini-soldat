(* Soldat_assets: Soldat's content, got while the game runs.

   The soldier's pictures and its animations are small and always
   needed: the program carries them (Soldat_gostek, Soldat_anims). A
   map's texture is half a megabyte, its scenery as much again, and
   there are 99 maps: those are files, got when a map needs them.

   **Where from.** A *base*, a folder or the start of a URL, under
   which the files are as in Soldat's own content (opensoldat-base's
   shared/): textures/poziomka.png, scenery-gfx/barrel.png,
   maps/ctf_Ash.pms. Natively a folder (data/ by default, or a whole
   checkout of Soldat's content: the flag base); in a browser the
   folder beside the page (the website's assets/).

   **Asking and having.** A file's bytes come at once natively and
   later in a browser, which fetches them. So nothing here waits: one
   asks for a file each time one would use it, and has it or not
   ([Loading]: ask again next frame; [Missing]: there is none). The
   first ask starts the fetch; what came is kept. The game goes on
   meanwhile, drawing what it can without (Soldat_scene).

   This is the one place of the game with a memory outside its model:
   which files have come is not part of a round, and a round replays
   the same whether its pictures have come or not.

   **A picture's name.** A map names its pictures as Soldat first had
   them, "barrel.bmp", "poziomka.bmp"; most have since been redrawn as
   PNG, with the name kept in the maps. So a picture is asked by the
   name without its ending, the .png tried first, then the .bmp, as
   Soldat does (FindImagePath, client/GameRendering.pas).

   **In a browser, pixels.** There a picture is asked as name.rgba:
   its width, its height, then its pixels, 4 bytes each, nothing to
   decode. elm-playground's PNG decoder, compiled to JavaScript, takes
   a time that grows as the square of the file's size (26 ms for 4 KB,
   14 seconds for 257 KB: a map's texture and scenery would take
   minutes), so the website's pictures are turned into pixels when it
   is built (Gen_assets, the Makefile's website). Bigger files, got
   once.

   **Green.** Before pictures had transparency, pure green (0, 255, 0)
   stood for it. [keyed] makes those pixels transparent, as Soldat
   does for its scenery (a colour key, client/Gfx.pas).

   In Soldat: PhysFS over soldat.smod (the archive of all of this), and
   stb_image to decode (client/Gfx.pas).
*)

type 'a asked = Loading | Missing | Here of 'a

(* the program runs in a browser (compiled by js_of_ocaml) *)
val in_browser : bool

(* the base: a folder ("data") or the start of a URL ("assets"),
 * without the last "/" *)
val set_base : string -> unit
val base : unit -> string

(* [bytes path]: the file at base/path *)
val bytes : string -> string asked

(* [picture ~keyed folder name]: the picture folder/name, by its name
 * with or without an ending ("scenery-gfx", "barrel.bmp"): the .png,
 * else the .bmp. [keyed]: its pure green made transparent *)
val picture : keyed:bool -> string -> string -> Rgba_image.t asked

(* a picture's file read, whatever it is, by its ending (.png, .bmp,
 * .rgba); and a picture as the pixels a browser is given *)
val decode : string -> string -> Rgba_image.t option
val to_pixels : Rgba_image.t -> string

(* how many files have been asked for and have not come yet *)
val pending : unit -> int

(* forget everything: for the tests *)
val reset : unit -> unit
