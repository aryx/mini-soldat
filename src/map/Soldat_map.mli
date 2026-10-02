(* Soldat_map: the map a game is played on.

   What the game needs of one of Soldat's maps (Pms.mli): its polygons
   as walls to test points against, found by where they are; the
   places a soldier appears at; and its picture.

   The walls are in Soldat's own coordinates, y downwards, as the game
   is (the soldier's code is Soldat's, with its signs). Only the
   picture is turned over, the Playground's y going up: [back] and
   [front] are shapes at (x, -y).

   **The sectors.** A map has a few hundred polygons and a soldier
   touches three. Soldat lays a grid over the map; the map's file says,
   for each square, a sector, which polygons touch it, and a point
   is tested against the polygons of its own sector alone:

       sector of (x, y) = (round (x / division), round (y / division))

   from -num to num each way; the outermost ring is never looked at (a
   point there touches nothing: it is out of the map). So what a test
   costs does not grow with the map. The grid is the file's own, not
   one made again here: which polygons a point may touch is the map's
   author's (the editor's) say. And it says something one would not
   guess: a sector lists the polygons whose *outline* crosses it. Deep
   inside a big polygon no sector lists it (14 of Arena2's 134 are not
   seen from their own middle): a soldier is stopped at a wall's skin,
   and one that got through it would fall through the wall, as in
   Soldat.

   **A wall** is a triangle with, for each of its three edges, a
   vector across it pointing *into* the triangle (a *perp*: the file
   has them). A point is in a wall when it is on the inner side of the
   three edges ([in_edges], by the perps) or, the test the soldier's
   feet use, on the same side of the three edges ([in_wall], by the
   corners alone). To push a point out, [closest_perp] gives the perp
   of the edge it is nearest and how far from it: the point is moved
   back along it.

   What a polygon stops is its kind's business (Pms.kind), here
   without teams or flags, which the game does not have yet: a soldier
   is stopped by the plain ones and by all those that do something to
   it (ice, the deadly ones, lava...), not by those for bullets only,
   for the eye, for one team, for flag carriers or for the background;
   a bullet the same, with "players only" for "bullets only".

   A polygon is filled with one colour: the mean of its three corners'
   times the mean colour of the map's texture (Texture_tints), a first
   approximation of what Soldat draws, the texture itself shaded by the
   corners; a polygon whose corners are all transparent is not drawn
   (Soldat's maps have many: walls one cannot see). Its props (the
   scenery) are not drawn yet.

   In Soldat: shared/PolyMap.pas (TPolyMap: LoadData, PointInPoly,
   PointInPolyEdges, ClosestPerpendicular, RayCast) and
   client/MapGraphics.pas (the map as vertices to draw); which kind
   stops a soldier is TSprite.CheckMapCollision's and TeamCollides's
   (shared/mechanics/Sprites.pas).
*)
open Playground

type wall = {
  a : float * float;
  b : float * float;
  c : float * float;
  (* for the edges a-b, b-c and c-a: of length 1, pointing in *)
  perps : (float * float) array;
  (* how much of its speed a bouncy one gives back: the length the
   * third perp had in the file *)
  bounciness : float;
  kind : Pms.kind;
}

type t = {
  name : string;
  (* the map as its file has it, when it is one of Soldat's: what draws
   * it as Soldat does needs its texture, its corners' colours, its
   * props (Soldat_scene) *)
  pms : Pms.t option;
  (* the picture in flat colours, y upwards: the sky; behind the
   * soldiers, the background polygons; over them, as Soldat draws the
   * others *)
  sky : shape list;
  back : shape list;
  front : shape list;
  walls : wall array;
  (* a sector's side, how many there are each way from the middle, and
   * for each the walls that touch it (their places in [walls]) *)
  division : float;
  num : int;
  sectors : int array array;
  (* circles that stop a bullet (a barrel, a crate drawn there): a
   * middle and a radius *)
  colliders : ((float * float) * float) list;
  (* where a soldier appears: never empty *)
  spawns : (float * float) list;
  (* the fuel a soldier's jets start with, in ticks *)
  jet : int;
  (* the graph the bots walk along: the file's, the first numbered 1 *)
  waypoints : Pms.waypoint array;
  (* how many medikits and grenade kits lie around, and where one may
   * appear (the file's spawn points of "teams" 8 and 7) *)
  medikits : int;
  grenade_kits : int;
  medikit_spawns : (float * float) list;
  grenade_spawns : (float * float) list;
}

(* the game's map for one of Soldat's *)
val of_pms : Pms.t -> t

(* the map the game starts on, carried in the program: Soldat's Arena2
 * (data/maps/Arena2.pms) *)
val arena2 : t Lazy.t

(* the walls of the sector (x, y) is in: none out of the map *)
val sector : t -> float -> float -> wall list

(* a point in a wall: by its corners, by its perps *)
val in_wall : float * float -> wall -> bool
val in_edges : float * float -> wall -> bool

(* [closest_perp wall p]: the perp of the edge [p] is nearest, how far
 * [p] is from that edge's line, and which edge (1, 2 or 3) *)
val closest_perp : wall -> float * float -> (float * float) * float * int

(* how far [p] is from the line through two points *)
val point_line_distance : float * float -> float * float -> float * float -> float

(* which kinds stop a soldier, and a bullet *)
val stops_soldier : Pms.kind -> bool
val stops_bullet : Pms.kind -> bool

(* the point is in a wall that stops a bullet: a bullet ends there, a
 * line of sight too *)
val in_bullet_wall : t -> float * float -> bool

(* nothing of the map between a and b: one sees the other. Looked at
 * every 4 units on the way *)
val clear : t -> float * float -> float * float -> bool

(* farther than this from the middle, either way, is out of the map
 * (50 short of its last sector) *)
val edge : t -> float
