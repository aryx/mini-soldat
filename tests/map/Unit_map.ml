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

(* twice the area of a polygon, positive when it turns counterclockwise *)
let area2 (corners : (float * float) list) : float =
  let rec go = function
    | (x1, y1) :: ((x2, y2) :: _ as rest) -> ((x1 *. y2) -. (x2 *. y1)) +. go rest
    | _ -> 0.
  in
  go (corners @ [ List.hd corners ])

let inside (corners : (float * float) list) ((x, y) : float * float) : bool =
  let rec go = function
    | (x1, y1) :: ((x2, y2) :: _ as rest) -> ((x2 -. x1) *. (y -. y1)) -. ((x -. x1) *. (y2 -. y1)) >= 0. && go rest
    | _ -> true
  in
  go (corners @ [ List.hd corners ])

let tests =
  Testo.categorize "Map"
    [
      Testo.create "Arena2, as the game plays it" (fun () ->
          let map = Lazy.force Soldat_map.arena2 in
          Alcotest.(check string) "its name" "Soldat Arena Two - version 2.2" map.name;
          Alcotest.(check int) "walls, all of its polygons" 134 (List.length map.walls);
          Alcotest.(check int) "as many bodies" 134 (List.length map.bodies);
          Alcotest.(check int) "and as many stop a bullet" 134 (List.length map.bullet_walls);
          Alcotest.(check bool) "every triangle counterclockwise" true (List.for_all (fun corners -> area2 corners > 0.) map.walls);
          Alcotest.(check (list (float 1.))) "twice as big" [ -1394.; 1394.; -700.; 700. ] [ map.bounds.left; map.bounds.right; map.bounds.bottom; map.bounds.top ];
          Alcotest.(check int) "spawn points" 11 (List.length map.spawns);
          Alcotest.(check (pair (float 0.1) (float 0.1))) "the first: (266, 137) down, so (532, -274) up" (532., -274.) (List.hd map.spawns);
          Alcotest.(check bool) "none inside a wall" true
            (List.for_all (fun spawn -> not (List.exists (fun corners -> inside corners spawn) map.walls)) map.spawns));
      Testo.create "what stops what" (fun () ->
          let soldier = Soldat_map.stops_soldier and bullet = Soldat_map.stops_bullet in
          Alcotest.(check (pair bool bool)) "plain ground: both" (true, true) (soldier Normal, bullet Normal);
          Alcotest.(check (pair bool bool)) "bullets only" (false, true) (soldier Only_bullets, bullet Only_bullets);
          Alcotest.(check (pair bool bool)) "players only" (true, false) (soldier Only_players, bullet Only_players);
          Alcotest.(check (pair bool bool)) "for the eye" (false, false) (soldier No_collide, bullet No_collide);
          Alcotest.(check (pair bool bool)) "ice" (true, true) (soldier Ice, bullet Ice);
          Alcotest.(check (pair bool bool)) "the background" (false, false) (soldier Background, bullet Background);
          Alcotest.(check (pair bool bool)) "a team's, no team yet" (false, false) (soldier (Team_players 1), bullet (Team_bullets 1)));
      Testo.create "the toy" (fun () ->
          let map = Soldat_map.toy in
          Alcotest.(check int) "walls" 12 (List.length map.walls);
          Alcotest.(check int) "spawn points" 5 (List.length map.spawns);
          Alcotest.(check bool) "a platform between under it and over it" false (Soldat_map.clear map (0., 0.) (0., 100.));
          Alcotest.(check bool) "nothing between two points of the sky" true (Soldat_map.clear map (-400., 400.) (400., 400.)));
    ]
