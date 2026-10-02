(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_server.mli *)

type t = { server : Server.t; mutable lobby : Soldat_lobby.t }

let listen (caps : < Cap.network ; .. >) ?(bind = "127.0.0.1") ?(port = 23073) ?capacity () : t * int =
  let (server, port) = Server.listen caps ~bind ~port () in
  ({ server; lobby = Soldat_lobby.create ?capacity () }, port)

let step (t : t) : unit =
  let answer ((lobby, out) : Soldat_lobby.t * (int * Soldat_protocol.to_client) list) : unit =
    t.lobby <- lobby;
    List.iter (fun (id, message) -> Server.send t.server id (Soldat_protocol.encode_to_client message)) out
  in
  Server.step t.server
  |> List.iter (fun (event : Server.event) ->
         match event with
         | Joined _ -> () (* nobody until it says Hello *)
         | Message (id, bytes) -> (
             match Soldat_protocol.decode_to_server bytes with
             | Ok message -> answer (Soldat_lobby.receive id message t.lobby)
             | Error _ ->
                 (* not a message: the connection closed, and the others
                  * told now (a Left that came after would find nobody) *)
                 answer (Soldat_lobby.left id t.lobby);
                 Server.close t.server id)
         | Left id -> answer (Soldat_lobby.left id t.lobby));
  Server.flush t.server

let wait (t : t) (timeout : float) : unit = Server.wait t.server timeout
let lobby (t : t) : Soldat_lobby.t = t.lobby
