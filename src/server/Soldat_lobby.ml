(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_lobby.mli *)

module Ints = Map.Make (Int)

type client = { nick : string; room : string }

(* the rooms are not kept: they are what the clients say they are in *)
type t = { clients : client Ints.t; capacity : int }

let create ?(capacity = 32) () : t = { clients = Ints.empty; capacity }

(* the connections in [room], in the order they connected, each with
 * its nick *)
let members (room : string) (t : t) : (int * string) list =
  Ints.fold (fun id (c : client) acc -> if c.room = room then (id, c.nick) :: acc else acc) t.clients [] |> List.rev

let rooms (t : t) : (string * string list) list =
  let names = Ints.fold (fun _ (c : client) acc -> c.room :: acc) t.clients [ Soldat_protocol.lobby ] in
  List.sort_uniq compare names |> List.map (fun room -> (room, List.map snd (members room t)))

(* [message] to everyone in [room] but [id] *)
let to_others (id : int) (room : string) (message : Soldat_protocol.to_client) (t : t) : (int * Soldat_protocol.to_client) list =
  List.filter_map (fun (other, _) -> if other = id then None else Some (other, message)) (members room t)

(* [id], known as [c], goes from its room into [room]: those it leaves
 * and those it joins are told, and it is told who is there *)
let move (id : int) (c : client) (room : string) (t : t) : t * (int * Soldat_protocol.to_client) list =
  let gone = to_others id c.room (Went c.nick) t in
  let t = { t with clients = Ints.add id { c with room } t.clients } in
  (t, gone @ to_others id room (Came c.nick) t @ [ (id, Entered (room, List.map snd (members room t))) ])

let receive (id : int) (message : Soldat_protocol.to_server) (t : t) : t * (int * Soldat_protocol.to_client) list =
  let refused why = (t, [ (id, Soldat_protocol.Refused why) ]) in
  match (Ints.find_opt id t.clients, message) with
  | Some _, Hello _ -> refused "you have a nick already"
  | None, Hello nick ->
      let taken = Ints.exists (fun _ (c : client) -> String.lowercase_ascii c.nick = String.lowercase_ascii nick) t.clients in
      if not (Soldat_protocol.valid_name nick) then refused "a nick is 1 to 24 characters, no space"
      else if taken then refused "this nick is taken"
      else
        let t = { t with clients = Ints.add id { nick; room = Soldat_protocol.lobby } t.clients } in
        ( t,
          [ (id, Soldat_protocol.Welcome nick); (id, Entered (Soldat_protocol.lobby, List.map snd (members Soldat_protocol.lobby t))) ]
          @ to_others id Soldat_protocol.lobby (Came nick) t )
  | None, _ -> refused "say Hello first"
  | Some c, Join room ->
      if not (Soldat_protocol.valid_name room) then refused "a room's name is 1 to 24 characters, no space"
      else if room = c.room then refused "you are in this room"
      else if room <> Soldat_protocol.lobby && List.length (members room t) >= t.capacity then refused "this room is full"
      else move id c room t
  | Some c, Leave -> if c.room = Soldat_protocol.lobby then refused "you are in the lobby" else move id c Soldat_protocol.lobby t
  | Some c, Say text ->
      if not (Soldat_protocol.valid_text text) then refused "a line is 1 to 200 characters"
      else (t, List.map (fun (other, _) -> (other, Soldat_protocol.Said (c.nick, text))) (members c.room t))
  | Some _, List -> (t, [ (id, Rooms (List.map (fun (room, nicks) -> (room, List.length nicks)) (rooms t))) ])
  (* a game's keys are the room's game's, not the lobby's (Soldat_server) *)
  | Some _, (Input _ | Weapon _) -> (t, [])

let who (id : int) (t : t) : (string * string) option = Option.map (fun (c : client) -> (c.nick, c.room)) (Ints.find_opt id t.clients)

let left (id : int) (t : t) : t * (int * Soldat_protocol.to_client) list =
  match Ints.find_opt id t.clients with
  | None -> (t, [])
  | Some c ->
      let t = { t with clients = Ints.remove id t.clients } in
      (t, to_others id c.room (Went c.nick) t)
