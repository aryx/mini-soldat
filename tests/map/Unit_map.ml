(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_map.mli *)

let arena2 () : Soldat_map.t = Lazy.force Soldat_map.arena2

(* a wall's middle: in it, by any test *)
let middle (w : Soldat_map.wall) : float * float =
  let (ax, ay) = w.a and (bx, by) = w.b and (cx, cy) = w.c in
  ((ax +. bx +. cx) /. 3., (ay +. by +. cy) /. 3.)

let tests =
  Testo.categorize "Map"
    [
      Testo.create "Arena2, as the game plays it" (fun () ->
          let map = arena2 () in
          Alcotest.(check string) "its name" "Soldat Arena Two - version 2.2" map.name;
          Alcotest.(check int) "walls, all of its polygons" 134 (Array.length map.walls);
          Alcotest.(check int) "sectors: a square grid" (((2 * map.num) + 1) * ((2 * map.num) + 1)) (Array.length map.sectors);
          Alcotest.(check int) "spawn points" 11 (List.length map.spawns);
          Alcotest.(check (pair (float 0.1) (float 0.1))) "the first, as the file has it: y downwards" (266., 137.) (List.hd map.spawns);
          Alcotest.(check bool) "none inside a wall" true
            (List.for_all (fun (x, y) -> not (List.exists (fun w -> Soldat_map.in_wall (x, y) w) (Soldat_map.sector map x y))) map.spawns);
          Alcotest.(check bool) "the jets' fuel: 119 hundredths of the file's" true (map.jet > 0 && map.jet < 400));
      Testo.create "a wall, its perps, a point in it" (fun () ->
          let map = arena2 () in
          Alcotest.(check bool) "every perp of length 1" true
            (Array.for_all (fun (w : Soldat_map.wall) -> Array.for_all (fun (x, y) -> Float.abs (Float.hypot x y -. 1.) < 0.001) w.perps) map.walls);
          Alcotest.(check bool) "a wall's middle is in it, by its corners and by its perps" true
            (Array.for_all (fun w -> Soldat_map.in_wall (middle w) w && Soldat_map.in_edges (middle w) w) map.walls);
          let w = map.walls.(0) in
          let (perp, depth, edge) = Soldat_map.closest_perp w (middle w) in
          Alcotest.(check bool) "its nearest edge: one of the three, nearer than the others" true (edge >= 1 && edge <= 3 && depth > 0. && perp = w.perps.(edge - 1));
          let (mx, my) = middle w and (px, py) = perp in
          Alcotest.(check bool) "back along the perp by that far, and a little: out" false (Soldat_map.in_edges (mx -. (px *. (depth +. 0.5)), my -. (py *. (depth +. 0.5))) w));
      Testo.create "the sectors" (fun () ->
          let map = arena2 () in
          let seen_from (w : Soldat_map.wall) (x, y) = List.memq w (Soldat_map.sector map x y) in
          let between (ax, ay) (bx, by) = ((ax +. bx) /. 2., (ay +. by) /. 2.) in
          Alcotest.(check bool) "a wall is seen from its corners and from its edges' middles" true
            (Array.for_all
               (fun (w : Soldat_map.wall) -> List.for_all (seen_from w) [ w.a; w.b; w.c; between w.a w.b; between w.b w.c; between w.c w.a ])
               map.walls);
          (* a sector lists the walls whose outline crosses it: deep in a
           * big one, nothing is listed. 14 of Arena2's 134 are so *)
          Alcotest.(check int) "not always from its middle: the file lists a wall where its outline is" 14
            (Array.fold_left (fun n w -> if seen_from w (middle w) then n else n + 1) 0 map.walls);
          Alcotest.(check int) "nothing out of the map" 0 (List.length (Soldat_map.sector map 1e6 0.));
          Alcotest.(check bool) "a sector sees a few walls, not all" true
            (Array.for_all (fun polys -> Array.length polys < Array.length map.walls / 2) map.sectors);
          let edge = Soldat_map.edge map in
          Alcotest.(check (float 0.01)) "the edge: 50 short of the last sector" ((float_of_int map.num *. map.division) -. 50.) edge);
      Testo.create "what stops what" (fun () ->
          let soldier = Soldat_map.stops_soldier and bullet = Soldat_map.stops_bullet in
          Alcotest.(check (pair bool bool)) "plain ground: both" (true, true) (soldier Normal, bullet Normal);
          Alcotest.(check (pair bool bool)) "bullets only" (false, true) (soldier Only_bullets, bullet Only_bullets);
          Alcotest.(check (pair bool bool)) "players only" (true, false) (soldier Only_players, bullet Only_players);
          Alcotest.(check (pair bool bool)) "for the eye" (false, false) (soldier No_collide, bullet No_collide);
          Alcotest.(check (pair bool bool)) "ice" (true, true) (soldier Ice, bullet Ice);
          Alcotest.(check (pair bool bool)) "the background" (false, false) (soldier Background, bullet Background);
          Alcotest.(check (pair bool bool)) "a team's, no team yet" (false, false) (soldier (Team_players 1), bullet (Team_bullets 1)));
      Testo.create "a line of sight" (fun () ->
          let map = arena2 () in
          let w = map.walls.(0) in
          let (mx, my) = middle w in
          Alcotest.(check bool) "into a wall: no" false (Soldat_map.clear map (mx, my -. 400.) (mx, my));
          Alcotest.(check bool) "a wall's middle stops a bullet" true (Soldat_map.in_bullet_wall map (mx, my));
          let (sx, sy) = List.hd map.spawns in
          Alcotest.(check bool) "from a spawn point to just beside it: yes" true (Soldat_map.clear map (sx, sy) (sx +. 5., sy -. 5.)));
    ]
