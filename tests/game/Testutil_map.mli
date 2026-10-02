(* Maps made by hand for the tests: nothing, a flat floor *)

(* a wall of three corners, with the perps Soldat's files give: across
 * each edge, pointing in *)
val wall : ?kind:Pms.kind -> float * float -> float * float -> float * float -> Soldat_map.wall

(* a map of these walls, with these places to appear at (one, just
 * above the middle, if none is given), these waypoints, and a kit at
 * each of these places for one *)
val map :
  ?spawns:(float * float) list ->
  ?waypoints:Pms.waypoint list ->
  ?medikit_spawns:(float * float) list ->
  ?grenade_spawns:(float * float) list ->
  Soldat_map.wall list ->
  Soldat_map.t

(* the floor's two triangles, for a map of one's own: left, top, right,
 * bottom *)
val slab : ?kind:Pms.kind -> float -> float -> float -> float -> Soldat_map.wall list

(* a waypoint, by its number (from 1), its place, and the numbers of
 * those it leads to; the keys to hold on the way to it; what to do
 * there (1: stop and camp) *)
val waypoint : ?left:bool -> ?right:bool -> ?up:bool -> ?action:int -> int -> int * int -> int list -> Pms.waypoint

(* no wall at all: a fall without end *)
val empty : Soldat_map.t

(* a floor from x = -2000 to 2000, its top at y = 0 (y goes down: the
 * air is above, at negative y); of a kind, if given *)
val floor : ?kind:Pms.kind -> unit -> Soldat_map.t

(* three rooms in a row on a floor, a wall between each and the next,
 * a place to appear at in each: nobody sees anybody *)
val rooms : Soldat_map.t

(* the same, their floor of a kind *)
val rooms_on : ?kind:Pms.kind -> unit -> Soldat_map.t
