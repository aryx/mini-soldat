(* Maps made by hand for the tests: nothing, a flat floor *)

(* a wall of three corners, with the perps Soldat's files give: across
 * each edge, pointing in *)
val wall : ?kind:Pms.kind -> float * float -> float * float -> float * float -> Soldat_map.wall

(* a map of these walls, with these places to appear at (one, just
 * above the middle, if none is given) *)
val map : ?spawns:(float * float) list -> Soldat_map.wall list -> Soldat_map.t

(* no wall at all: a fall without end *)
val empty : Soldat_map.t

(* a floor from x = -2000 to 2000, its top at y = 0 (y goes down: the
 * air is above, at negative y); of a kind, if given *)
val floor : ?kind:Pms.kind -> unit -> Soldat_map.t

(* three rooms in a row on a floor, a wall between each and the next,
 * a place to appear at in each: nobody sees anybody *)
val rooms : Soldat_map.t
