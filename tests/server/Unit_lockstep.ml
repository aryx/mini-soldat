(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_lockstep.mli *)

let floor = Testutil_map.floor ()
let right : Soldat_soldier.control = { Soldat_soldier.no_control with right = true; aim = (10000., 0.) }
let left : Soldat_soldier.control = { Soldat_soldier.no_control with left = true; aim = (-10000., 0.) }

(* [frames] frames of two peers on a network: the host holds right, the
 * other left; the two games after, and the bytes a packet was at most *)
let played ?(frames = 600) (config : Sim_net.config) : Soldat_lockstep.t * Soldat_lockstep.t * int =
  let net = Sim_net.create ~seed:3 config in
  let round () = Soldat_update.start ~bots:(Soldat_bots.cast 3 1) floor in
  let a = ref (Soldat_lockstep.start ~me:0 (round ())) and b = ref (Soldat_lockstep.start ~me:1 (round ())) in
  let most = ref 0 in
  for f = 1 to frames do
    let now = float_of_int f /. 60. in
    let turn peer me other keys =
      let incoming = List.map snd (Sim_net.receive net ~now me) in
      let (game, packet) = Soldat_lockstep.frame !peer ~incoming keys ~look:(0., 0.) in
      peer := game;
      most := max !most (String.length packet);
      Sim_net.send net ~now ~src:me ~dst:other packet
    in
    turn a 0 1 right;
    turn b 1 0 left
  done;
  (!a, !b, !most)

let ticks (g : Soldat_lockstep.t) : int = (Soldat_lockstep.play g).frame
let bodies (g : Soldat_lockstep.t) = Array.map (fun (s : Soldat_model.soldier) -> (s.body.x, s.body.y, s.health, s.kills)) (Soldat_lockstep.play g).soldiers

let tests =
  Testo.categorize "Lockstep"
    [
      Testo.create "two peers, one round" (fun () ->
          let (a, b, most) = played Sim_net.perfect in
          Alcotest.(check bool) (Printf.sprintf "both played, all but the delay's ticks (%d of 600)" (ticks a)) true (ticks a > 590 && abs (ticks a - ticks b) <= 1);
          (* the same round: compared at the same tick *)
          let (a, b, _) = if ticks a = ticks b then (a, b, most) else played ~frames:601 Sim_net.perfect in
          Alcotest.(check bool) "the same round, to the last digit" true (ticks a <> ticks b || bodies a = bodies b);
          Alcotest.(check (pair (option int) (option int))) "and never seen to differ" (None, None) (Soldat_lockstep.desync a, Soldat_lockstep.desync b);
          let x (g : Soldat_lockstep.t) i = (Soldat_lockstep.play g).soldiers.(i).body.x in
          let start = (Soldat_update.start ~bots:(Soldat_bots.cast 3 1) floor).soldiers.(0).body.x in
          Alcotest.(check bool) "the host's soldier went right, in the other's round too" true (x b 0 > start +. 50. || (Soldat_lockstep.play b).soldiers.(0).deaths > 0);
          Alcotest.(check bool) "the other's is a player's, not a bot's" true ((Soldat_lockstep.play a).brains.(1) = None && (Soldat_lockstep.play a).soldiers.(1).human);
          Alcotest.(check bool) (Printf.sprintf "a packet: a few keys, not a round (%d bytes at most)" most) true (most < 200));
      Testo.create "a slow network: it waits, it does not differ" (fun () ->
          (* 100 ms one way, some lost: more than the 3 ticks of delay *)
          let (a, b, _) = played { latency = 0.1; jitter = 0.02; loss = 0.1; duplication = 0.05 } in
          Alcotest.(check bool) (Printf.sprintf "it stalled (%d frames), and played fewer ticks (%d of 600)" (Soldat_lockstep.stalls a) (ticks a)) true
            (Soldat_lockstep.stalls a > 50 && ticks a < 590 && ticks a > 100);
          Alcotest.(check (pair (option int) (option int))) "the two rounds never differed" (None, None) (Soldat_lockstep.desync a, Soldat_lockstep.desync b));
    ]
