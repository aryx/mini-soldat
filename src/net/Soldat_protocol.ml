(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_protocol.mli *)

type to_server = Hello of string | Join of string | Leave | Say of string | List | Input of int * string | Weapon of int

type to_client =
  | Welcome of string
  | Refused of string
  | Rooms of (string * int) list
  | Entered of string * string list
  | Came of string
  | Went of string
  | Said of string * string
  | Seat of { seat : int; map : string }
  | World of { acked : int; world : string }

let lobby = "lobby"

let valid_name (s : string) : bool =
  let n = String.length s in
  n >= 1 && n <= 24 && String.for_all (fun c -> c > ' ' && c < '\x7f') s

let valid_text (s : string) : bool =
  let n = String.length s in
  n >= 1 && n <= 200 && String.for_all (fun c -> c >= ' ' && c <> '\x7f') s

(*****************************************************************************)
(* Writing *)
(*****************************************************************************)

let put_list (w : Wire.writer) (put : 'a -> unit) (xs : 'a list) : unit =
  Wire.put_varint w (List.length xs);
  List.iter put xs

let encode_to_server (m : to_server) : string =
  Wire.to_bytes (fun w ->
      match m with
      | Hello nick -> Wire.put_u8 w 0x10; Wire.put_string w nick
      | Join room -> Wire.put_u8 w 0x11; Wire.put_string w room
      | Leave -> Wire.put_u8 w 0x12
      | Say text -> Wire.put_u8 w 0x13; Wire.put_string w text
      | List -> Wire.put_u8 w 0x14
      | Input (seq, keys) -> Wire.put_u8 w 0x15; Wire.put_varint w seq; Wire.put_string w keys
      | Weapon key -> Wire.put_u8 w 0x16; Wire.put_u8 w key)

let encode_to_client (m : to_client) : string =
  Wire.to_bytes (fun w ->
      match m with
      | Welcome nick -> Wire.put_u8 w 0x20; Wire.put_string w nick
      | Refused why -> Wire.put_u8 w 0x21; Wire.put_string w why
      | Rooms rooms ->
          Wire.put_u8 w 0x22;
          put_list w (fun (room, n) -> Wire.put_string w room; Wire.put_varint w n) rooms
      | Entered (room, nicks) -> Wire.put_u8 w 0x23; Wire.put_string w room; put_list w (Wire.put_string w) nicks
      | Came nick -> Wire.put_u8 w 0x24; Wire.put_string w nick
      | Went nick -> Wire.put_u8 w 0x25; Wire.put_string w nick
      | Said (nick, text) -> Wire.put_u8 w 0x26; Wire.put_string w nick; Wire.put_string w text
      | Seat { seat; map } -> Wire.put_u8 w 0x27; Wire.put_u8 w seat; Wire.put_string w map
      | World { acked; world } -> Wire.put_u8 w 0x28; Wire.put_signed w acked; Wire.put_string w world)

(*****************************************************************************)
(* Reading *)
(*****************************************************************************)
(* the fields are read with a let each, in the order they were written:
 * the order a tuple's parts are evaluated in is not the one they are
 * written in *)

let get_string (r : Wire.reader) : string =
  let s = Wire.get_string r in
  if String.length s > 255 then Wire.fail r "a string longer than 255 bytes" else s

(* a count that lies stops at the first item whose bytes are missing *)
let get_list (r : Wire.reader) (get : unit -> 'a) : 'a list =
  let n = Wire.get_varint r in
  List.init n (fun _ -> get ())

let decode_to_server (bytes : string) : (to_server, string) result =
  Wire.parse
    (fun r ->
      match Wire.get_u8 r with
      | 0x10 -> Hello (get_string r)
      | 0x11 -> Join (get_string r)
      | 0x12 -> Leave
      | 0x13 -> Say (get_string r)
      | 0x14 -> List
      | 0x15 ->
          let seq = Wire.get_varint r in
          let keys = get_string r in
          Input (seq, keys)
      | 0x16 ->
          let key = Wire.get_u8 r in
          if key > 9 then Wire.fail r "a weapon's key is 0 to 9" else Weapon key
      | _ -> Wire.fail r "not a player's message")
    bytes

let decode_to_client (bytes : string) : (to_client, string) result =
  Wire.parse
    (fun r ->
      match Wire.get_u8 r with
      | 0x20 -> Welcome (get_string r)
      | 0x21 -> Refused (get_string r)
      | 0x22 ->
          Rooms
            (get_list r (fun () ->
                 let room = get_string r in
                 let n = Wire.get_varint r in
                 (room, n)))
      | 0x23 ->
          let room = get_string r in
          let nicks = get_list r (fun () -> get_string r) in
          Entered (room, nicks)
      | 0x24 -> Came (get_string r)
      | 0x25 -> Went (get_string r)
      | 0x26 ->
          let nick = get_string r in
          let text = get_string r in
          Said (nick, text)
      | 0x27 ->
          let seat = Wire.get_u8 r in
          let map = get_string r in
          Seat { seat; map }
      | 0x28 ->
          (* the round's bytes: Soldat_wire's to read, however long *)
          let acked = Wire.get_signed r in
          let world = Wire.get_string r in
          World { acked; world }
      | _ -> Wire.fail r "not a server's message")
    bytes
