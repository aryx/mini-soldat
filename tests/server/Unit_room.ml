(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_room.mli *)

(* a wide floor, where the soldiers of a deathmatch appear together *)
let floor = Testutil_map.floor ()
let rec ticks n room = if n = 0 then room else ticks (n - 1) (Soldat_room.tick room)
let soldier (room : Soldat_room.t) (i : int) : Soldat_model.soldier = (Soldat_room.play room).soldiers.(i)
let right : Soldat_soldier.control = { Soldat_soldier.no_control with right = true; aim = (10000., 0.) }

let tests =
  Testo.categorize "Room"
    [
      Testo.create "its seats" (fun () ->
          let room = Soldat_room.create ~seats:3 ~name:"test" Testutil_map.rooms in
          let p = Soldat_room.play room in
          Alcotest.(check int) "three soldiers" 3 (Array.length p.soldiers);
          Alcotest.(check bool) "all bots'" true (Array.for_all (fun (s : Soldat_model.soldier) -> not s.human) p.soldiers && Array.for_all (fun m -> Soldat_bots.brain_of m <> None) p.minds);
          Alcotest.(check int) "no player" 0 (Soldat_room.players room);
          let bot = (soldier room 0).name in
          (* a player takes the first *)
          let (room, seat) = Option.get (Soldat_room.join "pad" room) in
          Alcotest.(check int) "the first seat" 0 seat;
          Alcotest.(check bool) "the soldier is pad's" true ((soldier room 0).name = "pad" && (soldier room 0).human && (soldier room 0).body.human);
          Alcotest.(check bool) "and no bot's" true ((Soldat_bots.brain_of (Soldat_room.play room).minds.(0)) = None);
          Alcotest.(check (pair (Alcotest.float 0.01) (Alcotest.float 0.01))) "where it was" (p.soldiers.(0).body.x, p.soldiers.(0).body.y) ((soldier room 0).body.x, (soldier room 0).body.y);
          let (room, seat) = Option.get (Soldat_room.join "mm" room) in
          Alcotest.(check (pair int int)) "the next player the next seat" (1, 2) (seat, Soldat_room.players room);
          let (room, _) = Option.get (Soldat_room.join "third" room) in
          Alcotest.(check bool) "all taken: no seat for a fourth" true (Soldat_room.join "fourth" room = None);
          (* pad leaves: its bot has it back, the others keep their numbers *)
          let room = Soldat_room.leave 0 room in
          Alcotest.(check bool) "left: its bot has it back" true ((soldier room 0).name = bot && not (soldier room 0).human && (Soldat_bots.brain_of (Soldat_room.play room).minds.(0)) <> None);
          Alcotest.(check string) "the others keep their seats" "mm" (soldier room 1).name;
          let (room, seat) = Option.get (Soldat_room.join "fourth" room) in
          Alcotest.(check (pair int string)) "and the seat is to take again" (0, "fourth") (seat, (soldier room 0).name);
          ignore room);
      Testo.create "a player's keys" (fun () ->
          let room = ticks 100 (Soldat_room.create ~seats:3 ~name:"test" Testutil_map.rooms) in
          let (room, seat) = Option.get (Soldat_room.join "pad" room) in
          Alcotest.(check int) "none played yet" (-1) (Soldat_room.acked room seat);
          let x0 = (soldier room seat).body.x in
          (* nothing sent: it stands *)
          let still = ticks 30 room in
          Alcotest.(check (Alcotest.float 0.5)) "no keys: it stands" x0 (soldier still seat).body.x;
          (* three at once: one a tick, in their order *)
          let room = room |> Soldat_room.input seat ~seq:0 right |> Soldat_room.input seat ~seq:1 right |> Soldat_room.input seat ~seq:2 right in
          let room = Soldat_room.tick room in
          Alcotest.(check int) "a tick: the first is played" 0 (Soldat_room.acked room seat);
          let room = Soldat_room.tick room in
          Alcotest.(check int) "another: the second" 1 (Soldat_room.acked room seat);
          let room = ticks 2 room in
          Alcotest.(check int) "none left: the last again, its number kept" 2 (Soldat_room.acked room seat);
          let room = ticks 60 room in
          Alcotest.(check bool) "held: it has run to the right" true ((soldier room seat).body.x > x0 +. 50.);
          (* then let go *)
          let room = ticks 60 (Soldat_room.input seat ~seq:3 Soldat_soldier.no_control room) in
          let x1 = (soldier room seat).body.x in
          Alcotest.(check (Alcotest.float 0.5)) "let go: it stops" x1 (soldier (ticks 30 room) seat).body.x;
          (* keys for a seat nobody has: dropped *)
          let other = Soldat_room.input 2 ~seq:0 right room in
          Alcotest.(check int) "a bot's seat takes no keys" (-1) (Soldat_room.acked (ticks 5 other) 2);
          (* a program faster than the server: its last two only *)
          let flood = List.fold_left (fun room seq -> Soldat_room.input seat ~seq right room) room (List.init 20 (fun i -> 10 + i)) in
          Alcotest.(check bool) "twenty at once: the oldest are dropped" true (Soldat_room.acked (Soldat_room.tick flood) seat >= 24));
      Testo.create "a weapon chosen" (fun () ->
          let room = Soldat_room.create ~seats:2 ~name:"test" Testutil_map.rooms in
          let (room, seat) = Option.get (Soldat_room.join "pad" room) in
          let held = (soldier room seat).body.weapon.kind.id in
          let room = Soldat_room.weapon ~secondary:Law seat (Some Barrett) room in
          Alcotest.(check bool) "the ones to come back with" true ((soldier room seat).primary = Barrett && (soldier room seat).secondary = Law);
          Alcotest.(check bool) "the second alone" true ((soldier (Soldat_room.weapon ~secondary:Knife seat None room) seat).primary = Barrett);
          (* a room's mode, kept from a round to the next *)
          let rm = Soldat_room.create ~seats:2 ~mode:Rambomatch ~bonuses:3 ~name:"test.rm" Testutil_map.rooms in
          Alcotest.(check bool) "a room asked as a Rambomatch, with bonus kits" true ((Soldat_room.play rm).mode = Rambomatch && (Soldat_room.play rm).bonuses = 3);
          Alcotest.(check bool) "a room's name: its map, its mode" true
            (Soldat_protocol.room_map "Arena2.rm" = "Arena2" && Soldat_protocol.room_mode "Arena2.rm" = Some Rambomatch
           && Soldat_protocol.room_map "ctf_Ash" = "ctf_Ash" && Soldat_protocol.room_mode "ctf_Ash" = None && Soldat_protocol.room_mode "Arena2.zz" = None);
          Alcotest.(check bool) "not the one in its hands" true ((soldier (ticks 10 room) seat).body.weapon.kind.id = held);
          let theirs = (soldier room 1).primary in
          Alcotest.(check bool) "a bot's seat keeps its bot's" true ((soldier (Soldat_room.weapon 1 (Some Minigun) room) 1).primary = theirs));
      Testo.create "what is sent" (fun () ->
          let room = Soldat_room.create ~seats:4 ~name:"test" floor in
          let (room, _) = Option.get (Soldat_room.join "pad" room) in
          let room = ticks 300 room in
          let (room, bytes) = Soldat_room.snapshot room in
          (match Soldat_wire.decode_world floor bytes with
          | Error why -> Alcotest.fail why
          | Ok round ->
              Alcotest.(check string) "the round, with its player" "pad" round.soldiers.(0).name;
              Alcotest.(check int) "at its tick" 300 round.frame;
              (* four bots on an open floor fire at each other *)
              Alcotest.(check bool) "and what happened in those 300 ticks" true (round.events <> []));
          let (_, again) = Soldat_room.snapshot room in
          Alcotest.(check bool) "asked again at once: nothing new happened" true
            (match Soldat_wire.decode_world floor again with Ok round -> round.events = [] | Error _ -> false));
    ]
