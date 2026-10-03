(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_layers.mli *)

let near = Alcotest.float
let tick (p : Soldat_model.play) : Soldat_model.play = Soldat_update.tick p Soldat_model.still ~look:(0., 0.)
let rec after n p = if n = 0 then p else after (n - 1) (tick p)
let after_ticks = after

(* a floor with four waypoints in a row, each leading to its
 * neighbours, and a fifth nobody leads to *)
let road : Soldat_map.t =
  let w = Testutil_map.waypoint in
  Testutil_map.map ~spawns:[ (-600., -20.) ]
    ~waypoints:[ w 1 (-600, -10) [ 2 ]; w 2 (-200, -10) [ 1; 3 ]; w 3 (200, -10) [ 2; 4 ]; w 4 (600, -10) [ 3 ]; w 5 (0, -400) [] ]
    (Testutil_map.slab (-2000.) 0. 2000. 200.)

(* a frame of the keys that are any scene's, these held *)
let frame (keys : string list) (model : Soldat_model.model) : Soldat_model.model =
  let c = Playground.initial_computer in
  let (model, scenes) = Soldat_update.common { c with keyboard = List.fold_left (fun k key -> Playground.update_keyboard true key k) c.keyboard keys } model in
  { model with scenes }

let x (p : Soldat_model.play) (i : int) : float = p.soldiers.(i).body.x

let tests =
  Testo.categorize "Layers"
    [
      Testo.create "a layer's key goes round its levels" (fun () ->
          let level = Soldat_model.level in
          let model = Soldat_model.initial_model (Testutil_map.floor ()) in
          Alcotest.(check (list int)) "each at its highest: Soldat's" [ 3; 3; 2; 2; 2; 3 ] (List.map (level model) [ Graphics; Audio; Effects; Ai; Physics; Interface ]);
          let press key model = frame [] (frame [ key ] (frame [] model)) in
          let once = press "j" model in
          Alcotest.(check int) "j: the effects, round to none" 0 (level once Effects);
          Alcotest.(check bool) "said" true (match once.said with Some ("effects 0: none", _) -> true | _ -> false);
          Alcotest.(check int) "again: the Playground's" 1 (level (press "j" once) Effects);
          Alcotest.(check int) "g: the picture, round to its first, 1" 1 (level (press "g" model) Graphics);
          Alcotest.(check int) "the others are left" 2 (level once Ai);
          (* z: every twin at once, and back *)
          let twins = press "z" model in
          Alcotest.(check (list int)) "z: each at its twin; the picture, which has none, left" [ 3; 2; 1; 1; 1; 2 ]
            (List.map (level twins) [ Graphics; Audio; Effects; Ai; Physics; Interface ]);
          Alcotest.(check bool) "again: Soldat's own" true ((press "z" twins).levels |> List.sort compare = List.sort compare model.levels);
          Alcotest.(check int) "one of them moved by hand: z puts them all at their twins" 1 (level (press "z" (press "j" twins)) Effects);
          (* asked at the start; a level that is none is the nearest *)
          let basic = Soldat_model.initial_model ~levels:[ (Ai, 0); (Graphics, 0); (Audio, 9) ] (Testutil_map.floor ()) in
          Alcotest.(check (list int)) "asked for" [ 0; 1; 3 ] (List.map (level basic) [ Ai; Graphics; Audio ]));
      Testo.create "the bots: standing, the Playground's, Soldat's" (fun () ->
          let p = after 100 (Soldat_update.start ~bots:(Soldat_bots.cast 2 0) road) in
          let stand = after 300 { p with ai = 0 } in
          (* a few units to come to a stop, no more *)
          Alcotest.(check (near 5.)) "0: they stand" (x p 1) (x stand 1);
          let twin = after 300 { p with ai = 1 } in
          Alcotest.(check bool) "1: every bot has the twin's mind, and goes" true (Soldat_engine_bot.running twin.minds.(1) <> None && Soldat_engine_bot.running twin.minds.(2) <> None && Float.abs (x twin 1 -. x p 1) > 50.);
          let soldat = after 300 p in
          Alcotest.(check bool) "2: Soldat's, without it" true (Soldat_engine_bot.running soldat.minds.(1) = None && Soldat_bots.brain_of soldat.minds.(1) <> None));
      Testo.create "the twin's way: the cheapest path" (fun () ->
          let next from goal = Option.map (fun (w : Pms.waypoint) -> w.x) (Soldat_engine_bot.way road from goal) in
          Alcotest.(check (option int)) "at the first waypoint, to the last: the second" (Some (-200)) (next (-600., -10.) (600., -10.));
          Alcotest.(check (option int)) "far from any: the nearest first" (Some 200) (next (150., -10.) (600., -10.));
          Alcotest.(check (option int)) "back the other way" (Some (-200)) (next (200., -10.) (-600., -10.));
          Alcotest.(check (option int)) "to where no path leads: none" None (next (-600., -10.) (0., -400.));
          Alcotest.(check (option int)) "no waypoints: none" None (Option.map (fun (w : Pms.waypoint) -> w.x) (Soldat_engine_bot.way (Testutil_map.floor ()) (0., 0.) (9., 9.))));
      Testo.create "the effects: none, Juice's, Soldat's" (fun () ->
          let p = after 100 (Soldat_update.start ~bots:[] (Testutil_map.floor ())) in
          (* a grenade going off 300 units away *)
          let grenade = { (Soldat_bullets.of_shot ~owner:0 { from = (300., -40.); velocity = (0., 1.); weapon = Grenade }) with ttl = 1 } in
          let blast effects = after 2 { p with effects; bullets = [ grenade ] } in
          let (none, juice, soldat) = (blast 0, blast 1, blast 2) in
          let dots (p : Soldat_model.play) = List.length (Soldat_juice.dots (Soldat_juice.of_fx p.fx)) in
          Alcotest.(check (pair int int)) "0: nothing" (0, 0) (List.length (Soldat_sparks.of_fx none.fx), dots none);
          Alcotest.(check bool) "1: the emitter's dots, no spark" true (Soldat_sparks.of_fx (juice.fx) = [] && dots juice >= 50);
          Alcotest.(check bool) "and the screen shaken" true (Soldat_juice.shake (Soldat_juice.of_fx juice.fx) <> (0., 0.));
          Alcotest.(check bool) "2: Soldat's sparks, no dot" true (Soldat_sparks.of_fx (soldat.fx) <> [] && dots soldat = 0);
          Alcotest.(check bool) "three seconds later: the dots are gone, the screen still" true (dots (after 180 juice) = 0 && Soldat_juice.shake (Soldat_juice.of_fx (after 180 juice).fx) = (0., 0.));
          (* heard the same, whatever is seen *)
          let heard effects = (after 1 { p with effects; bullets = [ grenade ] }).sounds in
          Alcotest.(check bool) "the sounds are the same in all three" true (heard 0 <> [] && heard 0 = heard 1 && heard 1 = heard 2));
      Testo.create "the physics: the dead stay, or fall" (fun () ->
          let p = after 100 (Soldat_update.start ~bots:(Soldat_bots.cast 1 0) Testutil_map.rooms) in
          let (bx, by) = Soldat_bullets.place p.soldiers.(1) in
          let shot = Soldat_bullets.of_shot ~owner:0 { from = (bx -. 30., by); velocity = (55., 0.); weapon = Barrett } in
          let head (p : Soldat_model.play) = match p.soldiers.(1).dead with Some (_, r) -> r.points.(11).pos | None -> Alcotest.fail "not dead" in
          let dead physics = after 3 { p with physics; bullets = [ shot ] } in
          let (still, falls) = (dead 0, dead 2) in
          Alcotest.(check bool) "0: the body stays as it was hit" true (head still = head (after 40 still));
          Alcotest.(check bool) "2: it falls" true (snd (head (after 40 falls)) > snd (head falls) +. 3.));
      Testo.create "the things' twin: a rigid body" (fun () ->
          let floor = Testutil_map.floor () in
          (* a kit and a weapon let go 100 above the floor, whose top is at y = 0 *)
          let kit = Option.get (Soldat_things.bonus (Testutil_map.map ~spawns:[ (50., -100.) ] (Testutil_map.slab (-2000.) 0. 2000. 200.)) ~random:(fun () -> 0.5) Vest_kit) in
          let gun = Soldat_things.lying Ak74 (300., -100.) in
          let rec fall n (t : Soldat_things.t) = if n = 0 || t.still then (n, t) else fall (n - 1) (Soldat_bodies.move floor t) in
          let lowest (t : Soldat_things.t) = Array.fold_left (fun y (p : Particles.particle) -> Float.max y (snd p.pos)) (-1e9) t.points in
          let side (t : Soldat_things.t) = let (ax, ay) = t.points.(0).pos and (bx, by) = t.points.(1).pos in Float.hypot (bx -. ax) (by -. ay) in
          List.iter
            (fun (name, thing) ->
              let (left, rested) = fall 600 thing in
              Alcotest.(check bool) (name ^ ": it comes to rest") true (left > 0 && rested.still);
              Alcotest.(check bool) (Printf.sprintf "%s: on the floor, not through it (%.2f)" name (lowest rested)) true (lowest rested > -3. && lowest rested < 1.5);
              Alcotest.(check (near 0.01)) (name ^ ": its shape is kept") (side thing) (side rested);
              (* a tick of free fall, in its four steps: each adds its
               * part of gravity's 0.06 to the speed, then moves:
               * 0.06 / 16 x (1 + 2 + 3 + 4) = 0.0375 *)
              let (_, one) = fall 1 thing in
              Alcotest.(check (near 0.001)) (name ^ ": a tick's fall") 0.0375 (lowest one -. lowest thing))
            [ ("a kit", kit); ("a weapon", gun) ];
          (* in a round, at the physics' level 1 *)
          let p = after 100 (Soldat_update.start ~bots:[] floor) in
          let p = after 300 { p with physics = 1; things = [ Soldat_things.lying Ak74 (300., -100.) ] } in
          Alcotest.(check bool) "in a round: the weapon lies on the floor" true (match p.things with [ t ] -> t.still && lowest t > -3. && lowest t < 1.5 | _ -> false));
      Testo.create "the dead body's twin: limbs and joints" (fun () ->
          let floor = Testutil_map.floor () in
          (* a soldier let loose 80 above the floor, going right at 2 a tick *)
          let body = Soldat_soldier.create (0., -100.) 190 in
          let dead = Soldat_ragdoll.of_soldier body ~push:(2., 0.) in
          let at (r : Soldat_ragdoll.t) n = r.points.(n - 1).pos in
          let far (r : Soldat_ragdoll.t) a b = let (ax, ay) = at r a and (bx, by) = at r b in Float.hypot (bx -. ax) (by -. ay) in
          let rec after n r = if n = 0 then r else after (n - 1) (Soldat_limbs.tumble floor r) in
          let one = after 1 dead in
          Alcotest.(check bool) "a tick: it falls, and goes right" true (snd (at one 12) > snd (at dead 12) && fst (at one 12) > fst (at dead 12) +. 1.);
          let lying = after 400 dead in
          let lowest = Array.fold_left (fun y (p : Particles.particle) -> Float.max y (snd p.pos)) (-1e9) lying.points in
          let highest = Array.fold_left (fun y (p : Particles.particle) -> Float.min y (snd p.pos)) 1e9 lying.points in
          Alcotest.(check bool) (Printf.sprintf "on the floor, not through it (%.1f)" lowest) true (lowest > -4. && lowest < 4.);
          Alcotest.(check bool) (Printf.sprintf "lying down: no point more than a body's width up (%.1f)" highest) true (highest > -16.);
          (* rigid limbs: as long as they were *)
          Alcotest.(check (near 0.05)) "its arm is as long as it was" (far dead 10 13) (far lying 10 13);
          Alcotest.(check (near 0.05)) "its thigh too" (far dead 5 4) (far lying 5 4);
          (* at rest *)
          let next = after 1 lying in
          Alcotest.(check bool) "and it lies still" true (Float.hypot (fst (at next 12) -. fst (at lying 12)) (snd (at next 12) -. snd (at lying 12)) < 0.2);
          Alcotest.(check bool) (Printf.sprintf "not slid out of sight (%.0f)" (fst (at lying 12))) true (Float.abs (fst (at lying 12)) < 300.);
          (* in a round, at the physics' level 1: a soldier shot dead ends lying on its room's floor *)
          let p = after_ticks 100 (Soldat_update.start ~bots:(Soldat_bots.cast 1 0) Testutil_map.rooms) in
          let (bx, by) = Soldat_bullets.place p.soldiers.(1) in
          let shot = Soldat_bullets.of_shot ~owner:0 { from = (bx -. 30., by); velocity = (55., 0.); weapon = Barrett } in
          let p = after_ticks 150 { p with physics = 1; bullets = [ shot ] } in
          (match p.soldiers.(1).dead with
          | Some (_, r) ->
              let low = Array.fold_left (fun y (q : Particles.particle) -> Float.max y (snd q.pos)) (-1e9) r.points in
              Alcotest.(check bool) (Printf.sprintf "in a round: the dead lies on the floor (%.1f)" low) true (low > -6. && low < 4.)
          | None -> Alcotest.fail "not dead"));
      Testo.create "the sound: how loud, from where, at each level" (fun () ->
          let heard level = Soldat_sound.level := level; let h = Soldat_sound.heard ~listener:(0., 0.) (300., 0.) in Soldat_sound.level := 3; h in
          let at = Alcotest.(option (pair (near 0.001) (near 0.001))) in
          Alcotest.(check at) "0: nothing" None (heard 0);
          Alcotest.(check at) "1: as loud, in the middle" (Some (1., 0.)) (heard 1);
          (* Space: 100 / 300; 300 to the right of a listener 300 behind the screen: sin 45 *)
          Alcotest.(check at) "2: the Playground's Space" (Some (0.3333, 0.7071)) (heard 2);
          (* Soldat's: 1 - 300 / 750; 300 / hypot 300 1000 *)
          Alcotest.(check at) "3: Soldat's" (Some (0.6, 0.2873)) (heard 3));
    ]
