(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_rambo.mli *)

let near = Alcotest.float
let floor = Testutil_map.floor ()
let tick ?(keys = Soldat_model.still) (p : Soldat_model.play) : Soldat_model.play = Soldat_update.tick p keys ~look:(0., 0.)
let rec after ?keys n p = if n = 0 then p else after ?keys (n - 1) (tick ?keys p)

(* three soldiers in the rooms, past their first 90 ticks (the player
 * alone in its own; walls between the rooms); the bow taken off the
 * map: the tests give it *)
let rooms () : Soldat_model.play =
  let p = after 100 (Soldat_update.start ~bots:(Soldat_bots.cast 2 0) ~mode:Rambomatch Testutil_map.rooms) in
  { p with things = List.filter (fun t -> not (Soldat_things.is_bow t)) p.things }

(* soldier [i] with this weapon in its hands *)
let arm (i : int) (id : Soldat_weapons.id) (p : Soldat_model.play) : Soldat_model.play =
  { p with soldiers = Array.mapi (fun j (s : Soldat_model.soldier) -> if j = i then { s with body = { s.body with weapon = Soldat_soldier.gun id } } else s) p.soldiers }

(* a bullet of [owner]'s into soldier [i]'s chest, from 30 units to its left *)
let into (p : Soldat_model.play) (i : int) ~(owner : int) (weapon : Soldat_weapons.id) : Soldat_model.bullet =
  let (x, y) = Soldat_bullets.place p.soldiers.(i) in
  Soldat_bullets.of_shot ~owner { from = (x -. 30., y); velocity = ((Soldat_weapons.get weapon).speed, 0.); weapon }

(* the soldiers after that bullet's flight, in a Rambomatch or not *)
let shot ?(rambo = true) (p : Soldat_model.play) (b : Soldat_model.bullet) : Soldat_model.soldier array =
  let soldiers = ref p.soldiers and bullets = ref [ b ] in
  for _ = 1 to 5 do
    let (s, left, _) = Soldat_bullets.tick ~rambo p.map !soldiers !bullets in
    soldiers := s;
    bullets := left
  done;
  !soldiers

let bows (p : Soldat_model.play) : int = List.length (List.filter Soldat_things.is_bow p.things)
let held (p : Soldat_model.play) (i : int) : Soldat_weapons.id = p.soldiers.(i).body.weapon.kind.id
let words (p : Soldat_model.play) : string = match p.news with Some (w, _) -> w | None -> ""

let tests =
  Testo.categorize "Rambomatch"
    [
      Testo.create "the bow's numbers" (fun () ->
          let bow = Soldat_weapons.get Bow in
          Alcotest.(check (pair int int)) "one arrow, 25 ticks to the next" (1, 25) (bow.ammo, bow.reload_time);
          Alcotest.(check bool) "an arrow" true (bow.style = Arrow);
          (* 21 a tick, times 12: 252 in the chest, of 150; 226.8 in the legs *)
          Alcotest.(check (near 0.01)) "in the chest" 252. (bow.speed *. bow.damage *. Soldat_weapons.modifier bow 8);
          Alcotest.(check (near 0.01)) "in the legs" 226.8 (bow.speed *. bow.damage *. Soldat_weapons.modifier bow 2);
          Alcotest.(check bool) "the bow, with either arrows" true (Soldat_weapons.is_bow Bow && Soldat_weapons.is_bow Bow2 && not (Soldat_weapons.is_bow Ak74)));
      Testo.create "an arrow kills at once" (fun () ->
          let p = rooms () in
          let soldiers = shot p (into p 0 ~owner:1 Bow) in
          Alcotest.(check bool) "dead" true (soldiers.(0).dead <> None);
          Alcotest.(check int) "a kill by the bow counts" 1 soldiers.(1).kills);
      Testo.create "an arrow in a wall stays" (fun () ->
          (* straight down into the floor, whose top is at y = 0 *)
          let fly n bullets = let b = ref bullets in for _ = 1 to n do let (_, left, _) = Soldat_bullets.tick floor [||] !b in b := left done; !b in
          let arrow = Soldat_bullets.of_shot ~owner:0 { from = (50., -60.); velocity = (0., 15.); weapon = Bow } in
          let a = List.hd (fly 10 [ arrow ]) in
          let b = List.hd (fly 100 [ a ]) in
          Alcotest.(check bool) "in the floor" true (a.y > -15. && a.y < 15.);
          Alcotest.(check (pair (near 0.001) (near 0.001))) "a hundred ticks later: where it was" (a.x, a.y) (b.x, b.y);
          Alcotest.(check bool) "its time cut to ARROW_RESIST" true (a.ttl <= 280 && a.ttl > 270);
          Alcotest.(check int) "and then gone" 0 (List.length (fly 280 [ a ]));
          (* one that has stopped harms nobody *)
          let p = rooms () in
          let (x, y) = Soldat_bullets.place p.soldiers.(0) in
          let old = { (into p 0 ~owner:1 Bow) with x = x -. 10.; y; ttl = 200 } in
          Alcotest.(check (near 0.01)) "an old arrow goes through" Soldat_model.full_health (shot p old).(0).health);
      Testo.create "who is hurt, and what a kill is worth" (fun () ->
          let p = rooms () in
          let health soldiers i = (soldiers : Soldat_model.soldier array).(i).health in
          (* nobody is Rambo: all as in a deathmatch, but a kill is worth nothing *)
          Alcotest.(check bool) "nobody Rambo: hurt" true (health (shot p (into p 0 ~owner:1 Ak74)) 0 < Soldat_model.full_health);
          let killed = shot p (into p 0 ~owner:1 Barrett) in
          Alcotest.(check (pair bool int)) "nobody Rambo: killed, for nothing" (true, 0) (killed.(0).dead <> None, killed.(1).kills);
          Alcotest.(check int) "a deathmatch: a kill" 1 (shot ~rambo:false p (into p 0 ~owner:1 Barrett)).(1).kills;
          (* soldier 2 is Rambo *)
          let p = arm 2 Bow p in
          Alcotest.(check bool) "soldier 2 is Rambo" true (Soldat_model.rambo p.soldiers.(2) && not (Soldat_model.rambo p.soldiers.(0)));
          Alcotest.(check (near 0.01)) "the others do nothing to each other" Soldat_model.full_health (health (shot p (into p 0 ~owner:1 Barrett)) 0);
          Alcotest.(check bool) "Rambo is hurt" true (health (shot p (into p 2 ~owner:1 Ak74)) 2 < Soldat_model.full_health);
          Alcotest.(check bool) "and hurts, whatever it fires" true (health (shot p (into p 0 ~owner:2 Ak74)) 0 < Soldat_model.full_health);
          let killed = shot p (into p 2 ~owner:1 Barrett) in
          Alcotest.(check (pair bool int)) "Rambo killed: a kill" (true, 1) (killed.(2).dead <> None, killed.(1).kills);
          (* its second weapon is the bow too *)
          Alcotest.(check bool) "with the other arrows too" true (Soldat_model.rambo (arm 2 Bow2 p).soldiers.(2)));
      Testo.create "the bow: for empty hands, and kept" (fun () ->
          let p = Soldat_update.start ~bots:[] ~mode:Rambomatch floor in
          Alcotest.(check int) "a bow on the map" 1 (bows p);
          (* it lies where one appears: a weapon in the hands, it stays there *)
          let p = after 150 p in
          Alcotest.(check (pair int bool)) "a weapon in the hands: not taken" (1, true) (bows p, held p 0 = Ak74);
          (* f: the weapon thrown away; then the bow is in the hands *)
          let p = after ~keys:{ Soldat_model.still with drop = true } 5 p in
          let p = after 60 p in
          Alcotest.(check bool) "empty hands take it" true (held p 0 = Bow);
          let body = p.soldiers.(0).body in
          Alcotest.(check (pair int bool)) "an arrow on it, the other arrows behind" (1, true) (body.weapon.ammo, body.secondary.kind.id = Bow2);
          Alcotest.(check int) "no bow on the map" 0 (bows p);
          Alcotest.(check string) "said" "You got the Bow!" (words p);
          (* f again: Rambo keeps it *)
          let p = after 60 (after ~keys:{ Soldat_model.still with drop = true } 5 p) in
          Alcotest.(check bool) "it is not thrown away" true (held p 0 = Bow);
          (* and none appears while it is held *)
          Alcotest.(check int) "nor another made" 0 (bows (after 200 p)));
      Testo.create "the bow gives health back" (fun () ->
          let p = arm 0 Bow (rooms ()) in
          let hurt = { p with soldiers = Array.mapi (fun i (s : Soldat_model.soldier) -> if i < 2 then { s with health = 100. } else s) p.soldiers } in
          let later = after 30 hurt in
          (* one every 3 ticks *)
          Alcotest.(check (near 0.01)) "Rambo's: 10 in 30 ticks" 110. later.soldiers.(0).health;
          Alcotest.(check (near 0.01)) "another's: none" 100. later.soldiers.(1).health;
          Alcotest.(check (near 0.01)) "and no more than it had" Soldat_model.full_health (after 300 hurt).soldiers.(0).health);
      Testo.create "the bow let go, and found again" (fun () ->
          (* Rambo killed: the bow falls from its hands *)
          let p = arm 0 Bow2 (rooms ()) in
          let p = { p with frame = 1 } in
          let p = after 3 { p with bullets = [ into p 0 ~owner:1 Barrett ] } in
          Alcotest.(check bool) "Rambo is dead" true (p.soldiers.(0).dead <> None);
          Alcotest.(check int) "the bow is on the ground" 1 (bows p);
          Alcotest.(check bool) "the bow, not its other arrows" true
            (List.exists (fun (t : Soldat_things.t) -> match t.kind with Weapon g -> g.kind.id = Bow | _ -> false) p.things);
          (* lost (here: taken off the map), another appears within a second *)
          let p = { p with things = [] } in
          Alcotest.(check int) "lost: on the map again within a second" 1 (bows (after 61 p)));
      Testo.create "on Arena2, the map's own place for the bow" (fun () ->
          let map = Lazy.force Soldat_map.arena2 in
          let p = Soldat_update.start ~bots:(Soldat_bots.cast 5 1) ~mode:Rambomatch map in
          let bow = List.find Soldat_things.is_bow p.things in
          let (x, y) = Soldat_things.middle bow in
          Alcotest.(check bool) "the bow lies at one of the map's places for it" true
            (map.bow_spawns = [] || List.exists (fun (bx, by) -> Float.hypot (bx -. x) (by -. y) < 1.) map.bow_spawns);
          (* and a round of it plays *)
          let p = after 3000 p in
          Alcotest.(check bool) "at most one bow after 50 seconds" true (bows p + Array.fold_left (fun n s -> if Soldat_model.rambo s then n + 1 else n) 0 p.soldiers <= 1));
      Testo.create "Soldat's bots, after the bow" (fun () ->
          let p = ref (Soldat_update.start ~bots:(Soldat_bots.cast 3 0) ~mode:Rambomatch floor) in
          let was_rambo = ref false and most = ref 0 in
          for _ = 1 to 6000 do
            p := tick !p;
            let rambos = Array.fold_left (fun n s -> if Soldat_model.rambo s then n + 1 else n) 0 !p.soldiers in
            if rambos > 0 then was_rambo := true;
            most := max !most (rambos + bows !p)
          done;
          Alcotest.(check bool) "one of them took it" true !was_rambo;
          Alcotest.(check int) "never two bows" 1 !most;
          Alcotest.(check bool) "and kills were counted" true (Array.exists (fun (s : Soldat_model.soldier) -> s.kills > 0) !p.soldiers));
    ]
