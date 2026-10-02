(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_weapons.mli *)

let near = Alcotest.float
let floor = Testutil_map.floor ()

(* a soldier with this weapon, on the floor, looking right, past the 90
 * ticks during which it may not fire. The chance is always a half:
 * no scatter at all *)
let step ?(map = floor) (s : Soldat_soldier.t) (c : Soldat_soldier.control) (i : int) : Soldat_soldier.t =
  Soldat_soldier.tick map ~ticks:i ~random:(fun () -> 0.5) s c

let looking : Soldat_soldier.control = { Soldat_soldier.no_control with aim = (10000., -12.) }
let firing : Soldat_soldier.control = { looking with fire = true }

let armed (primary : Soldat_weapons.id) : Soldat_soldier.t =
  let s = ref (Soldat_soldier.create ~primary (0., -20.) 190) in
  for i = 1 to 120 do
    s := step !s looking i
  done;
  !s

(* [n] ticks of the keys [keys] gives at each: the soldier after, and
 * what left it at each tick *)
let run ?map (s : Soldat_soldier.t) (n : int) (keys : int -> Soldat_soldier.control) : Soldat_soldier.t * Soldat_soldier.shot list list =
  let s = ref s and shots = ref [] in
  for i = 1 to n do
    s := step ?map !s (keys i) i;
    shots := !s.shots :: !shots
  done;
  (!s, List.rev !shots)

let count shots = List.length (List.concat shots)

(* the ticks, from 1, at which something left *)
let at shots = List.filteri (fun _ l -> l <> []) (List.mapi (fun i l -> if l = [] then [] else [ i + 1 ]) shots) |> List.concat

(* three soldiers in three rooms, past their 90 ticks; nobody sees
 * anybody: the only bullets are the test's *)
let rooms () : Soldat_model.play =
  let p = ref (Soldat_model.start Testutil_map.rooms) in
  for _ = 1 to 100 do
    p := Soldat_update.tick !p Soldat_model.still ~look:(0., 0.)
  done;
  !p

let bullet ?(owner = 1) (weapon : Soldat_weapons.id) (from : float * float) (velocity : float * float) : Soldat_model.bullet =
  Soldat_bullets.of_shot ~owner { from; velocity; weapon }

(* a bullet's tick over the rooms' soldiers *)
let shoot (p : Soldat_model.play) (bullets : Soldat_model.bullet list) = Soldat_bullets.tick p.map p.soldiers bullets

let tests =
  Testo.categorize "Weapons"
    [
      Testo.create "weapons.ini" (fun () ->
          let eagles = Soldat_weapons.get Eagles in
          Alcotest.(check string) "its name" "Desert Eagles" eagles.name;
          Alcotest.(check (near 0.0001)) "Damage" 1.81 eagles.damage;
          Alcotest.(check (list int)) "FireInterval, Ammo, ReloadTime" [ 24; 7; 87 ] [ eagles.fire_interval; eagles.ammo; eagles.reload_time ];
          Alcotest.(check (near 0.0001)) "Speed" 19. eagles.speed;
          (* 87 x 0.8 = 69.6 and 87 x 0.3 = 26.1, cut *)
          Alcotest.(check (pair int int)) "the clip out at 69 of its reload, in at 26" (69, 26) (eagles.clip_out, eagles.clip_in);
          Alcotest.(check bool) "once a pull" true eagles.single_shot;
          Alcotest.(check (list (near 0.0001))) "head, chest, legs" [ 1.1; 0.95; 0.85 ] (List.map (Soldat_weapons.modifier eagles) [ 12; 10; 3 ]);
          Alcotest.(check int) "the Barrett waits 19 ticks" 19 (Soldat_weapons.get Barrett).startup;
          Alcotest.(check bool) "the shotgun fires pellets, and has no clip" true
            ((Soldat_weapons.get Spas).style = Pellets && not (Soldat_weapons.get Spas).clip_reload);
          Alcotest.(check (pair int int)) "so nothing comes out or in" (0, 0) ((Soldat_weapons.get Spas).clip_out, (Soldat_weapons.get Spas).clip_in);
          Alcotest.(check int) "a grenade lives 3 seconds" 180 (Soldat_weapons.get Grenade).timeout;
          Alcotest.(check int) "ten to choose from" 10 (List.length Soldat_weapons.primaries);
          (* a file of one's own *)
          let sections = Soldat_weapons.parse "; a comment\n[USSOCOM]\nDamage=2.5\nnonsense\n Speed = 20 \n" in
          Alcotest.(check (list (pair string (list (pair string (near 0.0001)))))) "sections and numbers" [ ("USSOCOM", [ ("Damage", 2.5); ("Speed", 20.) ]) ] sections;
          Alcotest.(check bool) "a file without all the weapons is refused" true (Result.is_error (Soldat_weapons.of_ini sections)));
      Testo.create "a shot" (fun () ->
          let s = armed Socom in
          let (hx, hy) = Soldat_soldier.point s 15 in
          let (after, shots) = run s 1 (fun _ -> firing) in
          let shot = List.hd (List.concat shots) in
          (* towards the cursor at 18 a tick; standing still, nothing
           * of the soldier's speed *)
          let (dx, dy) = let l = Float.hypot (10000. -. hx) (-12. -. hy) in ((10000. -. hx) /. l, (-12. -. hy) /. l) in
          Alcotest.(check (near 0.01)) "its speed" 18. (Float.hypot (fst shot.velocity) (snd shot.velocity));
          Alcotest.(check (pair (near 0.01) (near 0.01))) "towards the cursor" (dx *. 18., dy *. 18.) shot.velocity;
          Alcotest.(check (pair (near 0.01) (near 0.01))) "from 4 behind the hand, 2 above" (hx -. (dx *. 4.), hy -. (dy *. 4.) -. 2.) shot.from;
          Alcotest.(check int) "a round less" 13 after.weapon.ammo;
          Alcotest.(check bool) "its fire is drawn" true after.fired;
          Alcotest.(check bool) "the body recoils" true (after.body.id = Small_recoil));
      Testo.create "the trigger" (fun () ->
          (* the USSOCOM fires once a pull, however long it is held *)
          let (_, shots) = run (armed Socom) 100 (fun _ -> firing) in
          Alcotest.(check int) "held 100 ticks: one shot" 1 (count shots);
          (* let go a tick in every 20: a shot each time *)
          let (_, shots) = run (armed Socom) 100 (fun i -> if i mod 20 = 0 then looking else firing) in
          Alcotest.(check (list int)) "pulled again: a shot each time" [ 1; 21; 41; 61; 81 ] (at shots);
          (* let go every other tick: as fast as it can, its 10 ticks *)
          let (_, shots) = run (armed Socom) 45 (fun i -> if i mod 2 = 0 then looking else firing) in
          Alcotest.(check (list int)) "as fast as it can" [ 1; 11; 21; 31; 41 ] (at shots);
          (* the Ak-74 goes on, every 11 ticks *)
          let (_, shots) = run (armed Ak74) 45 (fun _ -> firing) in
          Alcotest.(check (list int)) "an automatic: every 11 ticks" [ 1; 12; 23; 34; 45 ] (at shots);
          (* not in its first 90 ticks *)
          let fresh = Soldat_soldier.create ~primary:Ak74 (0., -20.) 190 in
          let (_, shots) = run fresh 100 (fun _ -> firing) in
          Alcotest.(check (list int)) "nothing before 90 ticks" [ 90 ] (at shots));
      Testo.create "the Barrett's wait" (fun () ->
          let (s, shots) = run (armed Barrett) 30 (fun _ -> firing) in
          (* 19 ticks of the trigger held, the shot at the 20th *)
          Alcotest.(check (list int)) "held 19 ticks first" [ 20 ] (at shots);
          Alcotest.(check (near 0.01)) "at 55 a tick" 55. (let v = (List.hd (List.concat shots)).velocity in Float.hypot (fst v) (snd v));
          Alcotest.(check bool) "its own recoil" true (s.body.id = Barret);
          (* let go at the 15th, it starts again *)
          let (_, shots) = run (armed Barrett) 40 (fun i -> if i = 15 then looking else firing) in
          Alcotest.(check (list int)) "let go, the wait starts again" [ 35 ] (at shots));
      Testo.create "the Eagles and the shotgun" (fun () ->
          let (_, shots) = run (armed Eagles) 1 (fun _ -> firing) in
          let two = List.concat shots in
          Alcotest.(check int) "two bullets" 2 (List.length two);
          let (a, b) = (List.nth two 0, List.nth two 1) in
          Alcotest.(check (near 0.01)) "the second 3 beside the first" 3. (Float.hypot (fst a.from -. fst b.from) (snd a.from -. snd b.from));
          let (after, shots) = run (armed Spas) 1 (fun _ -> firing) in
          let six = List.concat shots in
          Alcotest.(check int) "six pellets" 6 (List.length six);
          Alcotest.(check (near 0.01)) "each at 14 a tick" 14. (fst (List.hd six).velocity);
          Alcotest.(check bool) "its own animation" true (after.body.id = Shotgun);
          (* standing, the floor's grip takes the kick. In the air
           * nothing does: falling, aiming to the right, a pellet goes
           * at 14 that way and the soldier 14 x 0.0412 = 0.577 the other *)
          let level i (s : Soldat_soldier.t) : Soldat_soldier.control = ignore i; { Soldat_soldier.no_control with aim = (s.x +. 10000., s.y) } in
          let falling = ref (Soldat_soldier.create ~primary:Spas (0., 0.) 190) in
          for i = 1 to 100 do
            falling := step ~map:Testutil_map.empty !falling (level i !falling) i
          done;
          let quiet = step ~map:Testutil_map.empty !falling (level 0 !falling) 101 in
          let fired = step ~map:Testutil_map.empty !falling { (level 0 !falling) with fire = true } 101 in
          Alcotest.(check int) "in the air: six pellets too" 6 (List.length fired.shots);
          Alcotest.(check (near 0.01)) "and the soldier kicked back by 0.577" (-0.577) (fired.vx -. quiet.vx));
      Testo.create "a clip, and its reload" (fun () ->
          (* the MP5: 30 rounds, one every 6 ticks; then 105 ticks *)
          let (s, shots) = run (armed Mp5) 175 (fun _ -> firing) in
          Alcotest.(check int) "30 shots in 175 ticks" 30 (count shots);
          Alcotest.(check int) "the last at 1 + 29 x 6" 175 (List.hd (List.rev (at shots)));
          Alcotest.(check int) "empty" 0 s.weapon.ammo;
          let (s, shots) = run s 50 (fun _ -> firing) in
          Alcotest.(check int) "nothing while it reloads" 0 (count shots);
          Alcotest.(check bool) "the clip comes out, then a new one goes in" true (s.body.id = Clip_in);
          let (s, _) = run s 60 (fun _ -> looking) in
          Alcotest.(check int) "full again" 30 s.weapon.ammo;
          Alcotest.(check bool) "the hands back" true (s.body.id = Stand);
          (* the key: a clip half used is let go *)
          let (s, _) = run (armed Mp5) 13 (fun _ -> firing) in
          Alcotest.(check int) "three shots: 27 left" 27 s.weapon.ammo;
          let (s, _) = run s 1 (fun _ -> { looking with reload = true }) in
          Alcotest.(check int) "the key: the clip is out" 0 s.weapon.ammo;
          let (s, _) = run s 105 (fun _ -> looking) in
          Alcotest.(check int) "105 ticks later: full" 30 s.weapon.ammo);
      Testo.create "the shotgun, shell by shell" (fun () ->
          let (s, _) = run (armed Spas) 70 (fun i -> if i mod 35 = 0 then looking else firing) in
          Alcotest.(check int) "two shots: 5 shells left" 5 s.weapon.ammo;
          let (s, _) = run s 1 (fun _ -> { looking with reload = true }) in
          Alcotest.(check bool) "the key: it loads" true (s.body.id = Reload);
          (* the animation's 14 frames, 2 ticks each: a shell every 28 ticks or so *)
          let (s, _) = run s 30 (fun _ -> looking) in
          Alcotest.(check int) "a shell in" 6 s.weapon.ammo;
          let (s, _) = run s 40 (fun _ -> looking) in
          Alcotest.(check int) "full" 7 s.weapon.ammo;
          let (s, _) = run s 40 (fun _ -> looking) in
          Alcotest.(check bool) "and it stops there" true (s.weapon.ammo = 7 && s.body.id = Stand));
      Testo.create "the other weapon" (fun () ->
          let s = armed Ak74 in
          Alcotest.(check bool) "the USSOCOM on the back" true (s.weapon.kind.id = Ak74 && s.secondary.kind.id = Socom);
          let (s, _) = run s 13 (fun _ -> firing) in
          let (s, _) = run s 1 (fun _ -> { looking with change = true }) in
          Alcotest.(check bool) "the key: the hands change" true (s.body.id = Change);
          let (s, _) = run s 20 (fun _ -> looking) in
          Alcotest.(check bool) "not yet at 20 ticks" true (s.weapon.kind.id = Ak74);
          let (s, shots) = run s 20 (fun _ -> firing) in
          Alcotest.(check bool) "swapped at the 25th frame" true (s.weapon.kind.id = Socom && s.secondary.kind.id = Ak74);
          Alcotest.(check int) "the rifle keeps what it had" 38 s.secondary.ammo;
          Alcotest.(check bool) "and the pistol fires, once the hands are free" true (count shots = 1));
      Testo.create "a grenade thrown" (fun () ->
          let s = armed Ak74 in
          Alcotest.(check int) "one grenade" 1 s.grenades;
          (* the key held 30 ticks, then let go: the Throw animation at
           * its 30th frame or so, 30 / 5 = 6 units a tick *)
          let (s, shots) = run s 32 (fun i -> if i <= 30 then { looking with grenade = true } else looking) in
          let thrown = List.concat shots in
          Alcotest.(check int) "one left the hand" 1 (List.length thrown);
          let g = List.hd thrown in
          Alcotest.(check bool) "a grenade" true (g.weapon = Grenade);
          let speed = Float.hypot (fst g.velocity) (snd g.velocity) in
          Alcotest.(check bool) (Printf.sprintf "at about 6 a tick (%.2f)" speed) true (speed > 5.6 && speed < 6.4);
          Alcotest.(check bool) "forwards, and up a little: the arc" true (fst g.velocity > 5. && snd g.velocity < -0.3);
          Alcotest.(check int) "none left" 0 s.grenades;
          (* let go too early, before the 15th frame: nothing *)
          let (s, shots) = run (armed Ak74) 20 (fun i -> if i <= 8 then { looking with grenade = true } else looking) in
          Alcotest.(check (pair int int)) "let go too early: kept" (0, 1) (count shots, s.grenades);
          (* held to the end: thrown at the 36th frame, 7.2 a tick *)
          let (_, shots) = run (armed Ak74) 60 (fun _ -> { looking with grenade = true }) in
          let g = List.hd (List.concat shots) in
          Alcotest.(check (near 0.05)) "held to the end: 36 / 5" 7.2 (Float.hypot (fst g.velocity) (snd g.velocity));
          Alcotest.(check int) "and only one" 1 (count shots));
      Testo.create "a hit, by where" (fun () ->
          let p = rooms () in
          let me = p.soldiers.(0) in
          let health (soldiers : Soldat_model.soldier array) = soldiers.(0).health in
          (* an Eagle's bullet, 19 a tick, ending in the right hip: the
           * chest's, 19 x 1.81 x 0.95 *)
          let (hx, hy) = Soldat_soldier.point me.body 5 in
          let (soldiers, _, _) = shoot p [ bullet Eagles (hx -. 25., hy) (19., 0.) ] in
          Alcotest.(check (near 0.01)) "the chest: 32.67" (150. -. (19. *. 1.81 *. 0.95)) (health soldiers);
          (* from above, into the head: 19 x 1.81 x 1.1 *)
          let (hx, hy) = Soldat_soldier.point me.body 12 in
          let (soldiers, _, _) = shoot p [ bullet Eagles (hx -. 2., hy -. 25.) (0., 19.) ] in
          Alcotest.(check (near 0.01)) "the head: 37.83" (150. -. (19. *. 1.81 *. 1.1)) (health soldiers);
          (* from below, into a knee: 19 x 1.81 x 0.85 *)
          let (kx, ky) = Soldat_soldier.point me.body 3 in
          let (soldiers, _, _) = shoot p [ bullet Eagles (kx -. 25., ky +. 3.) (19., 0.) ] in
          Alcotest.(check (near 0.01)) "a leg: 29.23" (150. -. (19. *. 1.81 *. 0.85)) (health soldiers);
          (* and pushed by 0.0176 of the bullet's speed *)
          Alcotest.(check (near 0.001)) "pushed 19 x 0.0176" (me.body.vx +. (19. *. 0.0176)) soldiers.(0).body.vx;
          (* a miss *)
          let (soldiers, left, _) = shoot p [ bullet Eagles (hx -. 25., hy -. 40.) (19., 0.) ] in
          Alcotest.(check (near 0.01)) "over the head: nothing" 150. (health soldiers);
          Alcotest.(check int) "and it flies on" 1 (List.length left);
          (* one's own bullet, in its first 20 ticks *)
          let (hx, hy) = Soldat_soldier.point me.body 5 in
          let (soldiers, _, _) = shoot p [ bullet ~owner:0 Eagles (hx -. 25., hy) (19., 0.) ] in
          Alcotest.(check (near 0.01)) "not by one's own, just fired" 150. (health soldiers));
      Testo.create "through a body, or not" (fun () ->
          let p = rooms () in
          let (hx, hy) = Soldat_soldier.point p.soldiers.(0).body 5 in
          let speed (bullets : Soldat_model.bullet list) = match bullets with [ b ] -> Float.hypot b.vx b.vy | _ -> 0. in
          (* an Ak-74's, 24 a tick: over 23, through at 0.75; then its
           * step: gravity, and a hundredth lost *)
          let (_, left, _) = shoot p [ bullet Ak74 (hx -. 30., hy) (24., 0.) ] in
          Alcotest.(check (near 0.05)) "an Ak-74's goes through at 18" (18. *. 0.99) (speed left);
          Alcotest.(check int) "and will not hit it again" 0 (List.hd left).through;
          (* a pistol's, 18 a tick: at its weapon's speed, through at 0.66 *)
          let (_, left, _) = shoot p [ bullet Socom (hx -. 25., hy) (18., 0.) ] in
          Alcotest.(check (near 0.05)) "a pistol's at 0.66" (18. *. 0.66 *. 0.99) (speed left);
          (* the same slowed to 12: under 0.9 of 18, it stops there *)
          let (soldiers, left, _) = shoot p [ bullet Socom (hx -. 20., hy) (12., 0.) ] in
          Alcotest.(check int) "slowed: it stops in the body" 0 (List.length left);
          Alcotest.(check (near 0.01)) "having taken 12 x 1.49 x 0.95" (150. -. (12. *. 1.49 *. 0.95)) soldiers.(0).health);
      Testo.create "weaker with the distance" (fun () ->
          (* in the air over nothing, 24 a tick: 500 units away after 21
           * ticks or so, looked at every 6 *)
          let fly n b = let b = ref [ b ] in for _ = 1 to n do let (_, left, _) = Soldat_bullets.tick Testutil_map.empty [||] !b in b := left done; List.hd !b in
          let b = bullet Ak74 (0., -1000.) (24., 0.) in
          Alcotest.(check (near 0.0001)) "its weapon's Damage at first" 1.11 (fly 12 b).damage;
          Alcotest.(check (near 0.0001)) "half beyond 500" 0.555 (fly 30 b).damage;
          Alcotest.(check (near 0.0001)) "a quarter beyond 900" 0.2775 (fly 60 b).damage;
          Alcotest.(check (near 0.0001)) "the Barrett's never" 4.45 (fly 30 (bullet Barrett (0., -1000.) (24., 0.))).damage;
          (* and it falls: 2.25 x 0.06 more a tick *)
          let one = fly 1 b in
          Alcotest.(check (near 0.0001)) "pulled down 0.135 a tick" (0.135 *. 0.99) one.vy;
          Alcotest.(check (pair (near 0.001) (near 0.001))) "moved by its speed" (24., -1000. +. 0.135) (one.x, one.y));
      Testo.create "a wall: the ricochet" (fun () ->
          let tick b = let (_, left, _) = Soldat_bullets.tick floor [||] [ b ] in left in
          (* far from the map's middle (where a bullet has "bounced" at
           * first), grazing the floor: 10 along for 1 down *)
          let grazing = bullet Socom (500., -1.) (17.9, 1.8) in
          (match tick grazing with
          | [ b ] ->
              Alcotest.(check bool) "it goes on" true (b.vx > 0.);
              (* 1.8 x 25/35 - 18 x 10/35 = 1.29 - 5.14, then gravity *)
              Alcotest.(check (near 0.05)) "turned out of the floor" ((1.8 *. 25. /. 35.) -. (Float.hypot 17.9 1.8 *. 10. /. 35.) +. 0.135) (b.vy /. 0.99);
              Alcotest.(check (near 0.05)) "keeping 25/35 of its way along it" (17.9 *. 25. /. 35.) (b.vx /. 0.99)
          | l -> Alcotest.failf "a grazing bullet: %d left" (List.length l));
          (* straight down into it: gone *)
          Alcotest.(check int) "straight in: it ends there" 0 (List.length (tick (bullet Socom (500., -5.) (0., 18.))));
          (* within 50 of where it last bounced: gone too *)
          Alcotest.(check int) "not twice within 50 units" 0 (List.length (tick { grazing with bounced_at = (490., -3.) }));
          (* a soldier behind the wall is not hit *)
          let p = rooms () in
          let (hx, hy) = Soldat_soldier.point p.soldiers.(0).body 5 in
          let (soldiers, _, _) = shoot p [ bullet Eagles (hx -. 25., hy +. 9.) (19., 2.) ] in
          ignore soldiers;
          (* out of the map: gone *)
          Alcotest.(check int) "out of the map: gone" 0 (List.length (tick (bullet Socom (2495., -500.) (18., 0.)))));
      Testo.create "a grenade bounces, and explodes" (fun () ->
          let tick b = Soldat_bullets.tick floor [||] [ b ] in
          (* a tick takes it into the floor, the next finds it there *)
          let (_, left, _) = tick (bullet Grenade (500., -1.) (3., 4.)) in
          let (_, left, blasts) = Soldat_bullets.tick floor [||] left in
          (match left with
          | [ b ] ->
              Alcotest.(check bool) "it bounces off the floor: upwards now" true (b.vy < 0.);
              Alcotest.(check bool) "still going its way along it" true (b.vx > 2.);
              Alcotest.(check bool) "slower" true (Float.hypot b.vx b.vy < 5.)
          | l -> Alcotest.failf "a bouncing grenade: %d left" (List.length l));
          Alcotest.(check int) "without exploding" 0 (List.length blasts);
          (* its time over *)
          let last = { (bullet Grenade (500., -100.) (0., 0.)) with ttl = 1 } in
          let (_, left, blasts) = tick last in
          Alcotest.(check (pair int int)) "after 3 seconds: an explosion" (0, 1) (List.length left, List.length blasts);
          Alcotest.(check (near 0.01)) "reaching 85" 85. (List.hd blasts).radius;
          (* another grenade 30 away goes off with it; one 60 away does not *)
          let (_, left, blasts) = Soldat_bullets.tick floor [||] [ last; bullet Grenade (530., -100.) (0., 0.); bullet Grenade (600., -100.) (0., 0.) ] in
          Alcotest.(check (pair int int)) "the one within 50 goes off too" (1, 2) (List.length left, List.length blasts);
          (* the M79's explodes on the wall, where it was before *)
          let (_, left, blasts) = tick (bullet M79 (500., -5.) (0., 10.7)) in
          Alcotest.(check (pair int int)) "the M79's explodes on the floor" (0, 1) (List.length left, List.length blasts);
          Alcotest.(check (near 0.01)) "reaching 64" 64. (List.hd blasts).radius);
      Testo.create "an explosion's reach" (fun () ->
          let p = rooms () in
          let me = p.soldiers.(0) in
          let hip = Soldat_soldier.point me.body 5 in
          (* a grenade whose time is over, at a distance to the right of
           * the right hip, at its height *)
          let blast d = shoot p [ { (bullet Grenade (fst hip +. d, snd hip) (0., 0.)) with ttl = 1 } ] in
          let nearest (soldiers : Soldat_model.soldier array) d =
            List.fold_left (fun m n -> Float.min m (let (x, y) = Soldat_soldier.point me.body n in Float.hypot (fst hip +. d -. x) (snd hip -. y))) infinity Soldat_bullets.hit_points
            |> fun dist -> ignore soldiers; dist
          in
          (* 1500 / (d + 1), d to its nearest point: all the grenade's
           * modifiers are 1 *)
          let (soldiers, _, _) = blast 40. in
          let d = nearest soldiers 40. in
          Alcotest.(check (near 0.5)) (Printf.sprintf "at %.1f: 1500 / (d + 1)" d) (150. -. (1500. /. (d +. 1.))) soldiers.(0).health;
          Alcotest.(check bool) "it lives" true (soldiers.(0).dead = None);
          (* pushed away: 3.75 d / (d + 1), to the left *)
          Alcotest.(check (near 0.05)) "pushed away" (me.body.vx -. (3.75 *. d /. (d +. 1.))) soldiers.(0).body.vx;
          let (soldiers, _, _) = blast 100. in
          Alcotest.(check (near 0.01)) "beyond 85: nothing" 150. soldiers.(0).health;
          (* 3 away: 1500 / 4 = 375 of its 150, dead and whole (an
           * explosion strikes no point in particular) *)
          let (soldiers, _, _) = blast 3. in
          (match soldiers.(0).dead with
          | Some (_, ragdoll) -> Alcotest.(check (list int)) "3 away: dead, whole" [] ragdoll.cut
          | None -> Alcotest.fail "a grenade 3 away: it lives");
          (* on its head (a grenade that strikes a soldier goes off
           * there, and is measured from the point it struck, the head
           * before any other): all of 1500, a kill for the thrower, all
           * five limbs off *)
          let (soldiers, _, _) = shoot p [ bullet Grenade (Soldat_soldier.point me.body 12) (0., 0.) ] in
          (match soldiers.(0).dead with
          | Some (_, ragdoll) ->
              Alcotest.(check (list int)) "on its head: thighs, head and arms off" [ 2; 4; 20; 21; 23 ] ragdoll.cut;
              Alcotest.(check int) "23 sticks still hold, of 28" 23 (List.length (Soldat_ragdoll.holding ragdoll))
          | None -> Alcotest.fail "a grenade at its feet: it lives");
          Alcotest.(check int) "a kill for who threw it" 1 soldiers.(1).kills;
          Alcotest.(check (near 0.01)) "no health under -400" (-400.) soldiers.(0).health;
          (* one's own grenade: a kill less *)
          let (soldiers, _, _) = shoot p [ { (bullet ~owner:0 Grenade (fst hip +. 3., snd hip) (0., 0.)) with ttl = 1 } ] in
          Alcotest.(check bool) "by one's own: dead, and no kill for it" true (soldiers.(0).dead <> None && soldiers.(0).kills = 0));
      Testo.create "a head off" (fun () ->
          let p = rooms () in
          let (hx, hy) = Soldat_soldier.point p.soldiers.(0).body 12 in
          (* the Barrett's, 55 a tick, from above into the head: 55 x
           * 4.45 (the same anywhere) = 244.75 of 150: -94.75, under -90 *)
          let (soldiers, left, _) = shoot p [ bullet Barrett (hx -. 2., hy -. 60.) (0., 55.) ] in
          Alcotest.(check (near 0.01)) "244.75 of its 150" (150. -. (55. *. 4.45)) soldiers.(0).health;
          (match soldiers.(0).dead with
          | Some (_, ragdoll) -> Alcotest.(check (list int)) "the head's stick cut" [ 20 ] ragdoll.cut
          | None -> Alcotest.fail "the Barrett in the head: it lives");
          Alcotest.(check int) "and the bullet goes on" 1 (List.length left);
          (* the same in a hip: as dead, and whole *)
          let (kx, ky) = Soldat_soldier.point p.soldiers.(0).body 5 in
          let (soldiers, _, _) = shoot p [ bullet Barrett (kx -. 60., ky) (55., 0.) ] in
          (match soldiers.(0).dead with
          | Some (_, ragdoll) -> Alcotest.(check (list int)) "in the hip: dead, whole" [] ragdoll.cut
          | None -> Alcotest.fail "the Barrett in the hip: it lives");
          (* a pistol's bullet in the head six times: dead, whole *)
          let p = ref p in
          for _ = 1 to 6 do
            let (hx, hy) = Soldat_bullets.point !p.soldiers.(0) 12 in
            let (soldiers, _, _) = shoot !p [ bullet Socom (hx -. 2., hy -. 20.) (0., 18.) ] in
            p := { !p with soldiers }
          done;
          (match !p.soldiers.(0).dead with
          | Some (_, ragdoll) -> Alcotest.(check (list int)) "a pistol's: dead, whole" [] ragdoll.cut
          | None -> Alcotest.fail "six in the head: it lives");
          (* the dead are still hit: more in the head, and it comes off *)
          for _ = 1 to 4 do
            let (hx, hy) = Soldat_bullets.point !p.soldiers.(0) 12 in
            let (soldiers, _, _) = shoot !p [ bullet Socom (hx -. 2., hy -. 20.) (0., 18.) ] in
            p := { !p with soldiers }
          done;
          match !p.soldiers.(0).dead with
          | Some (_, ragdoll) -> Alcotest.(check (list int)) "shot again, dead: the head off" [ 20 ] ragdoll.cut
          | None -> Alcotest.fail "it came back");
    ]
