(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_bots.mli *)

let near = Alcotest.float
let named (name : string) : Soldat_model.character = List.find (fun (c : Soldat_model.character) -> c.bot = name) (Lazy.force Soldat_bots.characters)

(* an open floor; the player (soldier 0) and one bot (soldier 1), each
 * put where the test says *)
let floor = Testutil_map.floor ()

let facing ?(map = floor) ?(bot = "Kruger") ~(player : float * float) ~(at : float * float) () : Soldat_model.play =
  let p = Soldat_update.start ~bots:[ named bot ] map in
  let put i (s : Soldat_model.soldier) = { s with body = Soldat_soldier.create ~primary:s.body.weapon.kind.id ~human:s.human (if i = 0 then player else at) 190 } in
  { p with soldiers = Array.mapi put p.soldiers }

(* the bot's keys this tick, the game's chance always [chance] *)
let keys ?(chance = 0.5) (p : Soldat_model.play) : Soldat_soldier.control * Soldat_model.brain * int list =
  Soldat_bots.control p 1 (Option.get p.brains.(1)) ~random:(fun () -> chance)

let tests =
  Testo.categorize "Bots"
    [
      Testo.create "the characters" (fun () ->
          let all = Lazy.force Soldat_bots.characters in
          Alcotest.(check int) "15 of the 16 play" 15 (List.length all);
          Alcotest.(check bool) "not Boogie Man, who likes the chainsaw" false (List.exists (fun (c : Soldat_model.character) -> c.bot = "Boogie Man") all);
          let kruger = named "Kruger" in
          Alcotest.(check bool) "Kruger likes the Ruger" true (kruger.favourite = Ruger);
          Alcotest.(check (list int)) "his accuracy, grenades, camping" [ 8; 500; 255 ] [ kruger.accuracy; kruger.grenade_freq; kruger.camper ];
          Alcotest.(check bool) "he leaves the dead alone" false kruger.shoot_dead;
          Alcotest.(check bool) "Danko does not" true (named "Danko").shoot_dead;
          (* Color1=$00E253EE: blue first; Skin_Color=$006D4A1A: red first *)
          let admiral = named "Admiral" in
          Alcotest.(check (list int)) "the Admiral's shirt" [ 0xEE; 0x53; 0xE2 ] (let (r, g, b) = admiral.bot_shirt in [ r; g; b ]);
          Alcotest.(check (list int)) "and his skin" [ 0x6D; 0x4A; 0x1A ] (let (r, g, b) = admiral.bot_skin in [ r; g; b ]);
          Alcotest.(check bool) "the Barrett's name is spelt as shown" true ((named "Sniper").favourite = Barrett);
          (* a round's cast *)
          Alcotest.(check (list string)) "the first round's three" [ "Admiral"; "Billy"; "Blain" ] (List.map (fun (c : Soldat_model.character) -> c.bot) (Soldat_bots.cast 3 0));
          Alcotest.(check string) "the next round starts one further" "Billy" (List.hd (Soldat_bots.cast 3 1)).bot;
          Alcotest.(check string) "and round the list" "Admiral" (List.hd (Soldat_bots.cast 3 15)).bot;
          (* its weapon: its favourite one time in two *)
          Alcotest.(check bool) "its favourite" true (Soldat_bots.weapon kruger ~random:(fun () -> 0.1) = Ruger);
          Alcotest.(check bool) "or one of the first nine" true (Soldat_bots.weapon kruger ~random:(fun () -> 0.95) = Minimi);
          Alcotest.(check bool) "a file that is no bot's" true (Soldat_bots.character "Name=Nobody\n" = None));
      Testo.create "the distances" (fun () ->
          Alcotest.(check (list int)) "35, 55, 95, 180, 350, 500, 730, and beyond"
            [ 35; 35; 55; 95; 180; 350; 500; 730; 731 ]
            (List.map (fun d -> Soldat_bots.bucket 0. d) [ 0.; 35.; 36.; 90.; -180.; 200.; 500.; 600.; 900. ]));
      Testo.create "nobody in sight: the waypoints" (fun () ->
          (* three waypoints along the floor, each saying to run right
           * on the way to it; the player 1500 away, out of sight *)
          let w = Testutil_map.waypoint in
          let map =
            Testutil_map.map ~spawns:[ (-1500., -20.); (0., -20.) ]
              ~waypoints:[ w 1 (0, -10) [ 2 ]; w ~right:true 2 (300, -10) [ 3 ]; w ~right:true ~up:true 3 (600, -10) [ 3 ] ]
              (Testutil_map.slab (-2000.) 0. 2000. 200.)
          in
          let p = ref (Soldat_update.start ~bots:[ named "Kruger" ] map) in
          Alcotest.(check (near 1.)) "the bot at the far place" 0. !p.soldiers.(1).body.x;
          let (c, brain, _) = keys !p in
          Alcotest.(check (pair int int)) "at the first waypoint, going to the second" (1, 2) (brain.current, brain.next);
          Alcotest.(check bool) "holding its key: right" true (c.right && not c.left);
          Alcotest.(check (pair (near 0.1) (near 0.1))) "looking that way" (300., -10.) c.aim;
          for _ = 1 to 200 do
            p := Soldat_update.tick !p Soldat_model.still ~look:(0., 0.)
          done;
          Alcotest.(check bool) "200 ticks later: well on its way" true (!p.soldiers.(1).body.x > 300.);
          let brain = Option.get !p.brains.(1) in
          Alcotest.(check (pair int int)) "past the second, going to the third" (2, 3) (brain.current, brain.next);
          (* a map without waypoints: it stays *)
          let p = ref (Soldat_update.start ~bots:[ named "Kruger" ] (Testutil_map.map ~spawns:[ (-1500., -20.); (0., -20.) ] (Testutil_map.slab (-2000.) 0. 2000. 200.))) in
          for _ = 1 to 200 do
            p := Soldat_update.tick !p Soldat_model.still ~look:(0., 0.)
          done;
          Alcotest.(check (near 1.)) "no waypoints: it stays" 0. !p.soldiers.(1).body.x);
      Testo.create "somebody in sight: the ladder" (fun () ->
          let at d = keys (facing ~player:(d, -20.) ~at:(0., -20.) ()) in
          let (c, brain, _) = at 30. in
          Alcotest.(check int) "its target" 0 brain.target;
          Alcotest.(check bool) "30 away: backs off, firing" true (c.left && (not c.right) && c.fire);
          let (c, _, _) = at 50. in
          Alcotest.(check bool) "50: stands and fires" true ((not c.left) && (not c.right) && c.fire && not c.down);
          let (c, _, _) = at 90. in
          Alcotest.(check bool) "90: crouches and fires" true ((not c.left) && (not c.right) && c.fire && c.down);
          let (c, _, _) = at 150. in
          Alcotest.(check bool) "150: the same, walking on" true (c.right && c.fire && c.down);
          let (c, _, _) = at 300. in
          (* Kruger camps (255): crouched at mid range *)
          Alcotest.(check bool) "300: fires; a camper crouches" true (c.fire && c.down);
          let (c, _, _) = keys (facing ~bot:"Billy" ~player:(300., -20.) ~at:(0., -20.) ()) in
          Alcotest.(check bool) "who does not camp walks on" true (c.fire && c.right && not c.down);
          (* farther: by chance *)
          let far chance = let (c, _, _) = keys ~chance (facing ~bot:"Billy" ~player:(600., -20.) ~at:(0., -20.) ()) in c.fire in
          Alcotest.(check (pair bool bool)) "600: one tick in four" (true, false) (far 0.1, far 0.5);
          let (c, brain, _) = at 800. in
          Alcotest.(check bool) "800: out of sight" true ((not c.fire) && brain.target = -1);
          (* the other side *)
          let (c, _, _) = keys (facing ~player:(-150., -20.) ~at:(0., -20.) ()) in
          Alcotest.(check bool) "on its left: walks left" true (c.left && not c.right);
          (* above *)
          let (c, _, _) = keys (facing ~player:(100., -300.) ~at:(0., -20.) ()) in
          Alcotest.(check bool) "200 above: the jets" true c.jetpack;
          (* behind a wall: not seen *)
          let (c, _, _) = keys (facing ~map:Testutil_map.rooms ~player:(-600., -20.) ~at:(-400., -20.) ()) in
          Alcotest.(check bool) "in the same room: seen" true c.fire;
          let (c, _, _) = keys (facing ~map:Testutil_map.rooms ~player:(-600., -20.) ~at:(0., -20.) ()) in
          Alcotest.(check bool) "behind a wall: not" false c.fire);
      Testo.create "its aim" (fun () ->
          (* Kruger, a Ruger (33 a tick) or what chance gave him; the
           * target 150 away, still: the bucket is 180, the rise 0.5 x
           * 180 / speed; off by 8 less a number from 0 to 7 *)
          let p = facing ~player:(150., -20.) ~at:(0., -20.) () in
          let speed = p.soldiers.(1).body.weapon.kind.speed in
          let (c, _, _) = keys ~chance:0. p in
          Alcotest.(check (near 0.6)) "at its target" 150. (fst c.aim);
          Alcotest.(check (near 0.6)) "raised, and off by all its accuracy" (-20. -. (0.5 *. 180. /. speed) -. 8.) (snd c.aim);
          let (c, _, _) = keys ~chance:0.99 p in
          Alcotest.(check (near 0.6)) "or by 1 only" (-20. -. (0.5 *. 180. /. speed) -. 1.) (snd c.aim);
          (* the Terminator never misses *)
          let p = facing ~bot:"Terminator" ~player:(150., -20.) ~at:(0., -20.) () in
          let speed = p.soldiers.(1).body.weapon.kind.speed in
          let (c, _, _) = keys ~chance:0.7 p in
          Alcotest.(check (near 0.6)) "accuracy 0: only the rise" (-20. -. (0.5 *. 180. /. speed)) (snd c.aim);
          (* a target moving: where it will be in 10 ticks *)
          let p = { p with soldiers = Array.mapi (fun i (s : Soldat_model.soldier) -> if i = 0 then { s with body = { s.body with vx = 2. } } else s) p.soldiers } in
          let (c, _, _) = keys p in
          Alcotest.(check (near 0.6)) "led by 10 ticks of its speed" 170. (fst c.aim));
      Testo.create "grenades, and kits" (fun () ->
          (* a grenade 50 to its right: it runs left *)
          let p = facing ~player:(1500., -20.) ~at:(0., -20.) () in
          let (c, _, _) = keys p in
          Alcotest.(check bool) "nothing to do" false (c.left || c.right);
          let grenade = Soldat_bullets.of_shot ~owner:0 { from = (50., -20.); velocity = (0., 0.); weapon = Grenade } in
          let (c, _, _) = keys { p with bullets = [ grenade ] } in
          Alcotest.(check bool) "a grenade on its right: left" true (c.left && not c.right);
          (* one tick in its Grenade_Frequency, an enemy near and not
           * above it, it throws *)
          let near_enemy = facing ~bot:"Billy" ~player:(150., -10.) ~at:(0., -20.) () in
          let (c, _, _) = keys ~chance:0. near_enemy in
          Alcotest.(check bool) "by chance: its grenade" true c.grenade;
          let (c, _, _) = keys ~chance:0.5 near_enemy in
          Alcotest.(check bool) "else not" false c.grenade;
          let (c, _, _) = keys ~chance:0. (facing ~bot:"Billy" ~player:(150., -120.) ~at:(0., -20.) ()) in
          Alcotest.(check bool) "nor at one well above" false c.grenade;
          (* hurt, a medikit 100 to its left: it goes, and its look wears the kit's interest *)
          let kit : Soldat_things.t =
            { kind = Medikit; points = Array.map Particles.particle [| (-100., -1.); (-109., -1.); (-109., -9.6); (-100., -9.6) |]; ttl = 100; interest = 350; still = true; facing = 1; place = 0; hits = 1 }
          in
          let (c, _, looked) = keys { p with things = [ kit ] } in
          Alcotest.(check bool) "well: the kit is left" true ((not c.left) && looked = []);
          let hurt = { p with things = [ kit ]; soldiers = Array.mapi (fun i (s : Soldat_model.soldier) -> if i = 1 then { s with health = 60. } else s) p.soldiers } in
          let (c, brain, looked) = keys hurt in
          Alcotest.(check bool) "hurt: it goes" true (c.left && brain.go_thing);
          Alcotest.(check (list int)) "and has looked at it" [ 0 ] looked;
          let (c, brain, _) = keys { hurt with things = [ { kit with interest = 1 } ] } in
          Alcotest.(check bool) "a kit it cannot get: it gives up" true ((not c.left) && not brain.go_thing);
          (* falling fast: the jets *)
          let falling = { p with soldiers = Array.mapi (fun i (s : Soldat_model.soldier) -> if i = 1 then { s with body = { s.body with vy = 4. } } else s) p.soldiers } in
          let (c, brain, _) = keys falling in
          Alcotest.(check bool) "falling fast: the jets" true (c.jetpack && brain.fall_save));
    ]
