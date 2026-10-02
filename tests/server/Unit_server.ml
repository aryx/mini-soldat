(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_server.mli *)

(* a player's program, for a test: its connection, and what the server
 * has told it so far *)
type player = { transport : Transport.t; mutable heard : Soldat_protocol.to_client list }

let connect (caps : < Cap.network ; .. >) (port : int) : player = { transport = Relay_client.connect caps ~host:"127.0.0.1" ~port; heard = [] }

let send (p : player) (m : Soldat_protocol.to_server) : unit = p.transport.send (Soldat_protocol.encode_to_server m)

(* the server's event loop and the players' frames, a millisecond at a
 * time, until [until] holds (5 seconds at most: a slow machine is
 * awaited, not failed) *)
let pump (server : Soldat_server.t) (players : player list) (until : unit -> bool) : unit =
  let rec go i =
    if i < 5000 && not (until ()) then begin
      Soldat_server.step server;
      List.iter
        (fun p ->
          p.transport.receive ()
          |> List.iter (fun bytes ->
                 match Soldat_protocol.decode_to_client bytes with
                 | Ok m -> p.heard <- p.heard @ [ m ]
                 | Error why -> Alcotest.failf "the server sent bytes that are no message: %s" why))
        players;
      Unix.sleepf 0.001;
      go (i + 1)
    end
  in
  go 0

let heard (p : player) (m : Soldat_protocol.to_client) () : bool = List.mem m p.heard

let rooms (server : Soldat_server.t) : (string * string list) list = Soldat_lobby.rooms (Soldat_server.lobby server)

let tests (caps : < Cap.network ; .. >) =
  Testo.categorize "Server"
    [
      Testo.create "two players, a room, a line" (fun () ->
          let (server, port) = Soldat_server.listen caps ~port:0 () in
          let pad = connect caps port and mm = connect caps port in
          send pad (Hello "pad");
          pump server [ pad; mm ] (heard pad (Entered ("lobby", [ "pad" ])));
          send mm (Hello "mm");
          pump server [ pad; mm ] (heard pad (Came "mm"));
          Alcotest.(check bool) "mm welcomed, with who is there" true (heard mm (Welcome "mm") () && heard mm (Entered ("lobby", [ "pad"; "mm" ])) ());
          send pad (Join "ctf_Ash");
          pump server [ pad; mm ] (heard mm (Went "pad"));
          send mm List;
          pump server [ pad; mm ] (heard mm (Rooms [ ("ctf_Ash", 1); ("lobby", 1) ]));
          send mm (Join "ctf_Ash");
          pump server [ pad; mm ] (heard pad (Came "mm"));
          send mm (Say "hello");
          pump server [ pad; mm ] (fun () -> heard pad (Said ("mm", "hello")) () && heard mm (Said ("mm", "hello")) ());
          Alcotest.(check bool) "both heard the line" true (heard pad (Said ("mm", "hello")) () && heard mm (Said ("mm", "hello")) ());
          Alcotest.(check (list (pair string (list string)))) "the server's rooms" [ ("ctf_Ash", [ "pad"; "mm" ]); ("lobby", []) ] (rooms server));
      Testo.create "garbage closes the one that sent it" (fun () ->
          let (server, port) = Soldat_server.listen caps ~port:0 () in
          let pad = connect caps port and mm = connect caps port in
          send pad (Hello "pad");
          send mm (Hello "mm");
          pump server [ pad; mm ] (fun () -> heard pad (Came "mm") () || heard mm (Came "pad") ());
          mm.transport.send "\x7fnot a message";
          pump server [ pad ] (heard pad (Went "mm"));
          Alcotest.(check bool) "the other told it went" true (heard pad (Went "mm") ());
          Alcotest.(check (list (pair string (list string)))) "and only it is gone" [ ("lobby", [ "pad" ]) ] (rooms server);
          send pad (Say "still here");
          pump server [ pad ] (heard pad (Said ("pad", "still here")));
          Alcotest.(check bool) "the server still answers" true (heard pad (Said ("pad", "still here")) ()));
    ]
