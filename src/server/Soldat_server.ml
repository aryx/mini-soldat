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

type t = {
  server : Server.t;
  mutable lobby : Soldat_lobby.t;
  (* the rooms' games, by the room's name; and each connection's seat
   * in its room's *)
  games : (string, Soldat_room.t) Hashtbl.t;
  seats : (int, string * int) Hashtbl.t;
  (* a room's map, by the room's name *)
  map_of : string -> Soldat_map.t;
  room_seats : int;
  mutable ticks : int;
}

let listen (caps : < Cap.network ; .. >) ?(bind = "127.0.0.1") ?(port = 23073) ?capacity ?(seats = 6) ?(map_of = fun _ -> Lazy.force Soldat_map.arena2) () : t * int =
  let (server, port) = Server.listen caps ~bind ~port () in
  ({ server; lobby = Soldat_lobby.create ?capacity (); games = Hashtbl.create 8; seats = Hashtbl.create 32; map_of; room_seats = seats; ticks = 0 }, port)

let send (t : t) (id : int) (message : Soldat_protocol.to_client) : unit = Server.send t.server id (Soldat_protocol.encode_to_client message)

(* connection [id] has no seat any more: its bot has it back *)
let stand_up (t : t) (id : int) : unit =
  match Hashtbl.find_opt t.seats id with
  | None -> ()
  | Some (room, seat) ->
      Hashtbl.remove t.seats id;
      Option.iter (fun game -> Hashtbl.replace t.games room (Soldat_room.leave seat game)) (Hashtbl.find_opt t.games room)

(* connection [id] is now in [room]: out of the seat it had; and, the
 * room not the lobby, in one of its game, made if this is its first
 * player *)
let sit_down (t : t) (id : int) (room : string) : unit =
  stand_up t id;
  if room <> Soldat_protocol.lobby then
    match Soldat_lobby.who id t.lobby with
    | None -> ()
    | Some (nick, _) -> (
        let game = match Hashtbl.find_opt t.games room with Some game -> game | None -> Soldat_room.create ~seats:t.room_seats ~seed:(Hashtbl.hash room) ~name:room (t.map_of room) in
        match Soldat_room.join nick game with
        | Some (game, seat) ->
            Hashtbl.replace t.games room game;
            Hashtbl.replace t.seats id (room, seat);
            send t id (Seat { seat; map = room })
        | None ->
            Hashtbl.replace t.games room game;
            send t id (Refused "every soldier of this game is somebody's: you may watch the room talk"))

let step (t : t) : unit =
  let answer ((lobby, out) : Soldat_lobby.t * (int * Soldat_protocol.to_client) list) : unit =
    t.lobby <- lobby;
    List.iter
      (fun (id, (message : Soldat_protocol.to_client)) ->
        send t id message;
        (* who has entered a room sits in its game *)
        match message with Entered (room, _) -> sit_down t id room | _ -> ())
      out
  in
  Server.step t.server
  |> List.iter (fun (event : Server.event) ->
         match event with
         | Joined _ -> () (* nobody until it says Hello *)
         | Message (id, bytes) -> (
             match Soldat_protocol.decode_to_server bytes with
             | Ok (Input (seq, keys)) -> (
                 (* its keys go to its seat; keys that are not keys close it *)
                 match (Soldat_wire.decode_control keys, Hashtbl.find_opt t.seats id) with
                 | (Ok control, Some (room, seat)) ->
                     Option.iter (fun game -> Hashtbl.replace t.games room (Soldat_room.input seat ~seq control game)) (Hashtbl.find_opt t.games room)
                 | (Ok _, None) -> ()
                 | (Error _, _) ->
                     stand_up t id;
                     answer (Soldat_lobby.left id t.lobby);
                     Server.close t.server id)
             | Ok message -> answer (Soldat_lobby.receive id message t.lobby)
             | Error _ ->
                 (* not a message: the connection closed, and the others
                  * told now (a Left that came after would find nobody) *)
                 stand_up t id;
                 answer (Soldat_lobby.left id t.lobby);
                 Server.close t.server id)
         | Left id ->
             stand_up t id;
             answer (Soldat_lobby.left id t.lobby));
  Server.flush t.server

(* a tick of every room's game, 60 a second: the caller's clock. A game
 * nobody plays is dropped. Every other tick the round is sent to who
 * plays it *)
let tick (t : t) : unit =
  t.ticks <- t.ticks + 1;
  let rooms = Hashtbl.fold (fun room _ acc -> room :: acc) t.games [] in
  List.iter
    (fun room ->
      let game = Hashtbl.find t.games room in
      if Soldat_room.players game = 0 then Hashtbl.remove t.games room
      else begin
        let game = Soldat_room.tick game in
        let game =
          if t.ticks mod 2 = 0 then begin
            let (game, world) = Soldat_room.snapshot game in
            Hashtbl.iter (fun id (its, seat) -> if its = room then send t id (World { acked = Soldat_room.acked game seat; world })) t.seats;
            game
          end
          else game
        in
        Hashtbl.replace t.games room game
      end)
    rooms;
  Server.flush t.server

let wait (t : t) (timeout : float) : unit = Server.wait t.server timeout
let lobby (t : t) : Soldat_lobby.t = t.lobby
let game (t : t) (room : string) : Soldat_room.t option = Hashtbl.find_opt t.games room
