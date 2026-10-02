(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* The server: players connect to it (WebSocket, from a browser or a
 * native program), name themselves, enter rooms and talk
 * (Soldat_server.mli, Soldat_lobby.mli). The games played in the rooms
 * are to come. Its parameters as name=value: port (23073, Soldat's),
 * bind (127.0.0.1: this computer only; 0.0.0.0 for every network it is
 * on), capacity (32 players a room). It prints the rooms whenever
 * someone comes, goes or moves.
 *
 * In Soldat: server/Main.pas and server/ServerLoop.pas,
 * opensoldatserver.
 *)

let flag (name : string) (default : string) : string =
  Array.to_list Sys.argv
  |> List.find_map (fun a ->
         match String.index_opt a '=' with
         | Some i when String.sub a 0 i = name -> Some (String.sub a (i + 1) (String.length a - i - 1))
         | _ -> None)
  |> Option.value ~default

let () =
  Cap.main (fun caps ->
      let bind = flag "bind" "127.0.0.1" in
      let capacity = int_of_string (flag "capacity" "32") in
      let (server, port) = Soldat_server.listen caps ~bind ~port:(int_of_string (flag "port" "23073")) ~capacity () in
      Printf.printf "mini-soldat-server on %s:%d, %d players a room\n%!" bind port capacity;
      let seen = ref (Soldat_lobby.rooms (Soldat_server.lobby server)) in
      while true do
        Soldat_server.wait server 1.0;
        Soldat_server.step server;
        let now = Soldat_lobby.rooms (Soldat_server.lobby server) in
        if now <> !seen then begin
          print_endline (String.concat "   " (List.map (fun (room, nicks) -> Printf.sprintf "%s: %s" room (String.concat " " nicks)) now));
          seen := now
        end
      done)
