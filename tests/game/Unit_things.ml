(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_things.mli *)

let near = Alcotest.float
let floor = Testutil_map.floor ()

(* the player alone in its room, two bots in theirs *)
let rooms () : Soldat_model.play = Soldat_update.start ~bots:(Soldat_bots.cast 2 0) Testutil_map.rooms

(* [n] ticks of the player's keys, aiming far to the right *)
let play (p : Soldat_model.play) (n : int) (keys : Soldat_soldier.control -> Soldat_soldier.control) : Soldat_model.play =
  let p = ref p in
  for _ = 1 to n do
    let me = !p.soldiers.(0).body in
    p := Soldat_update.tick !p (keys { Soldat_soldier.no_control with aim = (me.x +. 1000., me.y -. 12.) }) ~look:(0., 0.)
  done;
  !p

let weapons (p : Soldat_model.play) : Soldat_things.t list = List.filter (fun (t : Soldat_things.t) -> match t.kind with Weapon _ -> true | _ -> false) p.things

(* a thing's ticks on a map, until it is gone *)
let rec fall (map : Soldat_map.t) (n : int) (thing : Soldat_things.t) : Soldat_things.t option =
  if n = 0 then Some thing else match Soldat_things.tick map thing with Some thing -> fall map (n - 1) thing | None -> None

let length (thing : Soldat_things.t) : float =
  let (ax, ay) = thing.points.(0).pos and (bx, by) = thing.points.(1).pos in
  Float.hypot (bx -. ax) (by -. ay)

let tests =
  Testo.categorize "Things"
    [
      Testo.create "a weapon thrown away" (fun () ->
          let p = play (rooms ()) 100 Fun.id in
          Alcotest.(check bool) "an Ak-74 in the hands" true (p.soldiers.(0).body.weapon.kind.id = Ak74);
          (* the key: the animation, at whose 19th frame it leaves *)
          let p = play p 10 (fun c -> { c with drop = true }) in
          Alcotest.(check bool) "10 ticks of the key: still held" true (p.soldiers.(0).body.weapon.kind.id = Ak74 && weapons p = []);
          let p = play p 12 (fun c -> { c with drop = true }) in
          Alcotest.(check bool) "22: empty hands" true (p.soldiers.(0).body.weapon.kind.id = Hands);
          (match weapons p with
          | [ thing ] ->
              (match thing.kind with
              | Weapon g -> Alcotest.(check (pair bool int)) "the Ak-74, with its 40 rounds" (true, 40) (g.kind.id = Ak74, g.ammo)
              | _ -> ());
              (* karabin.po at 3.7: 4 x 3.7 *)
              Alcotest.(check (near 0.5)) "a stick of 14.8" 14.8 (length thing);
              Alcotest.(check bool) "going where one aimed: to the right" true (fst thing.points.(1).pos > fst thing.points.(1).old)
          | l -> Alcotest.failf "%d weapons on the ground" (List.length l));
          Alcotest.(check bool) "the USSOCOM still on the back" true (p.soldiers.(0).body.secondary.kind.id = Socom);
          (* empty hands fire nothing *)
          let q = play p 30 (fun c -> { c with fire = true }) in
          Alcotest.(check int) "empty hands fire nothing" 0 (List.length q.bullets));
      Testo.create "it falls, and lies still" (fun () ->
          let s = Soldat_soldier.create ~primary:Minigun (0., -60.) 190 in
          let thing = Soldat_things.weapon s ~alive:true s.weapon in
          (* its second point is thrown 3 further than its first: the
           * stick pulls it back to its length as it flies *)
          Alcotest.(check bool) "falling" false thing.still;
          Alcotest.(check (near 0.5)) "the minigun: 22 long, once its stick has pulled" 22. (length (Option.get (fall floor 20 thing)));
          (match fall floor 300 thing with
          | Some lying ->
              Alcotest.(check bool) "at rest within 5 seconds" true lying.still;
              Alcotest.(check bool) "on the floor" true (Array.for_all (fun (p : Particles.particle) -> Float.abs (snd p.pos) < 3.) lying.points);
              Alcotest.(check (near 0.5)) "as long as it was" 22. (length lying);
              let later = Option.get (fall floor 100 lying) in
              Alcotest.(check bool) "and not moving any more" true (later.points.(0).pos = lying.points.(0).pos)
          | None -> Alcotest.fail "gone");
          (* 20 seconds, and it is gone *)
          Alcotest.(check bool) "there after 1199 ticks" true (fall floor 1199 thing <> None);
          Alcotest.(check bool) "gone at 1200" true (fall floor 1200 thing = None);
          (* over nothing: it falls out of the map, and is gone *)
          Alcotest.(check bool) "out of the map: gone" true (fall Testutil_map.empty 1000 thing = None));
      Testo.create "picked up by empty hands" (fun () ->
          let p = play (rooms ()) 100 Fun.id in
          let p = play p 22 (fun c -> { c with drop = true }) in
          let thing = List.hd (weapons p) in
          (* within reach of where it was thrown from, at first: not at once *)
          let p = play p 5 Fun.id in
          Alcotest.(check bool) "not in its first 30 ticks" true (p.soldiers.(0).body.weapon.kind.id = Hands);
          ignore thing;
          (* walking over it *)
          let p = play p 200 (fun c -> { c with right = (match weapons p with [] -> false | _ -> true) }) in
          let rec walk p n =
            if n = 0 then p
            else match weapons p with
              | [] -> p
              | t :: _ -> walk (play p 1 (fun c -> if fst (Soldat_things.middle t) > p.soldiers.(0).body.x then { c with right = true } else { c with left = true })) (n - 1)
          in
          let p = walk p 400 in
          Alcotest.(check bool) "walked over: in the hands again" true (p.soldiers.(0).body.weapon.kind.id = Ak74);
          Alcotest.(check int) "with what it had" 40 p.soldiers.(0).body.weapon.ammo;
          Alcotest.(check int) "and no longer on the ground" 0 (List.length (weapons p));
          (* a weapon in the hands: another on the ground is left there *)
          let other = Soldat_things.weapon p.soldiers.(0).body ~alive:true (Soldat_soldier.gun Barrett) in
          let q = play { p with things = [ { other with ttl = 1000 } ] } 60 Fun.id in
          Alcotest.(check bool) "a hand that holds one takes no other" true (q.soldiers.(0).body.weapon.kind.id = Ak74 && List.length (weapons q) = 1));
      Testo.create "the dead drop theirs" (fun () ->
          let p = play (rooms ()) 100 Fun.id in
          let (hx, hy) = Soldat_soldier.point p.soldiers.(0).body 12 in
          let shot = Soldat_bullets.of_shot ~owner:1 { from = (hx -. 2., hy -. 60.); velocity = (0., 55.); weapon = Barrett } in
          let p = play { p with bullets = [ shot ] } 1 Fun.id in
          Alcotest.(check bool) "dead" true (p.soldiers.(0).dead <> None);
          Alcotest.(check int) "its Ak-74 on the ground" 1 (List.length (weapons p));
          let p = play p 200 Fun.id in
          Alcotest.(check bool) "back, with one in its hands" true (p.soldiers.(0).dead = None && p.soldiers.(0).body.weapon.kind.id = Ak74);
          Alcotest.(check int) "the old one still lying there" 1 (List.length (weapons p)));
      Testo.create "the kits" (fun () ->
          let places = [ (-600., -30.); (-500., -30.); (-400., -30.) ] in
          let map = Testutil_map.map ~spawns:[ (-600., -20.); (0., -20.); (600., -20.) ] ~medikit_spawns:places ~grenade_spawns:[ (-550., -30.) ] (Testutil_map.slab (-2000.) 0. 2000. 200.) in
          let p = Soldat_update.start map in
          let count kind = List.length (List.filter (fun (t : Soldat_things.t) -> t.kind = kind) p.things) in
          Alcotest.(check (pair int int)) "as many as the map says: 3 medikits, 1 of grenades" (3, 1) (count Medikit, count Grenade_kit);
          List.iter
            (fun (t : Soldat_things.t) ->
              let (x, y) = t.points.(0).pos in
              (* a place's point within 4, moved by up to 25 *)
              Alcotest.(check bool) "near one of its places" true (List.exists (fun (px, py) -> Float.abs (x -. px) < 30. && Float.abs (y -. py) < 30.) (places @ [ (-550., -30.) ])))
            p.things;
          (* at rest on the floor after a while; the player, unhurt, takes none *)
          let p = play p 300 Fun.id in
          Alcotest.(check bool) "all at rest" true (List.for_all (fun (t : Soldat_things.t) -> t.still) p.things);
          Alcotest.(check int) "none taken by who is well" 3 (List.length (List.filter (fun (t : Soldat_things.t) -> t.kind = Medikit) p.things));
          (* hurt, with a medikit on it *)
          let me = p.soldiers.(0) in
          let on_me kind place : Soldat_things.t =
            { kind; points = Array.map (fun (dx, dy) -> Particles.particle (me.body.x +. dx, me.body.y +. dy)) [| (0., 0.); (-9., 0.); (-9., -8.6); (0., -8.6) |];
              ttl = 100; interest = 350; still = true; facing = 1; place }
          in
          let hurt = { p with soldiers = Array.mapi (fun i (s : Soldat_model.soldier) -> if i = 0 then { s with health = 40. } else s) p.soldiers; things = [ on_me Medikit 0 ] } in
          let q = play hurt 1 Fun.id in
          Alcotest.(check (near 0.01)) "hurt: all its health back" 150. q.soldiers.(0).health;
          (match q.things with
          | [ kit ] ->
              Alcotest.(check bool) "the kit is elsewhere" true (kit.place <> 0 && Soldat_things.reach kit (me.body.x, me.body.y) = None);
              Alcotest.(check bool) "at another of the map's places for it" true (List.exists (fun (px, _) -> Float.abs (fst kit.points.(0).pos -. px) < 5.) (List.tl places))
          | l -> Alcotest.failf "%d things" (List.length l));
          (* grenades: one at first, a kit makes them two *)
          Alcotest.(check int) "one grenade at first" 1 me.body.grenades;
          let q = play { p with things = [ on_me Grenade_kit 0 ] } 1 Fun.id in
          Alcotest.(check int) "a grenade kit: two" 2 q.soldiers.(0).body.grenades;
          (* the only place for it: it appears there again *)
          Alcotest.(check int) "the kit again, at its only place" 1 (List.length q.things);
          let q = play { q with things = [ on_me Grenade_kit 0 ] } 1 Fun.id in
          Alcotest.(check bool) "with two already: left there" true (q.soldiers.(0).body.grenades = 2 && Soldat_things.reach (List.hd q.things) (me.body.x, me.body.y) <> None);
          (* a map without places for kits has none *)
          Alcotest.(check int) "no place for kits: none" 0 (List.length (Soldat_update.start Testutil_map.rooms).things));
    ]
