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
 * (Soldat_server.mli, Soldat_lobby.mli); and a room other than the
 * lobby is a game it plays, 60 ticks a second, its soldiers Soldat's
 * bots until a player takes one (Soldat_room.mli). Its parameters as
 * name=value: port (23073, Soldat's), bind (127.0.0.1: this computer
 * only; 0.0.0.0 for every network it is on), capacity (32 players a
 * room), seats (6 soldiers a game), maps (data/maps: a room named
 * ctf_Ash plays on maps/ctf_Ash.pms if there is one, else on Arena2;
 * named Arena2.rm, a Rambomatch on Arena2), bonus (0: how often bonus
 * kits appear, 1 to 5).
 * It prints the rooms whenever someone comes, goes or moves.
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

(* a room's map: the file of its name under [dir], if there is one and
 * it is a map; Arena2, which the program carries, else. A room's name
 * has no "/" and no ".." that matter: it is checked 1 to 24 printable
 * characters, and only letters, digits, "_" and "-" are looked for *)
let map_of (caps : < Cap.open_in ; .. >) (dir : string) (room : string) : Soldat_map.t =
  let plain = String.for_all (fun c -> (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c = '_' || c = '-') room in
  let file = Filename.concat dir (room ^ ".pms") in
  let read () =
    let chan = CapStdlib.open_in caps file in
    Fun.protect ~finally:(fun () -> close_in chan) (fun () ->
        set_binary_mode_in chan true;
        really_input_string chan (in_channel_length chan))
  in
  match if plain && Sys.file_exists file then Pms.parse (read ()) else Error "no such map" with
  | Ok pms -> Soldat_map.of_pms pms
  | Error _ | (exception Sys_error _) -> Lazy.force Soldat_map.arena2

let () =
  Cap.main (fun caps ->
      let bind = flag "bind" "127.0.0.1" in
      let capacity = int_of_string (flag "capacity" "32") in
      let seats = int_of_string (flag "seats" "6") in
      let maps = flag "maps" "data/maps" in
      (* nobody looks or listens here *)
      (* the server's bots are Soldat's; it makes no sparks *)
      Soldat_orig.register ();
      Soldat_state.most := 0;
      Soldat_sound.mute := true;
      let (server, port) = Soldat_server.listen caps ~bind ~port:(int_of_string (flag "port" "23073")) ~capacity ~seats ~bonuses:(int_of_string (flag "bonus" "0")) ~map_of:(map_of caps maps) () in
      Printf.printf "mini-soldat-server on %s:%d, %d players a room, %d soldiers a game, maps in %s\n%!" bind port capacity seats maps;
      let seen = ref (Soldat_lobby.rooms (Soldat_server.lobby server)) in
      (* the games' clock: a tick every 60th of a second, caught up when
       * late, but not by more than a quarter of a second *)
      let step = 1. /. 60. in
      let next = ref (Unix.gettimeofday () +. step) in
      while true do
        Soldat_server.wait server (Float.max 0. (Float.min 1. (!next -. Unix.gettimeofday ())));
        Soldat_server.step server;
        let now = Unix.gettimeofday () in
        if !next < now -. 0.25 then next := now;
        while !next <= now do
          Soldat_server.tick server;
          next := !next +. step
        done;
        let now = Soldat_lobby.rooms (Soldat_server.lobby server) in
        if now <> !seen then begin
          print_endline (String.concat "   " (List.map (fun (room, nicks) -> Printf.sprintf "%s: %s" room (String.concat " " nicks)) now));
          seen := now
        end
      done)
