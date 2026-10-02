(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_soldat.mli *)

(* a tick with the player standing still *)
let tick (p : Soldat_model.play) : Soldat_model.play = Soldat_update.tick p Soldat_model.still ~look:(0., 0.)

let after (n : int) (p : Soldat_model.play) : Soldat_model.play =
  let p = ref p in
  for _ = 1 to n do
    p := tick !p
  done;
  !p

(* its bots, both ways (the flag ai=engine): a minute of a three-way
 * fight on Arena2 with the player (soldier 0) standing still. Either
 * way the two bots leave where they appeared; the difference is what
 * they know -- by hand, each one has its enemies'
 * positions through the walls from the first tick; on ai/, it has to
 * see them, and patrols until it does *)
let fight ?(ai_engine = false) () =
  let p = ref (Soldat_model.start ~ai_engine (Lazy.force Soldat_map.arena2)) in
  let place i = let s = !p.soldiers.(i) in (s.body.x, s.body.y) in
  let blue = place 1 and green = place 2 in
  (* how far each one ever gets from where it started: a patrolling bot
   * turns every two seconds, so where it *ends* says nothing *)
  let roamed = [| 0.; 0.; 0. |] in
  for _ = 1 to 3600 do
    p := tick !p;
    List.iter
      (fun (j, (x0, y0)) ->
        let (x, y) = place j in
        roamed.(j) <- Float.max roamed.(j) (Float.hypot (x -. x0) (y -. y0)))
      [ (1, blue); (2, green) ]
  done;
  Alcotest.(check bool) "BLUE left where it appeared" true (roamed.(1) > 50.);
  Alcotest.(check bool) "GREEN too" true (roamed.(2) > 50.);
  (* by hand they find each other, wherever they are. On ai/ they only
   * patrol until they see somebody, and on a map this big, appearing
   * far apart, they may not in a minute: nothing is asked of them *)
  let kills = Array.fold_left (fun n (s : Soldat_model.soldier) -> n + s.kills) 0 !p.soldiers in
  if not ai_engine then Alcotest.(check bool) "somebody was killed" true (kills > 0)

(* what the ai/ layer takes away: a bot that has seen nobody knows
 * nothing, where the hand-written one knows where everyone is. Three
 * ticks in, the ai=engine bots' senses hold no enemy position: each
 * of the three appears in a room of its own *)
let senses () =
  let p = after 3 (Soldat_model.start ~ai_engine:true Testutil_map.rooms) in
  let knows i = match Bot.last_senses p.minds.(i) with Some (s : Soldat_model.senses) -> s.enemy.position <> None | None -> false in
  Alcotest.(check bool) "BLUE has seen nobody yet" false (knows 1);
  Alcotest.(check bool) "GREEN neither" false (knows 2)

(* nothing in a tick is drawn at random: the same round twice *)
let replay () =
  let once () = after 1200 (Soldat_model.start (Lazy.force Soldat_map.arena2)) in
  let a = once () and b = once () in
  let places (p : Soldat_model.play) = Array.to_list (Array.map (fun (s : Soldat_model.soldier) -> (s.body.x, s.body.y, s.kills, s.health)) p.soldiers) in
  Alcotest.(check bool) "the same places, kills and health after 20 seconds" true (places a = places b);
  Alcotest.(check int) "and as many bullets in flight" (List.length a.bullets) (List.length b.bullets)

(* dead for three seconds, then back with its health. In the three
 * rooms, where the bots see nobody: the only bullets are the test's *)
let death () =
  (* past the 90 ticks during which one that just appeared is not hit *)
  let p = after 100 (Soldat_model.start Testutil_map.rooms) in
  (* a bullet of BLUE's, about to go through the player's head *)
  let shot (p : Soldat_model.play) : Soldat_model.bullet =
    let (hx, hy) = Soldat_soldier.point p.soldiers.(0).body 12 in
    { x = hx -. 20.; y = hy; vx = 18.; vy = 0.; owner = 1; ttl = 100 }
  in
  let hits = ref 0 and p = ref p in
  while !p.soldiers.(0).dead = None && !hits < 20 do
    p := tick { !p with bullets = [ shot !p ] };
    incr hits
  done;
  (* 18 x 1.49 x 1.1 = 29.5 a bullet in the head, of 150 *)
  Alcotest.(check int) "six bullets in the head" 6 !hits;
  Alcotest.(check int) "a kill for BLUE" 1 !p.soldiers.(1).kills;
  let p = after 100 { !p with bullets = [] } in
  Alcotest.(check bool) "still dead 100 ticks later" true (p.soldiers.(0).dead <> None);
  let p = after 100 p in
  Alcotest.(check bool) "back after 180" true (p.soldiers.(0).dead = None);
  Alcotest.(check (float 0.1)) "with all its health" Soldat_model.full_health p.soldiers.(0).health;
  Alcotest.(check bool) "and not to be hit at once" true (p.soldiers.(0).safe > 0);
  let p = tick { p with bullets = [ shot p ] } in
  Alcotest.(check (float 0.1)) "a bullet through it then does nothing" Soldat_model.full_health p.soldiers.(0).health

(* what a wall's kind does to who stands on it *)
let walls () =
  let on (kind : Pms.kind) (ticks : int) : Soldat_model.soldier = (after ticks (Soldat_model.start (Testutil_map.floor ~kind ()))).soldiers.(0) in
  (* dropped from 20 above the floor: on it within the second *)
  Alcotest.(check bool) "a deadly floor: dead on landing" true ((on Deadly 60).dead <> None);
  Alcotest.(check int) "by nobody's hand: no kill" 0 (on Deadly 60).kills;
  (* 5 every 10 ticks: 150 is gone in 300 ticks on it *)
  let hurt = on Hurts 200 in
  Alcotest.(check bool) "a hurting floor: about half its health after 200 ticks" true (hurt.dead = None && hurt.health > 40. && hurt.health < 110.);
  Alcotest.(check bool) "dead after 400" true ((on Hurts 400).dead <> None);
  Alcotest.(check (float 0.1)) "a plain floor: nothing" Soldat_model.full_health (on Normal 400).health;
  (* wounded, on a healing floor: 2 every 12 ticks *)
  let p = Soldat_model.start (Testutil_map.floor ~kind:Regenerates ()) in
  let p = after 240 { p with soldiers = Array.map (fun (s : Soldat_model.soldier) -> { s with health = 50. }) p.soldiers } in
  Alcotest.(check bool) "a healing floor: from 50, well over 80 after 4 seconds" true (p.soldiers.(0).health > 80.);
  Alcotest.(check bool) "never over all of it" true ((on Regenerates 400).health <= Soldat_model.full_health)

let tests =
  Testo.categorize "Soldat"
    [
      Testo.create "the bots fight" fight;
      Testo.create "ai=engine, the bots fight" (fight ~ai_engine:true);
      Testo.create "ai=engine, a bot knows only what it has seen" senses;
      Testo.create "a round replays the same" replay;
      Testo.create "shot dead, and back" death;
      Testo.create "deadly, hurting and healing floors" walls;
    ]
