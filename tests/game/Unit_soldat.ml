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

(* the player against three of Soldat's bots; two in the three rooms,
 * each then alone in its own: nobody sees anybody *)
let start ?(seed = 1) ?(bots = 3) (map : Soldat_map.t) : Soldat_model.play = Soldat_update.start ~bots:(Soldat_bots.cast bots 1) ~seed map

(* a minute of a four-way fight on Arena2 with the player (soldier 0)
 * standing still: the bots leave where they appeared, along the map's
 * waypoints, and find each other *)
let fight () =
  let p = ref (start (Lazy.force Soldat_map.arena2)) in
  let place i = let s = !p.soldiers.(i) in (s.body.x, s.body.y) in
  let first = Array.init 4 place in
  (* how far each one ever gets from where it started *)
  let roamed = Array.make 4 0. in
  for _ = 1 to 3600 do
    p := tick !p;
    for j = 1 to 3 do
      if !p.soldiers.(j).dead = None && !p.soldiers.(j).kills = 0 then begin
        let (x, y) = place j and (x0, y0) = first.(j) in
        roamed.(j) <- Float.max roamed.(j) (Float.hypot (x -. x0) (y -. y0))
      end
    done
  done;
  for j = 1 to 3 do
    Alcotest.(check bool) (!p.soldiers.(j).name ^ " left where it appeared") true (roamed.(j) > 50.)
  done;
  let kills = Array.fold_left (fun n (s : Soldat_model.soldier) -> n + s.kills) 0 !p.soldiers in
  Alcotest.(check bool) "somebody was killed" true (kills > 0);
  Alcotest.(check int) "a minute less on the clock" (Soldat_model.time_limit - 3600) !p.time_left

(* ai=engine: the last bot is the one on Sense and Bot. In the three
 * rooms, where nobody sees anybody, its senses hold no enemy: it
 * knows only what it has seen, and patrols *)
let engine () =
  let p = Soldat_update.start ~bots:(Soldat_bots.cast 2 1) ~engine:true Testutil_map.rooms in
  Alcotest.(check string) "the last bot is the Engine" "Engine" p.soldiers.(2).name;
  Alcotest.(check bool) "it has a mind, and no brain" true (p.minds.(2) <> None && p.brains.(2) = None);
  Alcotest.(check bool) "the other is Soldat's" true (p.brains.(1) <> None && p.minds.(1) = None);
  let x0 = p.soldiers.(2).body.x in
  let p = ref p and roamed = ref 0. in
  for _ = 1 to 300 do
    p := tick !p;
    roamed := Float.max !roamed (Float.abs (!p.soldiers.(2).body.x -. x0))
  done;
  let senses = Option.get (Bot.last_senses (Option.get !p.minds.(2))) in
  Alcotest.(check bool) "alone in its room: it knows of nobody" true (senses.enemy.position = None);
  Alcotest.(check bool) "and patrols" true (!roamed > 30.);
  Alcotest.(check bool) "while Soldat's, without waypoints, stays" true (Float.abs (!p.soldiers.(1).body.x -. (Soldat_update.start ~bots:(Soldat_bots.cast 2 1) Testutil_map.rooms).soldiers.(1).body.x) < 1.);
  (* an enemy in its room: seen, and 12 ticks later acted on *)
  let me = !p.soldiers.(2).body in
  let beside (s : Soldat_model.soldier) = { s with body = Soldat_soldier.create ~human:true (me.x -. 100., me.y) 190 } in
  let p = ref { !p with soldiers = Array.mapi (fun i s -> if i = 0 then beside s else s) !p.soldiers } in
  p := tick !p;
  let senses = Option.get (Bot.last_senses (Option.get !p.minds.(2))) in
  Alcotest.(check bool) "an enemy in its room: sensed at once" true senses.enemy.visible;
  let fired_by n = let q = ref !p in for _ = 1 to n do q := tick !q done; !q.soldiers.(2).body.weapon.ammo < 40 in
  Alcotest.(check bool) "nothing done about it for 12 ticks" false (fired_by 8);
  (* the 90 ticks of a soldier that just appeared are long over for it *)
  Alcotest.(check bool) "then it fires" true (fired_by 40);
  (* a minute on Arena2 with it: the round goes on, and replays *)
  let arena () = after 1800 (Soldat_update.start ~bots:(Soldat_bots.cast 3 1) ~engine:true (Lazy.force Soldat_map.arena2)) in
  let a = arena () and b = arena () in
  let places (p : Soldat_model.play) = Array.to_list (Array.map (fun (s : Soldat_model.soldier) -> (s.body.x, s.body.y, s.kills)) p.soldiers) in
  Alcotest.(check bool) "a round with it replays the same" true (places a = places b)

(* nothing in a tick is drawn at random: the same round twice *)
let replay () =
  let once () = after 1200 (start (Lazy.force Soldat_map.arena2)) in
  let a = once () and b = once () in
  let places (p : Soldat_model.play) = Array.to_list (Array.map (fun (s : Soldat_model.soldier) -> (s.body.x, s.body.y, s.kills, s.health)) p.soldiers) in
  Alcotest.(check bool) "the same places, kills and health after 20 seconds" true (places a = places b);
  Alcotest.(check int) "and as many bullets in flight" (List.length a.bullets) (List.length b.bullets);
  (* another seed, another round *)
  let c = after 1200 (start ~seed:2 (Lazy.force Soldat_map.arena2)) in
  Alcotest.(check bool) "another seed: another round" true (places a <> places c)

(* dead for three seconds, then back with its health. In the three
 * rooms, where the bots see nobody: the only bullets are the test's *)
let death () =
  (* past the 90 ticks during which one that just appeared is not hit *)
  let p = after 100 (start ~bots:2 Testutil_map.rooms) in
  (* a bullet of BLUE's, about to go through the player's head *)
  let shot (p : Soldat_model.play) : Soldat_model.bullet =
    let (hx, hy) = Soldat_soldier.point p.soldiers.(0).body 12 in
    Soldat_bullets.of_shot ~owner:1 { from = (hx -. 20., hy); velocity = (18., 0.); weapon = Socom }
  in
  let hits = ref 0 and p = ref p in
  while !p.soldiers.(0).dead = None && !hits < 20 do
    p := tick { !p with bullets = [ shot !p ] };
    incr hits
  done;
  (* 18 x 1.49 x 1.1 = 29.5 a bullet in the head, of 150 *)
  Alcotest.(check int) "six bullets in the head" 6 !hits;
  Alcotest.(check int) "a kill for its owner" 1 !p.soldiers.(1).kills;
  let p = after 100 { !p with bullets = [] } in
  Alcotest.(check bool) "still dead 100 ticks later" true (p.soldiers.(0).dead <> None);
  let p = after 100 p in
  Alcotest.(check bool) "back after 180" true (p.soldiers.(0).dead = None);
  Alcotest.(check (float 0.1)) "with all its health" Soldat_model.full_health p.soldiers.(0).health;
  Alcotest.(check bool) "and not to be hit at once" true (p.soldiers.(0).body.ceasefire > 0);
  let p = tick { p with bullets = [ shot p ] } in
  Alcotest.(check (float 0.1)) "a bullet through it then does nothing" Soldat_model.full_health p.soldiers.(0).health

(* what a wall's kind does to who stands on it *)
let walls () =
  (* each in a room of its own: nobody shoots anybody *)
  let on (kind : Pms.kind) (ticks : int) : Soldat_model.soldier = (after ticks (start ~bots:2 (Testutil_map.rooms_on ~kind ()))).soldiers.(0) in
  (* dropped from 20 above the floor: on it within the second *)
  Alcotest.(check bool) "a deadly floor: dead on landing" true ((on Deadly 60).dead <> None);
  Alcotest.(check int) "by its own hand: no kill" 0 (on Deadly 60).kills;
  (* 5 every 10 ticks: 150 is gone in 300 ticks on it *)
  let hurt = on Hurts 200 in
  Alcotest.(check bool) "a hurting floor: about half its health after 200 ticks" true (hurt.dead = None && hurt.health > 40. && hurt.health < 110.);
  Alcotest.(check bool) "dead after 400" true ((on Hurts 400).dead <> None);
  Alcotest.(check (float 0.1)) "a plain floor: nothing" Soldat_model.full_health (on Normal 400).health;
  (* wounded, on a healing floor: 2 every 12 ticks *)
  let p = start ~bots:2 (Testutil_map.rooms_on ~kind:Regenerates ()) in
  let p = after 240 { p with soldiers = Array.map (fun (s : Soldat_model.soldier) -> { s with health = 50. }) p.soldiers } in
  Alcotest.(check bool) "a healing floor: from 50, well over 80 after 4 seconds" true (p.soldiers.(0).health > 80.);
  Alcotest.(check bool) "never over all of it" true ((on Regenerates 400).health <= Soldat_model.full_health)

(* the first to 10 kills; or, the 10 minutes over, who has most *)
let rounds () =
  let p = start ~bots:2 Testutil_map.rooms in
  Alcotest.(check bool) "nobody yet" true (Soldat_update.winner p = None);
  let with_kills i n = { p with soldiers = Array.mapi (fun j (s : Soldat_model.soldier) -> if j = i then { s with kills = n } else s) p.soldiers } in
  Alcotest.(check bool) "9 kills: not yet" true (Soldat_update.winner (with_kills 2 9) = None);
  Alcotest.(check (option string)) "10: the round is its" (Some p.soldiers.(2).name) (Option.map (fun (s : Soldat_model.soldier) -> s.name) (Soldat_update.winner (with_kills 2 10)));
  Alcotest.(check (option string)) "the time over: who has most" (Some "YOU")
    (Option.map (fun (s : Soldat_model.soldier) -> s.name) (Soldat_update.winner { (with_kills 0 3) with time_left = 0 }));
  (* the dead come back at one of the map's places *)
  let p = after 100 p in
  let p = { p with soldiers = Array.mapi (fun j (s : Soldat_model.soldier) -> if j = 0 then { s with dead = Some (0, Soldat_ragdoll.of_soldier s.body ~push:(0., 0.)) } else s) p.soldiers } in
  let p = after 200 p in
  let me = p.soldiers.(0) in
  Alcotest.(check bool) "back after 3 seconds, at a place of the map" true
    (me.dead = None && List.exists (fun (x, _) -> Float.abs (me.body.x -. x) < 30.) p.map.spawns)

let tests =
  Testo.categorize "Soldat"
    [
      Testo.create "the bots fight" fight;
      Testo.create "ai=engine: a bot on Sense and Bot" engine;
      Testo.create "a round's end" rounds;
      Testo.create "a round replays the same" replay;
      Testo.create "shot dead, and back" death;
      Testo.create "deadly, hurting and healing floors" walls;
    ]
