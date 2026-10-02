(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_pms.mli *)

(* data/maps/Arena2.pms, as the program carries it *)
let bytes : string = Base64.decode Map_arena2.base64

let arena2 () : Pms.t = match Pms.parse bytes with Ok m -> m | Error why -> Alcotest.fail why

(* where the polygons' count is: after the version (4), the name (1 and
 * 38), the texture (1 and 24), two colours (8), the jets (4), four
 * bytes and the random number (4) *)
let polygons_count_at = 4 + 39 + 25 + 8 + 4 + 4 + 4

let with_i32 (at : int) (n : int) (s : string) : string =
  let b = Bytes.of_string s in
  Bytes.set_int32_le b at (Int32.of_int n);
  Bytes.to_string b

let tests =
  Testo.categorize "Pms"
    [
      Testo.create "the worked example: Arena2" (fun () ->
          let m = arena2 () in
          Alcotest.(check string) "its name" "Soldat Arena Two - version 2.2" m.name;
          Alcotest.(check string) "its texture" "poziomka.bmp" m.texture;
          Alcotest.(check int) "polygons" 134 (Array.length m.polygons);
          Alcotest.(check bool) "all plain ground" true (Array.for_all (fun (p : Pms.polygon) -> p.kind = Pms.Normal) m.polygons);
          let corners = Array.to_list m.polygons |> List.concat_map (fun (p : Pms.polygon) -> [ p.a; p.b; p.c ]) in
          let least f = List.fold_left (fun m (v : Pms.vertex) -> Float.min m (f v)) infinity corners in
          let most f = List.fold_left (fun m (v : Pms.vertex) -> Float.max m (f v)) neg_infinity corners in
          Alcotest.(check (list (float 0.5))) "across, and down" [ -697.; 697.; -350.; 350. ]
            [ least (fun v -> v.x); most (fun v -> v.x); least (fun v -> v.y); most (fun v -> v.y) ];
          Alcotest.(check int) "props" 22 (Array.length m.props);
          Alcotest.(check bool) "each prop's picture is one of the scenery's" true
            (Array.for_all (fun (p : Pms.prop) -> p.style >= 0 && p.style <= Array.length m.scenery) m.props);
          Alcotest.(check string) "the first picture" "grass.bmp" m.scenery.(0);
          let deathmatch = Array.to_list m.spawnpoints |> List.filter (fun (s : Pms.spawnpoint) -> s.active && s.team = 0) in
          Alcotest.(check int) "spawn points for anyone" 11 (List.length deathmatch);
          Alcotest.(check (pair int int)) "the first" (266, 137) (let s = List.hd deathmatch in (s.x, s.y));
          Alcotest.(check int) "the sky, blue first in the file" 187 m.sky_top.b;
          Alcotest.(check int) "sectors: a square grid" (((2 * m.sectors_num) + 1) * ((2 * m.sectors_num) + 1)) (Array.length m.sectors);
          Alcotest.(check bool) "their polygons numbered from 1" true
            (Array.for_all (Array.for_all (fun n -> n >= 1 && n <= Array.length m.polygons)) m.sectors);
          Alcotest.(check bool) "waypoints, connected to waypoints" true
            (Array.length m.waypoints > 0
            && Array.for_all (fun (w : Pms.waypoint) -> List.for_all (fun c -> c >= 0 && c <= Array.length m.waypoints) w.connections) m.waypoints));
      Testo.create "the kinds, and their numbers" (fun () ->
          Alcotest.(check (list int)) "there and back" (List.init 30 Fun.id) (List.init 30 (fun n -> Pms.number_of_kind (Pms.kind_of_number n)));
          Alcotest.(check bool) "none of Soldat's 26 unknown" true
            (List.for_all (fun n -> match Pms.kind_of_number n with Unknown _ -> false | _ -> true) (List.init 26 Fun.id));
          Alcotest.(check bool) "the 27th is" true (Pms.kind_of_number 26 = Unknown 26);
          Alcotest.(check bool) "blue's players" true (Pms.kind_of_number 13 = Team_players 2);
          Alcotest.(check int) "red's bullets" 10 (Pms.number_of_kind (Team_bullets 1));
          Alcotest.(check int) "green's players" 17 (Pms.number_of_kind (Team_players 4));
          Alcotest.(check int) "ice" 4 (Pms.number_of_kind Ice);
          Alcotest.(check int) "the background" 24 (Pms.number_of_kind Background));
      Testo.create "what is refused" (fun () ->
          let refused name s = Alcotest.(check bool) name true (Result.is_error (Pms.parse s)) in
          refused "nothing" "";
          refused "a few bytes" "PMS!";
          refused "cut in its polygons" (String.sub bytes 0 4000);
          refused "cut just before its end of what is read" (String.sub bytes 0 (polygons_count_at + 4 + (134 * 121)));
          refused "more polygons than Soldat has" (with_i32 polygons_count_at 5001 bytes);
          refused "a count below zero" (with_i32 polygons_count_at (-1) bytes);
          refused "more polygons than there are bytes" (with_i32 polygons_count_at 4000 bytes);
          Alcotest.(check bool) "bytes after the waypoints are let be" true (Result.is_ok (Pms.parse (bytes ^ "left over"))));
    ]
