(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *
 * Adapted from OpenSoldat's shared/AI.pas, shared/Waypoints.pas and
 * shared/SharedConfig.pas, Copyright 2001-2020 Transhuman Design,
 * Copyright 2020-2023 OpenSoldat contributors (the MIT License).
 *)

(* See Soldat_cast.mli *)
open Soldat_model (* its types, used all along *)

(*****************************************************************************)
(* The characters *)
(*****************************************************************************)

(* the lines "Key=value" of a file *)
let values (text : string) : (string * string) list =
  String.split_on_char '\n' text
  |> List.filter_map (fun line ->
         let line = String.trim line in
         match String.index_opt line '=' with
         | Some i -> Some (String.sub line 0 i, String.trim (String.sub line (i + 1) (String.length line - i - 1)))
         | None -> None)

(* "$00BBGGRR", Delphi's TColor: blue first (ReadConfColor turns it
 * round) *)
let colour (s : string) : (int * int * int) option =
  match int_of_string_opt ("0x" ^ String.sub s 1 (String.length s - 1)) with
  | Some n when String.length s > 1 && s.[0] = '$' -> Some (n land 255, (n lsr 8) land 255, (n lsr 16) land 255)
  | _ -> None
  | exception Invalid_argument _ -> None

(* the skin's is read as it is, red first (ReadConfMagicColor) *)
let turned ((r, g, b) : int * int * int) : int * int * int = (b, g, r)

let character (text : string) : character option =
  let lines = String.split_on_char '\n' text |> List.map String.trim in
  let v = values text in
  let get key = List.assoc_opt key v in
  let number key default = Option.value (Option.bind (get key) int_of_string_opt) ~default in
  let colour_of key default = Option.value (Option.bind (get key) colour) ~default in
  let favourite =
    Option.bind (get "Favourite_Weapon") (fun name -> List.find_opt (fun id -> (Soldat_weapons.get id).name = name) Soldat_weapons.primaries)
  in
  match (List.mem "[BOT]" lines, get "Name", favourite) with
  | (true, Some bot, Some favourite) ->
      Some
        {
          bot;
          bot_shirt = colour_of "Color1" (128, 128, 128);
          bot_trousers = colour_of "Color2" (64, 64, 64);
          bot_skin = turned (colour_of "Skin_Color" (120, 180, 230));
          favourite;
          accuracy = number "Accuracy" 20;
          shoot_dead = number "Shoot_Dead" 0 = 1;
          grenade_freq = number "Grenade_Frequency" 200;
          camper = number "Camping" 0;
        }
  | _ -> None

let characters : character list Lazy.t = lazy (List.filter_map (fun (_, base64) -> character (Base64.decode base64)) Bots_data.all)

let cast (n : int) (round : int) : character list =
  let all = Array.of_list (Lazy.force characters) in
  let count = Array.length all in
  if count = 0 then [] else List.init n (fun i -> all.((((round + i) mod count) + count) mod count))

(* Random(n): a whole number from 0 to n - 1; 0 for none *)
let whole ~(random : unit -> float) (n : int) : int = if n <= 0 then 0 else min (n - 1) (int_of_float (random () *. float_of_int n))

(* TSprite.Respawn: its favourite, or one of the first nine *)
let weapon (c : character) ~(random : unit -> float) : Soldat_weapons.id =
  if whole ~random 2 = 0 then c.favourite else List.nth Soldat_weapons.primaries (whole ~random 9)

(* the twin's bot (ai=engine): its looks, and the weapon it appears with *)
let engine : character =
  { bot = "Engine"; bot_shirt = (60, 110, 220); bot_trousers = (30, 55, 110); bot_skin = (230, 180, 120); favourite = Ak74; accuracy = 0; shoot_dead = false; grenade_freq = -1; camper = 0 }
