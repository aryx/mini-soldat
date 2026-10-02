(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_teams.mli *)

let near = Alcotest.float

(* a floor with the two teams' places 800 apart and their flags 600:
 * Alpha's on the left *)
let field : Soldat_map.t =
  Testutil_map.map ~spawns:[ (0., -20.) ] ~alpha_spawns:[ (-400., -20.) ] ~bravo_spawns:[ (400., -20.) ] ~alpha_flag:(-300., -14.) ~bravo_flag:(300., -14.)
    (Testutil_map.slab (-2000.) 0. 2000. 200.)

let bots n = Soldat_bots.cast n 0

(* the round, its soldiers standing on the floor, past their first 90
 * ticks; nobody sees anybody across 800 units *)
let round ?(n = 1) ?mode () : Soldat_model.play =
  let p = ref (Soldat_update.start ~bots:(bots n) ?mode field) in
  for _ = 1 to 100 do
    p := Soldat_update.tick !p Soldat_model.still ~look:(0., 0.)
  done;
  !p

let tick (p : Soldat_model.play) : Soldat_model.play = Soldat_update.tick p Soldat_model.still ~look:(0., 0.)
let rec after n p = if n = 0 then p else after (n - 1) (tick p)

(* soldier [i] put at a place, as it is *)
let put (i : int) (at : float * float) (p : Soldat_model.play) : Soldat_model.play =
  let move (s : Soldat_model.soldier) =
    let body = Soldat_soldier.create ~primary:s.body.weapon.kind.id ~human:s.human ~team:s.body.team at 190 in
    { s with body = { body with ceasefire = 0 } }
  in
  { p with soldiers = Array.mapi (fun j s -> if j = i then move s else s) p.soldiers }

(* a team's flag *)
let flag (p : Soldat_model.play) (team : int) : Soldat_things.t = List.find (fun (t : Soldat_things.t) -> t.kind = Flag team) p.things
let foot (t : Soldat_things.t) : float * float = t.points.(0).pos
let words (p : Soldat_model.play) : string = match p.news with Some (w, _) -> w | None -> ""

let tests =
  Testo.categorize "Teams"
    [
      Testo.create "who is on which team" (fun () ->
          Alcotest.(check bool) "Arena2 is a deathmatch's" true (Soldat_model.mode_of (Lazy.force Soldat_map.arena2) = Deathmatch);
          Alcotest.(check bool) "a map with the two flags' places: capture the flag" true (Soldat_model.mode_of field = Capture_the_flag);
          let p = Soldat_update.start ~bots:(bots 3) field in
          Alcotest.(check (list int)) "the player Alpha's; the bots Bravo's, Alpha's, Bravo's" [ 1; 2; 1; 2 ] (Array.to_list (Array.map Soldat_model.team p.soldiers));
          Alcotest.(check bool) "each in its team's colour" true
            (Array.for_all (fun (s : Soldat_model.soldier) -> s.shirt = Soldat_model.team_shirt (Soldat_model.team s)) p.soldiers);
          Alcotest.(check (list (near 0.1))) "each at its team's place" [ -400.; 400.; -400.; 400. ]
            (Array.to_list (Array.map (fun (s : Soldat_model.soldier) -> s.body.x) p.soldiers));
          Alcotest.(check int) "and the two flags" 2 (List.length p.things);
          (* asked as a deathmatch: no teams, no flags *)
          let dm = Soldat_update.start ~bots:(bots 3) ~mode:Deathmatch field in
          Alcotest.(check bool) "as a deathmatch: nobody's" true (Array.for_all (fun s -> Soldat_model.team s = 0) dm.soldiers && dm.things = []);
          (* as a team match: teams, no flags *)
          let tm = Soldat_update.start ~bots:(bots 3) ~mode:Team_match field in
          Alcotest.(check bool) "as a team match: teams, no flags" true (Soldat_model.team tm.soldiers.(1) = 2 && tm.things = []);
          (* the dead come back at their team's place *)
          let p = round () in
          let dead = { p with soldiers = Array.mapi (fun j (s : Soldat_model.soldier) -> if j = 1 then { s with dead = Some (0, Soldat_ragdoll.of_soldier s.body ~push:(0., 0.)) } else s) p.soldiers } in
          let back = (after 200 dead).soldiers.(1) in
          Alcotest.(check bool) "back at Bravo's place, Bravo's still" true (back.dead = None && Float.abs (back.body.x -. 400.) < 30. && Soldat_model.team back = 2));
      Testo.create "a team's bullets, a team's walls" (fun () ->
          let p = round ~n:2 () in
          let me = p.soldiers.(0) in
          let (hx, hy) = Soldat_soldier.point me.body 5 in
          let shot owner = Soldat_bullets.of_shot ~owner { from = (hx -. 25., hy); velocity = (19., 0.); weapon = Eagles } in
          let health owner = let (soldiers, _, _) = Soldat_bullets.tick p.map p.soldiers [ shot owner ] in soldiers.(0).health in
          (* soldier 1 is Bravo's, soldier 2 Alpha's as the player *)
          Alcotest.(check (near 0.01)) "the other team's hurts" (150. -. (19. *. 1.81 *. 0.95)) (health 1);
          Alcotest.(check (near 0.01)) "one's own team's does not" 150. (health 2);
          let grenade = { (Soldat_bullets.of_shot ~owner:0 { from = (hx, hy); velocity = (0., 0.); weapon = Grenade }) with ttl = 1 } in
          let (soldiers, _, _) = Soldat_bullets.tick p.map p.soldiers [ grenade ] in
          Alcotest.(check bool) "one's own grenade does" true (soldiers.(0).dead <> None);
          (* walls *)
          Alcotest.(check (list bool)) "Alpha's wall stops Alpha's soldiers only" [ true; false; false ]
            (List.map (fun team -> Soldat_map.stops_soldier ~team (Team_players 1)) [ 1; 2; 0 ]);
          Alcotest.(check (list bool)) "and no bullet" [ false; false ] (List.map (fun team -> Soldat_map.stops_bullet ~team (Team_players 1)) [ 1; 2 ]);
          Alcotest.(check (list bool)) "a wall for Bravo's bullets stops those only" [ false; true ]
            (List.map (fun team -> Soldat_map.stops_bullet ~team (Team_bullets 2)) [ 1; 2 ]);
          (* a floor of Alpha's: an Alpha stands on it, a Bravo falls through *)
          let floor = Testutil_map.floor ~kind:(Team_players 1) () in
          let fall team =
            let s = ref (Soldat_soldier.create ~team (0., -20.) 190) in
            for i = 1 to 120 do
              s := Soldat_soldier.tick floor ~ticks:i ~random:(fun () -> 0.5) !s Soldat_soldier.no_control
            done;
            !s.y
          in
          Alcotest.(check bool) "on Alpha's floor an Alpha stands" true (fall 1 < 0.);
          Alcotest.(check bool) "and a Bravo falls through" true (fall 2 > 100.));
      Testo.create "a flag at home" (fun () ->
          let p = round () in
          let red = flag p 1 and blue = flag p 2 in
          Alcotest.(check bool) "both at home" true (red.in_base && blue.in_base);
          (* a pole of 24, standing: its top above its foot *)
          let (fx, fy) = foot red and (tx, ty) = red.points.(1).pos in
          Alcotest.(check (near 1.)) "its foot on the floor" 0. fy;
          (* leaning: its cloth's corner is on the ground and pulls its top *)
          Alcotest.(check bool) "its pole up, leaning to its cloth" true (ty < fy -. 15. && Float.abs (tx -. fx) < 16.);
          Alcotest.(check (near 0.5)) "24 long" 24. (Float.hypot (tx -. fx) (ty -. fy));
          (* as they are made, before their cloths fall *)
          let fresh = Soldat_update.start ~bots:(bots 1) field in
          Alcotest.(check bool) "Alpha's cloth to the right, Bravo's to the left" true
            (fst (flag fresh 1).points.(2).pos > fst (flag fresh 1).points.(1).pos && fst (flag fresh 2).points.(2).pos < fst (flag fresh 2).points.(1).pos);
          ignore blue;
          (* still there, still up, a minute later *)
          let later = flag (after 3600 p) 1 in
          Alcotest.(check bool) "a minute later: the same" true (later.in_base && Float.abs (fst (foot later) -. fx) < 2. && snd later.points.(1).pos < -15.);
          (* its own team walks over it: left there *)
          let q = after 5 (put 0 (-300., -5.) p) in
          Alcotest.(check bool) "its own team's at home: not taken" true ((flag q 1).holder < 0 && (flag q 1).in_base));
      Testo.create "taken, carried, dropped, returned" (fun () ->
          let p = round () in
          (* the player, Alpha's, on Bravo's flag *)
          let q = tick (put 0 (300., -5.) p) in
          Alcotest.(check int) "the other team's takes it" 0 (flag q 2).holder;
          Alcotest.(check string) "it is said" "YOU captured the Blue Flag" (words q);
          Alcotest.(check bool) "and heard" true (List.mem_assoc Soldat_sfx.Capture q.sounds);
          (* carried: its foot at its carrier's waist, wherever that goes *)
          let q = after 120 (put 0 (100., -5.) q) in
          let (wx, wy) = Soldat_soldier.point q.soldiers.(0).body 8 in
          Alcotest.(check (pair (near 0.5) (near 0.5))) "its foot at the carrier's waist" (wx, wy) (foot (flag q 2));
          Alcotest.(check bool) "away from home" false (flag q 2).in_base;
          Alcotest.(check bool) "its pole held up, over the shoulder" true (snd (flag q 2).points.(1).pos < wy -. 10.);
          (* in its first 90 ticks a soldier takes none *)
          let fresh = tick { p with soldiers = Array.mapi (fun j (s : Soldat_model.soldier) -> if j = 0 then { s with body = Soldat_soldier.create ~team:1 (300., -5.) 190 } else s) p.soldiers } in
          Alcotest.(check int) "not in its first 90 ticks" (-1) (flag fresh 2).holder;
          (* its carrier dies: it falls where it is *)
          (* (Bravo's bot sent far away: it would come and take its flag home) *)
          let q = put 1 (1500., -5.) q in
          let dead = { q with soldiers = Array.mapi (fun j (s : Soldat_model.soldier) -> if j = 0 then { s with dead = Some (0, Soldat_ragdoll.of_soldier s.body ~push:(0., 0.)) } else s) q.soldiers } in
          let d = after 60 dead in
          Alcotest.(check (pair int bool)) "its carrier dead: on the ground, nobody's" (-1, false) ((flag d 2).holder, (flag d 2).in_base);
          (* it bounces as it lands: not far *)
          Alcotest.(check bool) "near where it fell" true (Float.abs (fst (foot (flag d 2)) -. 100.) < 150.);
          (* one of its own touches it: home at once *)
          let r = tick (put 1 (fst (foot (flag d 2)), -5.) d) in
          Alcotest.(check bool) "one of its own: home at once" true ((flag r 2).in_base && Float.abs (fst (foot (flag r 2)) -. 300.) < 2.);
          Alcotest.(check bool) "it is said" true (String.ends_with ~suffix:"returned the Blue Flag" (words r));
          (* left there: home by itself after 25 seconds *)
          let far = put 1 (1500., -5.) d in
          Alcotest.(check bool) "24 seconds on the ground: still there" false (flag (after 1380 far) 2).in_base;
          Alcotest.(check bool) "25: home by itself" true (flag (after 1500 far) 2).in_base);
      Testo.create "a capture" (fun () ->
          let p = round () in
          let carrying = tick (put 0 (300., -5.) p) in
          (* brought to one's own flag, at home *)
          let home = after 3 (put 0 (-298., -5.) carrying) in
          Alcotest.(check (pair int int)) "a flag for Alpha" (1, 0) home.captures;
          Alcotest.(check string) "it is said" "Alpha Team scores! (YOU)" (words home);
          Alcotest.(check bool) "Bravo's flag is home again, nobody's" true ((flag home 2).in_base && (flag home 2).holder < 0);
          Alcotest.(check int) "Alpha's points" 1 (Soldat_model.score home 1);
          (* not while one's own flag is away *)
          let away = { carrying with things = List.map (fun (t : Soldat_things.t) -> if t.kind = Flag 1 then { t with in_base = false; holder = 1 } else t) carrying.things } in
          let no = after 3 (put 0 (-298., -5.) away) in
          Alcotest.(check (pair int int)) "not while one's own is away" (0, 0) no.captures;
          (* who wins *)
          Alcotest.(check (option string)) "nobody yet" None (Soldat_update.winner home);
          Alcotest.(check (option string)) "10 flags: Alpha" (Some "ALPHA TEAM") (Soldat_update.winner { home with captures = (10, 3) });
          Alcotest.(check (option string)) "the time over: who has most" (Some "BRAVO TEAM") (Soldat_update.winner { home with captures = (1, 2); time_left = 0 });
          Alcotest.(check (option string)) "as many each: nobody" (Some "NOBODY") (Soldat_update.winner { home with captures = (2, 2); time_left = 0 });
          (* a team match: a team's kills *)
          let tm = round ~n:3 ~mode:Team_match () in
          let with_kills = { tm with soldiers = Array.mapi (fun j (s : Soldat_model.soldier) -> { s with kills = (if j = 0 then 25 else if j = 2 then 35 else 10) }) tm.soldiers } in
          Alcotest.(check (pair int int)) "a team's points are its soldiers' kills" (60, 20) (Soldat_model.score with_kills 1, Soldat_model.score with_kills 2);
          Alcotest.(check (option string)) "60: the match is Alpha's" (Some "ALPHA TEAM") (Soldat_update.winner with_kills));
      Testo.create "the bots, in teams" (fun () ->
          let keys (p : Soldat_model.play) i = let (c, brain, _) = Soldat_bots.control p i (Option.get p.brains.(i)) ~random:(fun () -> 0.5) in (c, brain) in
          (* soldier 1 Bravo's, soldier 2 Alpha's; the player Alpha's *)
          let p = round ~n:2 () |> put 1 (0., -20.) |> put 2 (1500., -20.) in
          let (c, _) = keys (put 0 (150., -20.) p) 1 in
          Alcotest.(check bool) "an enemy in sight: it fires" true c.fire;
          let (c, _) = keys (put 0 (150., -20.) p) 2 in
          Alcotest.(check bool) "far from everyone: nothing" false c.fire;
          (* its own team's is no target *)
          let friends = put 0 (150., -20.) (put 2 (0., -20.) (put 1 (-1500., -20.) p)) in
          let (c, _) = keys friends 2 in
          Alcotest.(check bool) "one of its own beside it: it does not" false c.fire;
          (* the enemy's flag at home, seen from near: it goes *)
          let by_flag = put 2 (250., -20.) (put 1 (-1500., -20.) (put 0 (-1500., -40.) p)) in
          let (c, brain) = keys by_flag 2 in
          Alcotest.(check bool) "the enemy's flag 50 away: it goes to it" true (c.right && brain.go_thing);
          let (c, brain) = keys (put 2 (100., -20.) by_flag) 2 in
          Alcotest.(check bool) "200 away: not yet (its waypoints lead there)" false (c.right && brain.go_thing);
          (* its own flag on the ground, away from home: it goes *)
          let dropped = { by_flag with things = List.map (fun (t : Soldat_things.t) -> if t.kind = Flag 1 then { t with in_base = false; points = Array.map (fun (q : Particles.particle) -> Particles.particle (fst q.pos +. 400., snd q.pos)) t.points } else t) by_flag.things } in
          let (c, brain) = keys (put 2 (0., -20.) dropped) 2 in
          Alcotest.(check bool) "its own flag lying 100 away: it goes" true (c.right && brain.go_thing));
      Testo.create "capture the flag on ctf_Ash" (fun () ->
          let chan = open_in_bin "../../data/maps/ctf_Ash.pms" in
          let bytes = Fun.protect ~finally:(fun () -> close_in chan) (fun () -> really_input_string chan (in_channel_length chan)) in
          let map = match Pms.parse bytes with Ok pms -> Soldat_map.of_pms pms | Error why -> Alcotest.fail why in
          Alcotest.(check bool) "a map for it" true (Soldat_model.mode_of map = Capture_the_flag);
          Alcotest.(check (pair int int)) "three places for each team" (3, 3) (List.length map.alpha_spawns, List.length map.bravo_spawns);
          let p = ref (Soldat_update.start ~bots:(Soldat_bots.cast 5 1) map) in
          let said = ref [] in
          for _ = 1 to 4500 do
            p := tick !p;
            match !p.news with Some (w, 180) -> said := w :: !said | _ -> ()
          done;
          let has part = List.exists (fun w -> let n = String.length part in let rec at i = i + n <= String.length w && (String.sub w i n = part || at (i + 1)) in at 0) !said in
          Alcotest.(check bool) "in 75 seconds a flag is taken" true (has "captured the");
          Alcotest.(check bool) "and one brought home" true (fst !p.captures + snd !p.captures >= 1 && has "Team scores"));
    ]
