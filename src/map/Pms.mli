(* Pms: a Soldat map as its file has it.

   A map of Soldat's is one binary file, Arena2.pms, ctf_Ash.pms.
   Everything in it is in the order below, numbers little-endian, a
   text as a byte for its length then a fixed number of bytes whatever
   the length:

     the header     version, the map's name (38 bytes), its texture's
                    file (24), the sky's two colours (top and bottom),
                    the jets' fuel, how many grenade packs and
                    medikits lie around, the weather, the footsteps'
                    sound, a random number
     the polygons   a count, then triangles: 3 vertices (x, y, z, rhw,
                    a colour, a texture's u and v), 3 vectors (one per
                    edge), a kind
     the sectors    a grid over the map, and for each of its squares
                    the polygons that touch it: what a collision looks
                    at, instead of all of them
     the props      the scenery placed: which picture, where, turned
                    and scaled how, in which layer
     the scenery    the pictures' files, which the props number from 1
     the colliders  circles that stop bullets
     the spawns     where a player appears, and where the flags (5 and
                    6) and other things do
     the waypoints  the graph the bots walk along

   A map is triangles only, and nothing says which way a triangle is
   wound. Their colours, one per corner, multiply the map's one
   texture: a map is shaded by its corners. The kind of a polygon says
   what touches it and what it does to what does: most are plain
   ground, some stop only bullets or only players, some are for the
   eye alone, some are ice, some kill.

   The order Soldat draws a frame in says what the kinds and the
   props' layers are for (client/GameRendering.pas): the background
   polygons, the props of layer 0, the bullets and the soldiers, the
   props of layer 1, the other polygons -- over the soldiers, whose
   feet sink a little into the ground -- and the props of layer 2.

   Soldat's y grows downwards, as a screen's rows do, and the
   coordinates here are the file's: [Soldat_map] turns them into the
   game's.

   What is read is checked: a count beyond Soldat's own limits (5,000
   polygons, 500 props, 128 colliders, 255 spawn points, 5,000
   waypoints) or bytes missing make the whole file an Error, as
   Soldat's loader refuses them. Bytes left over after the waypoints
   are let be: many of Soldat's own maps have some.

   The worked example, checked by the tests, is the map the game
   starts on, data/maps/Arena2.pms: "Soldat Arena Two - version 2.2",
   134 polygons all plain ground, between -697 and 697 across and -350
   and 350 down, 22 props, 11 spawn points for a deathmatch.

   In Soldat: shared/MapFile.pas (TMapFile, LoadMapFile), whose order
   this follows field for field; shared/PolyMap.pas has the kinds
   (its POLY_TYPE_ constants) and the limits.
*)

(* red, green, blue and alpha, 0 to 255 (the file has them blue first) *)
type color = { r : int; g : int; b : int; a : int }

(* a corner of a triangle. The file also has a z and an rhw, what
 * Direct3D wanted of a vertex already placed on the screen, which the
 * game never reads: not kept *)
type vertex = { x : float; y : float; color : color; u : float; v : float }

(* what a polygon is to what touches it (the POLY_TYPE_ constants, 0 to 25); a team
 * is 1 to 4: alpha (red), bravo (blue), charlie (yellow), delta
 * (green) *)
type kind =
  | Normal
  | Only_bullets (* players go through *)
  | Only_players (* bullets go through *)
  | No_collide (* for the eye *)
  | Ice
  | Deadly
  | Bloody_deadly
  | Hurts
  | Regenerates
  | Lava
  | Team_bullets of int (* stops this team's bullets only *)
  | Team_players of int (* stops this team's players only *)
  | Bouncy
  | Explodes
  | Hurts_flaggers
  | Only_flaggers
  | Not_flaggers
  | Non_flagger_collides
  | Background
  | Background_transition
  | Unknown of int

type polygon = {
  a : vertex;
  b : vertex;
  c : vertex;
  (* one vector per edge, pointing out of the ground, as (x, y, z):
   * what Soldat pushes a soldier back along; the third one's length is
   * how bouncy the polygon is *)
  perps : (float * float * float) array;
  kind : kind;
}

(* a piece of scenery placed on the map *)
type prop = {
  active : bool;
  style : int; (* which picture: its place in [scenery], from 1 *)
  width : int;
  height : int;
  x : float;
  y : float;
  rotation : float;
  scale_x : float;
  scale_y : float;
  alpha : int;
  color : color;
  level : int; (* which layer: 0 behind the soldiers, 1 over them, 2 over the polygons too *)
}

type collider = { active : bool; x : float; y : float; radius : float }

(* [team]: 0 anyone (a deathmatch), 1 to 4 a team's; above, where
 * things appear rather than players (5 and 6: the two flags) *)
type spawnpoint = { active : bool; x : int; y : int; team : int }

type waypoint = {
  active : bool;
  id : int;
  x : int;
  y : int;
  (* the keys a bot holds on its way from here *)
  left : bool;
  right : bool;
  up : bool;
  down : bool;
  jetpack : bool;
  path : int;
  action : int; (* 0 none, 1 stop and camp, 2 to 6 wait 1, 5, 10, 15, 20 seconds *)
  connections : int list; (* the waypoints one can go to from here *)
}

type t = {
  version : int;
  name : string;
  texture : string; (* a file's name, "poziomka.bmp" *)
  sky_top : color;
  sky_bottom : color;
  jet : int; (* the fuel a soldier's jets start with *)
  grenade_packs : int;
  medikits : int;
  weather : int;
  steps : int;
  random_id : int;
  polygons : polygon array;
  sectors_division : int; (* a sector's side *)
  sectors_num : int; (* the grid goes from minus this to this, both ways *)
  sectors : int array array; (* (2 num + 1) squared of them: polygons, numbered from 1 *)
  props : prop array;
  scenery : string array; (* files' names, "grass.bmp" *)
  colliders : collider array;
  spawnpoints : spawnpoint array;
  waypoints : waypoint array;
}

(* the map these bytes (a .pms file's) are, or what was wrong with
 * them *)
val parse : string -> (t, string) result

(* a kind and its POLY_TYPE_ number, each way *)
val kind_of_number : int -> kind
val number_of_kind : kind -> int
