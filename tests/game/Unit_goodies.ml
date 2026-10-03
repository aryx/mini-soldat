(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_goodies.mli *)

let near = Alcotest.float
let floor = Testutil_map.floor ()
let full = Soldat_model.full_health
let looking : Soldat_soldier.control = { Soldat_soldier.no_control with aim = (10000., -12.) }

(* a soldier with this weapon standing on the floor at x, looking
 * right, past the ticks during which it may not fire *)
let armed ?(x = 0.) (id : Soldat_weapons.id) : Soldat_soldier.t =
  let s = ref (Soldat_soldier.create ~primary:id (x, -20.) 190) in
  for i = 1 to 120 do
    s := Soldat_soldier.tick floor ~ticks:i ~random:(fun () -> 0.5) !s looking
  done;
  !s

(* the two soldiers of a round, the first with this weapon, the second
 * [gap] to its right, unarmed and still *)
let pair ?(gap = 14.) (id : Soldat_weapons.id) : Soldat_model.soldier array =
  let p = Soldat_update.start ~bots:(Soldat_bots.cast 1 0) floor in
  [| { (p.soldiers.(0)) with body = armed id }; { (p.soldiers.(1)) with body = armed ~x:gap Hands } |]

(* [n] ticks of the first holding these keys, its shots flying over the
 * two: the soldiers after, the shots there were, the explosions *)
let play ?(n = 40) (soldiers : Soldat_model.soldier array) (keys : int -> Soldat_soldier.control) =
  let soldiers = ref soldiers and bullets = ref [] and shots = ref [] and blasts = ref [] and knives = ref [] in
  for i = 1 to n do
    let body = Soldat_soldier.tick floor ~ticks:(200 + i) ~random:(fun () -> 0.5) !soldiers.(0).body (keys i) in
    shots := !shots @ body.shots;
    let (w, left) = Soldat_bullets.run floor (Array.mapi (fun j s -> if j = 0 then { s with Soldat_model.body } else s) !soldiers) (!bullets @ List.map (Soldat_bullets.of_shot ~owner:0) body.shots) in
    soldiers := w.soldiers;
    bullets := left;
    blasts := !blasts @ w.explosions;
    knives := !knives @ w.knives
  done;
  (!soldiers, !shots, !blasts, !knives)

let fire _ = { looking with fire = true }
let health (soldiers : Soldat_model.soldier array) (i : int) : float = soldiers.(i).health

(* a bullet of the first's into the second's chest, from 30 to its left *)
let into (soldiers : Soldat_model.soldier array) (weapon : Soldat_weapons.id) : Soldat_model.bullet =
  let (x, y) = Soldat_bullets.place soldiers.(1) in
  Soldat_bullets.of_shot ~owner:0 { from = (x -. 30., y); velocity = ((Soldat_weapons.get weapon).speed, 0.); weapon }

let after_hit (soldiers : Soldat_model.soldier array) (weapon : Soldat_weapons.id) : Soldat_model.soldier array =
  let (w, _) = Soldat_bullets.run floor soldiers [ into soldiers weapon ] in
  let (w, _) = Soldat_bullets.run floor w.soldiers (List.filter_map Fun.id (Array.to_list w.bullets)) in
  w.soldiers

let tick (p : Soldat_model.play) : Soldat_model.play = Soldat_update.tick p Soldat_model.still ~look:(0., 0.)
let rec after n p = if n = 0 then p else after (n - 1) (tick p)

(* a round alone on the floor, a kit of this kind where the player stands *)
let with_kit (kit : Soldat_things.bonus) : Soldat_model.play =
  let p = after 100 (Soldat_update.start ~bots:[] floor) in
  { p with things = Option.to_list (Soldat_things.bonus p.map ~random:(fun () -> 0.5) kit) }

let tests =
  Testo.categorize "Goodies"
    [
      Testo.create "their numbers" (fun () ->
          let get = Soldat_weapons.get in
          Alcotest.(check bool) "the styles" true
            ((get Knife).style = Melee && (get Chainsaw).style = Melee && (get Hands).style = Melee && (get Law).style = Explosive && (get Flamer).style = Flame
           && (get Thrown_knife).style = Flying_knife && (get Cluster_grenade).style = Thrown && (get Cluster).style = Explosive);
          Alcotest.(check (list int)) "a blow lives a tick, a flame 32" [ 1; 1; 32 ] [ (get Knife).timeout; (get Chainsaw).timeout; (get Flamer).timeout ];
          Alcotest.(check (pair int int)) "the LAW: one rocket, held 13 ticks" (1, 13) ((get Law).ammo, (get Law).startup);
          (* the chainsaw: 8 a tick times 50 *)
          Alcotest.(check (near 0.01)) "the chainsaw in the chest" 400. ((get Chainsaw).speed *. (get Chainsaw).damage));
      Testo.create "a fist, a knife" (fun () ->
          (* a fist: a tenth of 330, times where it lands (0.9 to 1.15) *)
          let (soldiers, shots, _, _) = play ~n:16 (pair Hands) fire in
          let lost = full -. health soldiers 1 in
          Alcotest.(check bool) (Printf.sprintf "a punch takes about 33 (%.1f)" lost) true (lost >= 29.7 -. 0.01 && lost <= 37.95 +. 0.01);
          Alcotest.(check int) "one blow in 16 ticks: at the punch's 11th frame" 1 (List.length shots);
          let (_, shots, _, _) = play ~n:120 (pair Hands) fire in
          Alcotest.(check bool) (Printf.sprintf "the key held: blow after blow (%d in 2 seconds)" (List.length shots)) true (List.length shots >= 3);
          (* out of reach: nothing *)
          let (soldiers, _, _, _) = play (pair ~gap:40. Hands) fire in
          Alcotest.(check (near 0.01)) "40 away: missed" full (health soldiers 1);
          (* a knife: a tenth of 2150 *)
          let (soldiers, _, _, _) = play (pair Knife) fire in
          Alcotest.(check bool) "a knife's blow kills" true (soldiers.(1).dead <> None));
      Testo.create "the knife thrown" (fun () ->
          let speed (s : Soldat_soldier.shot) = Float.hypot (fst s.velocity) (snd s.velocity) in
          (* the key held: thrown at the 16th frame, at 6 x 1.5 *)
          let (soldiers, shots, _, knives) = play ~n:120 (pair ~gap:300. Knife) (fun _ -> { looking with drop = true }) in
          Alcotest.(check bool) "one knife left the hand" true (List.map (fun (s : Soldat_soldier.shot) -> s.weapon) shots = [ Soldat_weapons.Thrown_knife ]);
          Alcotest.(check (near 0.01)) "held: 9 a tick" 9. (speed (List.hd shots));
          Alcotest.(check bool) "the hands are empty" true (soldiers.(0).body.weapon.kind.id = Hands);
          Alcotest.(check int) "and it lies where it fell" 1 (List.length knives);
          (* let go at once: half of it *)
          let (_, shots, _, _) = play (pair ~gap:300. Knife) (fun i -> { looking with drop = i <= 2 }) in
          Alcotest.(check (near 0.01)) "let go at once: 4.5" 4.5 (speed (List.hd shots)));
      Testo.create "the chainsaw" (fun () ->
          let (soldiers, shots, _, _) = play ~n:20 (pair Chainsaw) fire in
          Alcotest.(check bool) "a blow every other tick" true (List.length shots >= 9 && List.length shots <= 11);
          Alcotest.(check bool) "who is against it dies" true (soldiers.(1).dead <> None));
      Testo.create "the LAW" (fun () ->
          let (_, shots, _, _) = play ~n:80 (pair ~gap:200. Law) fire in
          Alcotest.(check int) "standing: it does not fire" 0 (List.length shots);
          let (soldiers, shots, blasts, _) = play ~n:80 (pair ~gap:200. Law) (fun _ -> { looking with fire = true; down = true }) in
          Alcotest.(check int) "crouched: one rocket" 1 (List.length shots);
          Alcotest.(check bool) "which explodes as the M79's, 64 wide" true (List.exists (fun (e : Soldat_model.explosion) -> e.radius = 64.) blasts);
          Alcotest.(check bool) "and kills who it hits" true (soldiers.(1).dead <> None));
      Testo.create "a flame" (fun () ->
          let soldiers = pair Ak74 in
          (* 10.5 a tick times 19: 199.5 in the chest *)
          Alcotest.(check bool) "kills" true ((after_hit soldiers Flamer).(1).dead <> None);
          let fly n = let b = ref [ Soldat_bullets.of_shot ~owner:0 { from = (0., -500.); velocity = (10.5, 0.); weapon = Flamer } ] in
            for _ = 1 to n do let (_, left) = Soldat_bullets.run Testutil_map.empty [||] !b in b := left done; !b in
          Alcotest.(check (pair int int)) "lives 32 ticks" (1, 0) (List.length (fly 31), List.length (fly 32)));
      Testo.create "a cluster grenade" (fun () ->
          (* its time over, in the air: five bits, no explosion yet *)
          let grenade = { (Soldat_bullets.of_shot ~owner:0 { from = (0., -60.); velocity = (2., 4.); weapon = Cluster_grenade }) with ttl = 1 } in
          let (w, bits) = Soldat_bullets.run floor [||] [ grenade ] in
          Alcotest.(check (pair int int)) "five bits, no blast" (5, 0) (List.length bits, List.length w.explosions);
          Alcotest.(check bool) "thrown back up" true (List.for_all (fun (b : Soldat_model.bullet) -> b.weapon = Cluster && b.vy < 0.) bits);
          let blasts = ref [] and bullets = ref bits in
          for _ = 1 to 200 do
            let (w, left) = Soldat_bullets.run floor [||] !bullets in
            blasts := !blasts @ w.explosions;
            bullets := left
          done;
          Alcotest.(check (list (near 0.01))) "five small explosions" [ 35.; 35.; 35.; 35.; 35. ] (List.map (fun (e : Soldat_model.explosion) -> e.radius) !blasts));
      Testo.create "a vest, a berserker, the Flame God" (fun () ->
          let soldiers = pair Ak74 in
          let ak = full -. health (after_hit soldiers Ak74) 1 in
          Alcotest.(check bool) "an Ak-74's bullet takes something" true (ak > 10.);
          let wear (i : int) (s : Soldat_model.soldier) = Array.mapi (fun j o -> if j = i then s else o) soldiers in
          (* a vest: a quarter gets through, a third goes to the vest *)
          let vested = (after_hit (wear 1 { (soldiers.(1)) with vest = 100. }) Ak74).(1) in
          Alcotest.(check (near 0.01)) "a vest: a quarter" (Float.round (0.25 *. ak)) (full -. vested.health);
          Alcotest.(check (near 0.01)) "a third off the vest" (100. -. Float.round (0.33 *. ak)) vested.vest;
          (* a berserker's: four times *)
          let hit = (after_hit (wear 0 { (soldiers.(0)) with bonus = Some (Berserker, 100) }) Ak74).(1) in
          Alcotest.(check (near 0.01)) "a berserker's: four times" (4. *. ak) (full -. hit.health);
          (* the Flame God: nothing *)
          Alcotest.(check (near 0.01)) "the Flame God is not hurt" full (health (after_hit (wear 1 { (soldiers.(1)) with bonus = Some (Flame_god, 100) }) Barrett) 1));
      Testo.create "a kit taken, and its time" (fun () ->
          let words (p : Soldat_model.play) = match p.news with Some (w, _) -> w | None -> "" in
          let me (p : Soldat_model.play) = p.soldiers.(0) in
          let p = after 60 (with_kit Berserker_kit) in
          Alcotest.(check bool) "a berserker for 15 seconds" true (match (me p).bonus with Some (Berserker, ticks) -> ticks > 800 && ticks <= 900 | _ -> false);
          Alcotest.(check (pair string int)) "said, and the kit gone" ("Berserker Mode!", 0) (words p, List.length p.things);
          Alcotest.(check bool) "over after its time" true ((me (after 900 p)).bonus = None);
          (* the flamer: the weapon to the back, and gone with the bonus *)
          let p = after 60 (with_kit Flamer_kit) in
          Alcotest.(check bool) "the flamer in the hands, the Ak-74 behind" true ((me p).body.weapon.kind.id = Flamer && (me p).body.secondary.kind.id = Ak74);
          Alcotest.(check bool) "ten seconds later: empty hands" true ((me (after 600 p)).body.weapon.kind.id = Hands);
          let p = after 60 (with_kit Vest_kit) in
          Alcotest.(check (near 0.01)) "a vest" 100. (me p).vest;
          let p = after 60 (with_kit Cluster_kit) in
          Alcotest.(check (pair int bool)) "three cluster grenades" (3, true) ((me p).body.grenades, (me p).body.cluster);
          let p = after 60 (with_kit Predator_kit) in
          Alcotest.(check bool) "a predator for 25 seconds" true (match (me p).bonus with Some (Predator, ticks) -> ticks > 1400 | _ -> false));
      Testo.create "who killed whom" (fun () ->
          let p = after 100 (Soldat_update.start ~bots:(Soldat_bots.cast 1 0) Testutil_map.rooms) in
          let victim = p.soldiers.(1).name in
          let (x, y) = Soldat_bullets.place p.soldiers.(1) in
          let shot = Soldat_bullets.of_shot ~owner:0 { from = (x -. 30., y); velocity = (55., 0.); weapon = Barrett } in
          let p = after 3 { p with bullets = [ shot ] } in
          Alcotest.(check bool) "said: the killer, the weapon, the killed" true (match p.log with [ ("YOU", Some Barrett, name, ticks) ] -> name = victim && ticks > 400 | _ -> false);
          Alcotest.(check (pair int int)) "a kill for the one, a death for the other" (1, 1) (p.soldiers.(0).kills, p.soldiers.(1).deaths);
          Alcotest.(check int) "for 7 seconds" 0 (List.length (after 420 p).log));
      Testo.create "kits appear, when asked" (fun () ->
          let kits (p : Soldat_model.play) = List.length (List.filter (fun (t : Soldat_things.t) -> match t.kind with Bonus _ -> true | _ -> false) p.things) in
          let played bonuses =
            let p = ref (Soldat_update.start ~bots:[] ~bonuses floor) and seen = ref false in
            for _ = 1 to 6000 do
              p := tick !p;
              let me = !p.soldiers.(0) in
              if kits !p > 0 || me.bonus <> None || me.vest > 0. || me.body.cluster then seen := true
            done;
            !seen
          in
          Alcotest.(check bool) "not by themselves" false (played 0);
          Alcotest.(check bool) "often, at 5" true (played 5));
    ]
