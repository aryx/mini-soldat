(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_wire.mli *)

let hex (s : string) : string = String.concat " " (List.init (String.length s) (fun i -> Printf.sprintf "%02x" (Char.code s.[i])))
let near = Alcotest.float

(* ten seconds of a fight on Arena2 *)
let fight () : Soldat_model.play =
  let p = ref (Soldat_update.start ~bots:(Soldat_bots.cast 5 1) (Lazy.force Soldat_map.arena2)) in
  for _ = 1 to 600 do
    p := Soldat_update.tick !p Soldat_model.still ~look:(0., 0.)
  done;
  !p

let tests =
  Testo.categorize "Wire"
    [
      Testo.create "a player's keys" (fun () ->
          let keys : Soldat_soldier.control = { Soldat_soldier.no_control with left = true; fire = true; aim = (100.5, -20.) } in
          let bytes = Soldat_wire.encode_control keys in
          (* left is the first bit, the trigger the seventh: 41; then the cursor, two singles *)
          Alcotest.(check string) "the worked example's ten bytes" "00 41 42 c9 00 00 c1 a0 00 00" (hex bytes);
          Alcotest.(check bool) "and back" true (Soldat_wire.decode_control bytes = Ok keys);
          let all : Soldat_soldier.control =
            { left = true; right = true; up = true; down = true; jetpack = true; prone = true; fire = true; reload = true; change = true; grenade = true; drop = true; aim = (-1.25, 3.5) }
          in
          Alcotest.(check bool) "every key" true (Soldat_wire.decode_control (Soldat_wire.encode_control all) = Ok all);
          Alcotest.(check bool) "none" true (Soldat_wire.decode_control (Soldat_wire.encode_control Soldat_soldier.no_control) = Ok Soldat_soldier.no_control);
          Alcotest.(check bool) "nine bytes: refused" true (Result.is_error (Soldat_wire.decode_control (String.sub bytes 0 9)));
          Alcotest.(check bool) "eleven: refused" true (Result.is_error (Soldat_wire.decode_control (bytes ^ "x"))));
      Testo.create "a soldier's body" (fun () ->
          let p = fight () in
          Array.iter
            (fun (s : Soldat_model.soldier) ->
              match Soldat_wire.decode_body (Soldat_wire.encode_body s.body) with
              | Error why -> Alcotest.fail why
              | Ok back ->
                  (* a single keeps 7 digits: a place within a thousandth *)
                  Alcotest.(check (pair (near 0.001) (near 0.001))) "its place" (s.body.x, s.body.y) (back.x, back.y);
                  Alcotest.(check (pair (near 0.0001) (near 0.0001))) "its speed" (s.body.vx, s.body.vy) (back.vx, back.vy);
                  Alcotest.(check bool) "its animations, to the frame" true (back.legs = s.body.legs && back.body = s.body.body);
                  Alcotest.(check bool) "its weapons and their counters" true (back.weapon = s.body.weapon && back.secondary = s.body.secondary);
                  Alcotest.(check bool) "what is whole, whole" true
                    (back.direction = s.body.direction && back.stance = s.body.stance && back.jets = s.body.jets && back.grenades = s.body.grenades
                   && back.on_ground = s.body.on_ground && back.ceasefire = s.body.ceasefire && back.human = s.body.human && back.team = s.body.team);
                  Alcotest.(check int) "its 20 points" 20 (Array.length back.skeleton);
                  (* written again, the same bytes: nothing more is lost *)
                  Alcotest.(check bool) "there and back again: the same bytes" true (Soldat_wire.encode_body back = Soldat_wire.encode_body s.body);
                  (* and a tick of it lands where a tick of the server's does *)
                  let keys = { Soldat_soldier.no_control with right = true; aim = (s.body.x +. 100., s.body.y) } in
                  let step (b : Soldat_soldier.t) = Soldat_soldier.tick p.map ~ticks:1 ~random:(fun () -> 0.5) b keys in
                  Alcotest.(check (near 0.01)) "a tick of it: as the server's" (step s.body).x (step back).x)
            p.soldiers);
      Testo.create "a round" (fun () ->
          let p = fight () in
          let events : (int * Soldat_event.t) list =
            [ (1, Sound (Fire Ak74, (10., -20.)));
              (1, Shot { weapon = Ak74; hand = (10., -20.); bullet = (24., 0.); aim = (1., 0.); speed = (0.5, 0.); facing = -1 });
              (-1, Blast (Grenade, (50., -5.)));
              (2, Jets { feet = ((0., 0.), (4., 0.)); legs = ((0., -1.), (0., -1.)); speed = (0., -2.) });
              (-1, Wall ((1., 2.), (3., 4.))) ]
          in
          let bytes = Soldat_wire.encode_world p events in
          Alcotest.(check bool) (Printf.sprintf "six soldiers, their bullets and things: under 6 KB (%d)" (String.length bytes)) true (String.length bytes < 6000);
          match Soldat_wire.decode_world p.map bytes with
          | Error why -> Alcotest.fail why
          | Ok back ->
              Alcotest.(check int) "its soldiers" 6 (Array.length back.soldiers);
              Alcotest.(check (list string)) "their names" (Array.to_list (Array.map (fun (s : Soldat_model.soldier) -> s.name) p.soldiers)) (Array.to_list (Array.map (fun (s : Soldat_model.soldier) -> s.name) back.soldiers));
              Alcotest.(check (list int)) "their kills" (Array.to_list (Array.map (fun (s : Soldat_model.soldier) -> s.kills) p.soldiers)) (Array.to_list (Array.map (fun (s : Soldat_model.soldier) -> s.kills) back.soldiers));
              Alcotest.(check (list bool)) "who is dead" (Array.to_list (Array.map (fun (s : Soldat_model.soldier) -> s.dead <> None) p.soldiers)) (Array.to_list (Array.map (fun (s : Soldat_model.soldier) -> s.dead <> None) back.soldiers));
              Alcotest.(check bool) "somebody is" true (Array.exists (fun (s : Soldat_model.soldier) -> s.dead <> None) p.soldiers);
              Alcotest.(check (pair int int)) "its bullets, its things" (List.length p.bullets, List.length p.things) (List.length back.bullets, List.length back.things);
              Alcotest.(check bool) "its time, its tick, its mode" true (back.time_left = p.time_left && back.frame = p.frame && back.mode = p.mode);
              Alcotest.(check bool) "what happened, as it was said" true (back.events = events);
              (* somebody is dead: who killed whom came too, and the deaths, the bonuses, the second weapons *)
              Alcotest.(check bool) "who killed whom" true (p.log <> [] && back.log = p.log);
              Alcotest.(check bool) "deaths, second weapons, bonuses, vests" true
                (Array.for_all2 (fun (a : Soldat_model.soldier) (b : Soldat_model.soldier) -> a.deaths = b.deaths && a.secondary = b.secondary && a.bonus = b.bonus && a.vest = b.vest) p.soldiers back.soldiers);
              Alcotest.(check bool) "no bot's mind travels" true (Array.for_all (( = ) Soldat_state.Nobody) back.minds);
              (* a dead body's points *)
              Array.iteri
                (fun i (s : Soldat_model.soldier) ->
                  match (s.dead, back.soldiers.(i).dead) with
                  | (Some (_, a), Some (_, b)) -> Alcotest.(check (near 0.001)) "a body's head" (fst a.points.(11).pos) (fst b.points.(11).pos)
                  | _ -> ())
                p.soldiers;
              (* bytes that are no round *)
              Alcotest.(check bool) "cut short: refused" true (Result.is_error (Soldat_wire.decode_world p.map (String.sub bytes 0 (String.length bytes - 3))));
              Alcotest.(check bool) "with more after: refused" true (Result.is_error (Soldat_wire.decode_world p.map (bytes ^ "\000")));
              Alcotest.(check bool) "nothing: refused" true (Result.is_error (Soldat_wire.decode_world p.map ""));
              Alcotest.(check bool) "noise: refused" true (Result.is_error (Soldat_wire.decode_world p.map (String.make 64 '\255'))));
    ]
