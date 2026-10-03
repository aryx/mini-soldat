(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_online.mli *)

let floor = Testutil_map.floor ()

(* a connection whose messages take [frames] frames each way: what is
 * sent leaves that much later, what arrives is given that much later.
 * The second value is its clock: a frame has gone by *)
let lagged (frames : int) (inner : Transport.t) : Transport.t * (unit -> unit) =
  let now = ref 0 in
  let up = Queue.create () and down = Queue.create () in
  let due q = Queue.peek_opt q |> Option.fold ~none:false ~some:(fun (at, _) -> at <= !now) in
  let clock () =
    incr now;
    while due up do
      inner.send (snd (Queue.pop up))
    done;
    List.iter (fun bytes -> Queue.push (!now + frames, bytes) down) (inner.receive ())
  in
  let receive () =
    let rec go acc = if due down then go (snd (Queue.pop down) :: acc) else List.rev acc in
    go []
  in
  ({ inner with send = (fun bytes -> Queue.push (!now + frames, bytes) up); receive }, clock)

(* a server, this program's side of a round on it (Soldat_online, which
 * is one for a whole program), and another player that is only its
 * messages: its keys, sent each frame *)
type world = {
  server : Soldat_server.t;
  port : int;
  clock : unit -> unit;
  mutable model : Soldat_model.model;
  mutable computer : Playground.computer;
  (* the other player's connection, the keys it holds, their number *)
  mutable other : (Transport.t * Soldat_soldier.control ref * int ref) option;
}

(* a computer with these keys held, its mouse to the right of the
 * screen's middle: the soldier looks right *)
let holding (keys : string list) : Playground.computer =
  let c = Playground.initial_computer in
  { c with keyboard = List.fold_left (fun k key -> Playground.update_keyboard true key k) c.keyboard keys; mouse = { c.mouse with mx = 200. } }

(* a sixtieth of a second: the server's tick, then this program's frame *)
let frame (w : world) : unit =
  w.clock ();
  Option.iter
    (fun ((t : Transport.t), keys, seq) ->
      ignore (t.receive ());
      t.send (Soldat_protocol.encode_to_server (Input (!seq, Soldat_wire.encode_control !keys)));
      incr seq)
    w.other;
  Unix.sleepf 0.0005;
  Soldat_server.step w.server;
  Soldat_server.tick w.server;
  Unix.sleepf 0.0005;
  w.model <- Soldat_online.update w.computer w.model

let frames (n : int) (w : world) : unit =
  for _ = 1 to n do
    frame w
  done

(* the round shown, once there is one *)
let shown (w : world) : Soldat_model.play option = match w.model.scenes.scene with Online (p, _) -> Some p | _ -> None

(* a soldier by its name, in the round shown and in the server's *)
let named (p : Soldat_model.play) (name : string) : Soldat_model.soldier =
  match List.find_opt (fun (s : Soldat_model.soldier) -> s.name = name) (Array.to_list p.soldiers) with
  | Some s -> s
  | None -> Alcotest.failf "no soldier named %s" name

let seen (w : world) (name : string) : Soldat_model.soldier = named (Option.get (shown w)) name
let truth (w : world) (name : string) : Soldat_model.soldier = named (Soldat_room.play (Option.get (Soldat_server.game w.server "test"))) name

(* pad's program in the room "test" of a new server, a floor with
 * [seats] soldiers, [lag] frames away; its soldier on the ground *)
let connect (caps : < Cap.network ; .. >) ~(seats : int) ~(lag : int) ~(room : string) : world =
  Soldat_sound.mute := true;
  Soldat_online.reset ();
  List.iter (fun name -> Soldat_online.know name floor) ("test" :: Soldat_model.maps);
  let (server, port) = Soldat_server.listen caps ~port:0 ~seats ~map_of:(fun _ -> floor) () in
  let (transport, clock) = lagged lag (Relay_client.connect caps ~host:"127.0.0.1" ~port) in
  Soldat_online.connected transport ~nick:"pad" ~room;
  { server; port; clock; model = Soldat_model.initial_model floor; computer = holding []; other = None }

(* a key pressed and let go *)
let press (w : world) (c : Playground.computer) : unit =
  w.computer <- c;
  frames 2 w;
  w.computer <- holding [];
  frames 20 w

let lobby (w : world) = match w.model.scenes.scene with Lobby l -> Some (l.rooms, l.chosen, l.here) | _ -> None

let start (caps : < Cap.network ; .. >) ~(seats : int) ~(lag : int) : world =
  let w = connect caps ~seats ~lag ~room:"test" in
  let rec wait n =
    if n > 0 && shown w = None then begin
      frame w;
      wait (n - 1)
    end
  in
  wait 600;
  if shown w = None then Alcotest.fail "no round after six hundred frames";
  frames 150 w;
  w

(* mm, another player in the room, who is only its messages: the keys
 * it holds, to change *)
let join (caps : < Cap.network ; .. >) (w : world) : Soldat_soldier.control ref =
  let t = Relay_client.connect caps ~host:"127.0.0.1" ~port:w.port in
  t.send (Soldat_protocol.encode_to_server (Hello "mm"));
  t.send (Soldat_protocol.encode_to_server (Join "test"));
  let keys = ref Soldat_soldier.no_control in
  w.other <- Some (t, keys, ref 0);
  frames 150 w;
  keys

let x (s : Soldat_model.soldier) : float = s.body.x

let tests (caps : < Cap.network ; .. >) =
  Testo.categorize "Online"
    [
      Testo.create "a seat in a room" (fun () ->
          let w = start caps ~seats:3 ~lag:0 in
          let p = Option.get (shown w) in
          Alcotest.(check int) "the room's three soldiers" 3 (Array.length p.soldiers);
          Alcotest.(check bool) "one of them pad's, a player's" true (seen w "pad").human;
          Alcotest.(check int) "and two bots'" 2 (List.length (List.filter (fun (s : Soldat_model.soldier) -> not s.human) (Array.to_list p.soldiers))));
      Testo.create "the lobby, a room, and back" (fun () ->
          let w = connect caps ~seats:2 ~lag:3 ~room:Soldat_protocol.lobby in
          frames 80 w;
          Alcotest.(check bool) "the lobby's screen: a room for each map, nobody in any, pad here" true
            (lobby w = Some (List.map (fun map -> (map, 0)) Soldat_model.maps, 0, [ "pad" ]));
          (* down: the second; down again: round to the first; up: the last *)
          let down = { (holding []) with keyboard = { (holding []).keyboard with kdown = true } } in
          let enter = { (holding []) with keyboard = { (holding []).keyboard with kenter = true } } in
          press w down;
          Alcotest.(check bool) "down: the next" true (Option.map (fun (_, chosen, _) -> chosen) (lobby w) = Some 1);
          (* enter: its room, a soldier in its round *)
          press w enter;
          frames 60 w;
          let room = List.nth Soldat_model.maps 1 in
          Alcotest.(check bool) "enter: a round shown" true (shown w <> None);
          Alcotest.(check bool) "the server's room of that name, pad in it" true
            (match Soldat_server.game w.server room with Some game -> Soldat_room.players game = 1 | None -> false);
          (* escape: the lobby again, the seat given back *)
          press w (holding [ "Escape" ]);
          frames 80 w;
          Alcotest.(check bool) "escape: the lobby again" true (lobby w <> None);
          Alcotest.(check bool) "its game, nobody's, is dropped" true (Soldat_server.game w.server room = None);
          (* and in again *)
          press w enter;
          frames 60 w;
          Alcotest.(check bool) "and in again" true (shown w <> None));
      Testo.create "a weapon chosen" (fun () ->
          let w = start caps ~seats:1 ~lag:6 in
          (* the key 8 of Soldat's menu: the Barrett *)
          w.computer <- holding [ "8" ];
          frames 3 w;
          w.computer <- holding [];
          frames 30 w;
          Alcotest.(check bool) "the server has it" true ((truth w "pad").primary = Barrett);
          Alcotest.(check bool) "and shows it back" true ((seen w "pad").primary = Barrett));
      Testo.create "its own soldier, at once" (fun () ->
          (* 6 frames each way: a key is answered 200 ms later *)
          let w = start caps ~seats:1 ~lag:6 in
          let before = Soldat_online.corrections () in
          let x0 = x (seen w "pad") in
          Alcotest.(check (Alcotest.float 0.05)) "standing where the server has it" (x (truth w "pad")) x0;
          (* d, four frames: nothing of it has reached the server yet *)
          w.computer <- holding [ "d" ];
          frames 4 w;
          Alcotest.(check (Alcotest.float 0.001)) "the server's has not moved" (x (truth w "pad")) x0;
          Alcotest.(check bool) "the one shown has" true (x (seen w "pad") > x0 +. 0.3);
          (* a second of it: shown ahead of the server's by what the keys on their way are worth *)
          frames 60 w;
          let ahead = x (seen w "pad") -. x (truth w "pad") in
          Alcotest.(check bool) (Printf.sprintf "running: ahead of the server's (%.1f)" ahead) true (ahead > 5. && ahead < 40.);
          (* let go: the two meet, and the server never had to move it *)
          w.computer <- holding [];
          frames 90 w;
          Alcotest.(check bool) "it ran" true (x (seen w "pad") > x0 +. 50.);
          Alcotest.(check (Alcotest.float 0.05)) "stopped: where the server has it" (x (truth w "pad")) (x (seen w "pad"));
          Alcotest.(check int) (Printf.sprintf "guessed right all along (%d before)" before) before (Soldat_online.corrections ()));
      Testo.create "jumping and jetting, guessed too" (fun () ->
          let w = start caps ~seats:1 ~lag:6 in
          let before = Soldat_online.corrections () in
          w.computer <- holding [ "d"; "w" ];
          frames 40 w;
          w.computer <- { (holding [ "a" ]) with mouse = { (holding []).mouse with mx = -200.; mrdown = true } };
          frames 60 w;
          w.computer <- holding [ "s" ];
          frames 150 w;
          let (a, b) = (seen w "pad", truth w "pad") in
          Alcotest.(check (pair (Alcotest.float 0.05) (Alcotest.float 0.05))) "landed: where the server has it" (b.body.x, b.body.y) (a.body.x, a.body.y);
          Alcotest.(check int) (Printf.sprintf "guessed right all along (%d before)" before) before (Soldat_online.corrections ()));
      Testo.create "pushed by what it could not guess" (fun () ->
          let w = start caps ~seats:2 ~lag:6 in
          let keys = join caps w in
          (* pad runs off to the right, mm shoots it in the back *)
          w.computer <- holding [ "d" ];
          frames 50 w;
          w.computer <- holding [];
          frames 60 w;
          let health = (truth w "pad").health in
          let (mx, my) = ((truth w "mm").body.x, (truth w "mm").body.y) in
          keys := { Soldat_soldier.no_control with fire = true; aim = (mx +. 1000., my -. 8.) };
          frames 25 w;
          keys := { !keys with fire = false };
          frames 120 w;
          Alcotest.(check bool) "hit" true ((truth w "pad").health < health);
          Alcotest.(check bool) "the server's word moved it" true (Soldat_online.corrections () > 0);
          Alcotest.(check (Alcotest.float 0.05)) "the health shown is the server's" (truth w "pad").health (seen w "pad").health;
          if (truth w "pad").dead = None then
            Alcotest.(check (Alcotest.float 0.05)) "and it is again where the server has it" (x (truth w "pad")) (x (seen w "pad")));
      Testo.create "the others, between two rounds" (fun () ->
          let w = start caps ~seats:2 ~lag:0 in
          let keys = join caps w in
          keys := { Soldat_soldier.no_control with right = true; aim = (10000., 0.) };
          frames 40 w;
          (* rounds come every other frame: it moves in each all the same,
           * a little behind where the server has it *)
          let moved = ref 0 and behind = ref 0 in
          for _ = 1 to 60 do
            let before = x (seen w "mm") in
            frame w;
            if x (seen w "mm") > before +. 0.2 then incr moved;
            if x (seen w "mm") < x (truth w "mm") -. 2. then incr behind
          done;
          Alcotest.(check bool) (Printf.sprintf "it moves in each frame (%d of 60)" !moved) true (!moved >= 55);
          Alcotest.(check bool) (Printf.sprintf "in the past (%d of 60)" !behind) true (!behind >= 55));
    ]
