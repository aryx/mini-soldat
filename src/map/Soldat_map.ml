(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* The map: polygons the soldiers stand on and the bullets stop at,
 * the places a soldier spawns, and what can be seen from where.
 *
 * For now the one arena TinySoldat had, written here by hand. Soldat's
 * maps are files (.pms: triangles with a texture and a colour at each
 * corner, the scenery, the spawn points, the bots' waypoints), read
 * there by shared/MapFile.pas and held by shared/PolyMap.pas; this is
 * the module that becomes those two (docs/opensoldat.md).
 *)
open Playground
open Basics (* float arithmetics *)

let box (x : number) (y : number) (w : number) (h : number) : (number * number) list =
  [ (x - (w / 2.), y - (h / 2.)); (x + (w / 2.), y - (h / 2.)); (x + (w / 2.), y + (h / 2.)); (x - (w / 2.), y + (h / 2.)) ]

(* convex polygons, counterclockwise, in the screen's coordinates: hills,
 * the side walls, platforms, a bunker *)
let polygons : (number * number) list list =
  [ [ (-500., -500.); (-250., -500.); (-250., -330.); (-500., -300.) ];
    [ (-250., -500.); (0., -500.); (0., -380.); (-250., -330.) ];
    [ (0., -500.); (250., -500.); (250., -320.); (0., -380.) ];
    [ (250., -500.); (500., -500.); (500., -280.); (250., -320.) ];
    box (-510.) 0. 40. 1000.;
    box 510. 0. 40. 1000.;
    box (-300.) (-130.) 180. 20.;
    box 280. (-110.) 200. 20.;
    box 0. 50. 240. 20.;
    [ (-60., -390.); (60., -390.); (35., -310.); (-35., -310.) ];
    box (-320.) 220. 160. 20.;
    box 320. 230. 160. 20. ]

let bodies : Physics.body list =
  List.map (fun corners -> Physics.body (polygon (rgb 110 90 70) corners) |> Physics.immovable |> Physics.rough 0.6) polygons

let spawns = [ (-400., -250.); (400., -230.); (0., 100.); (-320., 260.); (320., 270.) ]

(* what pulls everything down, in pixels per second per second *)
let gravity = 800.

(* nothing of the map between a and b *)
let clear (a : number * number) (b : number * number) : bool =
  List.for_all (fun corners -> Collide.segment_polygon (a, b) corners = None) polygons
