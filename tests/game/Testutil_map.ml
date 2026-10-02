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
let map ?(spawns = [ (0., -20.) ]) (walls : Soldat_map.wall list) : Soldat_map.t =
  let walls = Array.of_list walls in
  let num = 25 in
  let side = (2 * num) + 1 in
  { name = "test"; back = []; front = []; walls; division = 100.; num; sectors = Array.make (side * side) (Array.init (Array.length walls) Fun.id); spawns; jet = 190 }

let empty : Soldat_map.t = map []

(* a floor from x = -2000 to 2000, its top at y = 0, 200 thick: two
 * triangles *)
let slab ?(kind : Pms.kind option) (left : float) (top : float) (right : float) (bottom : float) : Soldat_map.wall list =
  [ wall ?kind (left, top) (right, top) (right, bottom); wall ?kind (left, top) (right, bottom) (left, bottom) ]

let floor ?(kind : Pms.kind option) () : Soldat_map.t = map (slab ?kind (-2000.) 0. 2000. 200.)

(* three rooms in a row on a floor, a wall 400 high between each and
 * the next, a place to appear at in each *)
let rooms : Soldat_map.t =
  map ~spawns:[ (-600., -20.); (0., -20.); (600., -20.) ]
    (slab (-2000.) 0. 2000. 200. @ slab (-320.) (-400.) (-280.) 0. @ slab 280. (-400.) 320. 0.)
