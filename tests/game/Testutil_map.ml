(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Testutil_map.mli *)

(* a wall of three corners, its perps worked out: across each edge,
 * towards the third corner *)
let wall ?(kind : Pms.kind = Normal) (a : float * float) (b : float * float) (c : float * float) : Soldat_map.wall =
  let perp (x1, y1) (x2, y2) (ox, oy) =
    let (nx, ny) = (-.(y2 -. y1), x2 -. x1) in
    let (nx, ny) = if (nx *. (ox -. x1)) +. (ny *. (oy -. y1)) < 0. then (-.nx, -.ny) else (nx, ny) in
    let len = Float.hypot nx ny in
    (nx /. len, ny /. len)
  in
  { a; b; c; perps = [| perp a b c; perp b c a; perp c a b |]; bounciness = 1.; kind }

(* a map of these walls, every sector seeing them all: 25 sectors of
 * 100 each way *)
let map ?(spawns = [ (0., -20.) ]) ?(waypoints : Pms.waypoint list = []) ?(medikit_spawns = []) ?(grenade_spawns = []) ?(bow_spawns = []) ?(alpha_spawns = []) ?(bravo_spawns = []) ?alpha_flag ?bravo_flag (walls : Soldat_map.wall list) : Soldat_map.t =
  let walls = Array.of_list walls in
  let num = 25 in
  let side = (2 * num) + 1 in
  { name = "test"; pms = None; sky = []; back = []; front = []; walls; division = 100.; num; sectors = Array.make (side * side) (Array.init (Array.length walls) Fun.id); colliders = []; spawns; jet = 190; waypoints = Array.of_list waypoints; medikits = List.length medikit_spawns; grenade_kits = List.length grenade_spawns; medikit_spawns; grenade_spawns; bow_spawns; alpha_spawns; bravo_spawns; alpha_flag; bravo_flag }

let empty : Soldat_map.t = map []

(* a floor from x = -2000 to 2000, its top at y = 0, 200 thick: two
 * triangles *)
let slab ?(kind : Pms.kind option) (left : float) (top : float) (right : float) (bottom : float) : Soldat_map.wall list =
  [ wall ?kind (left, top) (right, top) (right, bottom); wall ?kind (left, top) (right, bottom) (left, bottom) ]

let floor ?(kind : Pms.kind option) () : Soldat_map.t = map (slab ?kind (-2000.) 0. 2000. 200.)

(* three rooms in a row on a floor, a wall 400 high between each and
 * the next, a place to appear at in each *)
let rooms_on ?(kind : Pms.kind option) () : Soldat_map.t =
  map ~spawns:[ (-600., -20.); (0., -20.); (600., -20.) ]
    (slab ?kind (-2000.) 0. 2000. 200. @ slab (-320.) (-400.) (-280.) 0. @ slab 280. (-400.) 320. 0.)

let rooms : Soldat_map.t = rooms_on ()

(* a waypoint at a place, saying which way to run on the way to it,
 * and which come next *)
let waypoint ?(left = false) ?(right = false) ?(up = false) ?(action = 0) (id : int) ((x, y) : int * int) (connections : int list) : Pms.waypoint =
  { active = true; id; x; y; left; right; up; down = false; jetpack = false; path = 1; action; connections }
