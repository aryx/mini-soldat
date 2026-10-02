(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_soldier.mli. The numbers expected are worked out in the
 * comments from Soldat's constants: gravity 0.06 a tick, a speed kept
 * at 0.99 a tick in the air and at 0.97 more when running on the
 * ground. *)

let still = Soldat_soldier.no_control

(* looking to the right, far away *)
let facing_right : Soldat_soldier.control = { still with aim = (10000., 0.) }

(* [n] ticks, the keys asked of [keys] at each (its number, from 1, and
 * the soldier as it is) *)
let run (map : Soldat_map.t) (s : Soldat_soldier.t) (n : int) (keys : int -> Soldat_soldier.t -> Soldat_soldier.control) : Soldat_soldier.t =
  let s = ref s in
  for i = 1 to n do
    s := Soldat_soldier.tick map ~ticks:i !s (keys i !s)
  done;
  !s

let floor = Testutil_map.floor ()

(* dropped from 20 above the floor, two seconds later *)
let standing () : Soldat_soldier.t = run floor (Soldat_soldier.create (0., -20.) 190) 120 (fun _ _ -> facing_right)

let near = Alcotest.float

let tests =
  Testo.categorize "Soldier"
    [
      Testo.create "a fall's top speed" (fun () ->
          (* each tick v := (v + 0.06) * 0.99: it stops growing at
           * 0.06 * 0.99 / 0.01 = 5.94 *)
          let s = run Testutil_map.empty (Soldat_soldier.create (0., 0.) 190) 900 (fun _ _ -> still) in
          Alcotest.(check (near 0.01)) "5.94 a tick" 5.94 s.vy;
          Alcotest.(check bool) "never on the ground" false s.on_ground;
          Alcotest.(check bool) "its legs fall" true (s.legs.id = Fall));
      Testo.create "standing on a floor" (fun () ->
          let s = standing () in
          Alcotest.(check bool) "on the ground" true s.on_ground;
          (* the feet are tested 2 under the particle *)
          Alcotest.(check (near 0.1)) "the particle 2 above the floor" (-2.) s.y;
          Alcotest.(check (near 0.0001)) "not moving" 0. (Float.abs s.vx +. Float.abs s.vy);
          Alcotest.(check bool) "its legs stand" true (s.legs.id = Stand && s.stance = Standing);
          let later = run floor s 300 (fun _ _ -> facing_right) in
          Alcotest.(check (near 0.001)) "nor a second later: it does not sink" s.y later.y);
      Testo.create "a run" (fun () ->
          (* on the ground v := (v + 0.118) * 0.99 * 0.97: it stops
           * growing near 0.118 * 0.96 / 0.04 = 2.85 *)
          let s = run floor (standing ()) 300 (fun _ _ -> { facing_right with right = true }) in
          Alcotest.(check (near 0.1)) "2.9 a tick" 2.9 s.vx;
          Alcotest.(check bool) "its legs run" true (s.legs.id = Run);
          Alcotest.(check bool) "on the ground still" true s.on_ground;
          let back = run floor (standing ()) 300 (fun _ _ -> { facing_right with left = true }) in
          Alcotest.(check bool) "away from the cursor: backwards" true (back.legs.id = Run_back);
          Alcotest.(check (near 0.1)) "as fast" (-2.9) back.vx;
          let stopped = run floor s 30 (fun _ _ -> facing_right) in
          Alcotest.(check (near 0.0001)) "the key let go: a full stop" 0. stopped.vx);
      Testo.create "a jump: a wind-up, then up" (fun () ->
          let top = ref 0. and left_at = ref 0 in
          let s0 = standing () in
          let _ =
            run floor s0 200 (fun i s ->
                if s.y < !top then top := s.y;
                if !left_at = 0 && not s.on_ground then left_at := i;
                { facing_right with up = i < 40 })
          in
          (* the force is the animation's frames 9 to 14 *)
          Alcotest.(check bool) "on the ground for its first 8 ticks" true (!left_at > 8 && !left_at < 14);
          (* 6 ticks of 0.66 up against 0.06 down: 3.5 a tick, which
           * gravity takes 50 ticks to stop: about 85 up *)
          Alcotest.(check (near 5.)) "85 up" 85. (s0.y -. !top));
      Testo.create "a jump sideways: low and long" (fun () ->
          let top = ref 0. in
          let s0 = standing () in
          let s =
            run floor s0 200 (fun i s ->
                if s.y < !top then top := s.y;
                { facing_right with up = i < 40; right = i < 40 })
          in
          Alcotest.(check bool) "lower than a jump" true (s0.y -. !top > 10. && s0.y -. !top < 25.);
          Alcotest.(check bool) "and far" true (s.x > 60.));
      Testo.create "the jets" (fun () ->
          let s0 = standing () in
          let up = run floor s0 100 (fun _ _ -> { facing_right with jetpack = true }) in
          Alcotest.(check bool) "they lift" true (up.y < s0.y -. 30.);
          Alcotest.(check int) "a tick of fuel a tick" (190 - 100) up.jets;
          let dry = run floor up 200 (fun _ _ -> { facing_right with jetpack = true }) in
          Alcotest.(check int) "until there is none" 0 dry.jets;
          let rested = run floor dry 600 (fun _ _ -> facing_right) in
          Alcotest.(check int) "it comes back at rest, to the map's" 190 rested.jets);
      Testo.create "lying down, crawling, getting up" (fun () ->
          let lying = run floor (standing ()) 60 (fun i _ -> { facing_right with prone = i = 1 }) in
          Alcotest.(check bool) "lying" true (lying.stance = Lying && lying.legs.id = Prone);
          let crawled = run floor lying 200 (fun _ _ -> { facing_right with right = true }) in
          Alcotest.(check bool) "a crawl is slow: 50 in the time a run does 500" true (crawled.x > 30. && crawled.x < 90.);
          Alcotest.(check bool) "still lying" true (crawled.stance = Lying);
          let up = run floor lying 60 (fun i _ -> { facing_right with prone = i = 1 }) in
          Alcotest.(check bool) "the key again: up" true (up.stance = Standing && up.legs.id = Stand));
      Testo.create "crouching, and walking crouched" (fun () ->
          let crouched = run floor (standing ()) 60 (fun _ _ -> { facing_right with down = true }) in
          Alcotest.(check bool) "crouching, its body aiming" true (crouched.stance = Crouching && crouched.body.id = Aim);
          (* v := (v + 0.118 / 0.6) * 0.99 * 0.85: near 1.04 *)
          let walked = run floor crouched 200 (fun _ _ -> { facing_right with down = true; right = true }) in
          Alcotest.(check (near 0.1)) "1 a tick" 1.0 walked.vx);
      Testo.create "a roll" (fun () ->
          let running = run floor (standing ()) 100 (fun _ _ -> { facing_right with right = true }) in
          let rolling = run floor running 5 (fun _ _ -> { facing_right with right = true; down = true }) in
          Alcotest.(check bool) "down while running: legs and body roll" true (rolling.legs.id = Roll && rolling.body.id = Roll);
          let after = run floor rolling 60 (fun _ _ -> { facing_right with right = true; down = true }) in
          Alcotest.(check bool) "then a crouched walk" true (after.legs.id = Crouch_run && after.stance = Crouching));
      Testo.create "ice" (fun () ->
          let ice = Testutil_map.floor ~kind:Ice () in
          let slide map =
            let s = run map (Soldat_soldier.create (0., -20.) 190) 120 (fun _ _ -> facing_right) in
            (run map s 200 (fun i _ -> { facing_right with right = i <= 100 })).vx
          in
          Alcotest.(check (near 0.0001)) "on the ground, a stop" 0. (slide floor);
          Alcotest.(check bool) "on ice, still sliding 100 ticks later" true (slide ice > 0.5));
      Testo.create "which way it faces is the cursor's" (fun () ->
          let s = run floor (standing ()) 5 (fun _ _ -> { still with aim = (-10000., 0.) }) in
          Alcotest.(check int) "left" (-1) s.direction;
          let (hx, _) = Soldat_soldier.point s 12 in
          Alcotest.(check bool) "its head near its particle" true (Float.abs (hx -. s.x) < 6.));
      Testo.create "a tick does not change the soldier it is given" (fun () ->
          let s = standing () in
          let (x, y, legs) = (s.x, s.y, s.legs) in
          ignore (run floor s 50 (fun _ _ -> { facing_right with right = true; up = true }));
          Alcotest.(check bool) "as it was" true (s.x = x && s.y = y && s.legs = legs));
    ]
