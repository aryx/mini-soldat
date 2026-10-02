(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_anims.mli *)

type id =
  | Stand | Run | Run_back | Jump | Jump_side | Fall | Crouch | Crouch_run | Reload | Throw | Recoil
  | Small_recoil | Shotgun | Clip_out | Clip_in | Slide_back | Change | Throw_weapon | Weapon_none
  | Punch | Reload_bow | Barret | Roll | Roll_back | Crouch_run_back | Cigar | Match | Smoke | Wipe
  | Groin | Piss | Mercy | Mercy2 | Take_off | Prone | Victory | Aim | Hands_up_aim | Prone_move
  | Get_up | Aim_recoil | Hands_up_recoil | Melee | Own

(* coupling: the order is dune's rule's, which is Soldat's IDs' *)
let all : (id * string * int * bool) list =
  [ (Stand, "stoi", 3, true);
    (Run, "biega", 1, true);
    (Run_back, "biegatyl", 1, true);
    (Jump, "skok", 1, false);
    (Jump_side, "skokwbok", 1, false);
    (Fall, "spada", 1, false);
    (Crouch, "kuca", 1, false);
    (Crouch_run, "kucaidzie", 2, true);
    (Reload, "laduje", 2, false);
    (Throw, "rzuca", 1, false);
    (Recoil, "odrzut", 1, false);
    (Small_recoil, "odrzut2", 1, false);
    (Shotgun, "shotgun", 1, false);
    (Clip_out, "clipout", 3, false);
    (Clip_in, "clipin", 3, false);
    (Slide_back, "slideback", 2, true);
    (Change, "change", 1, false);
    (Throw_weapon, "wyrzuca", 1, false);
    (Weapon_none, "bezbroni", 3, false);
    (Punch, "bije", 1, false);
    (Reload_bow, "strzala", 1, false);
    (Barret, "barret", 9, false);
    (Roll, "skokdolobrot", 1, false);
    (Roll_back, "skokdolobrottyl", 1, false);
    (Crouch_run_back, "kucaidzietyl", 2, true);
    (Cigar, "cigar", 3, false);
    (Match, "match", 3, false);
    (Smoke, "smoke", 4, false);
    (Wipe, "wipe", 4, false);
    (Groin, "krocze", 2, false);
    (Piss, "szcza", 8, false);
    (Mercy, "samo", 3, false);
    (Mercy2, "samo2", 3, false);
    (Take_off, "takeoff", 2, false);
    (Prone, "lezy", 1, false);
    (Victory, "cieszy", 3, false);
    (Aim, "celuje", 2, false);
    (Hands_up_aim, "gora", 2, false);
    (Prone_move, "lezyidzie", 2, true);
    (Get_up, "wstaje", 1, false);
    (Aim_recoil, "celujeodrzut", 1, false);
    (Hands_up_recoil, "goraodrzut", 1, false);
    (Melee, "kolba", 1, false);
    (Own, "rucha", 3, false) ]

(* an animation, ready to be asked: its speed, whether it loops, how
 * many frames, and where its first frame's first point is in the
 * numbers (8 bytes a point, 20 points a frame) *)
type animation = { speed : int; loop : bool; count : int; offset : int }

let bytes : string = Base64.decode Anims_data.base64

(* in [all]'s order, which is the numbers' *)
let table : (id, animation) Hashtbl.t =
  let table = Hashtbl.create 64 and offset = ref 0 in
  List.iter2
    (fun (id, file, speed, loop) (name, count) ->
      if file <> name then failwith (Printf.sprintf "Soldat_anims: %s where %s was expected" name file);
      Hashtbl.replace table id { speed; loop; count; offset = !offset };
      offset := !offset + (count * 20 * 8))
    all Anims_data.counts;
  table

let get (id : id) : animation = Hashtbl.find table id

let frames (id : id) : int = (get id).count

let point (id : id) (frame : int) (p : int) : float * float =
  let a = get id in
  if frame < 1 || frame > a.count || p < 1 || p > 20 then invalid_arg "Soldat_anims.point";
  let at = a.offset + ((((frame - 1) * 20) + (p - 1)) * 8) in
  (Int32.float_of_bits (String.get_int32_le bytes at), Int32.float_of_bits (String.get_int32_le bytes (at + 4)))

type playing = { id : id; frame : int; count : int }

let start (id : id) (frame : int) : playing = { id; frame; count = 0 }

let advance (p : playing) : playing =
  let a = get p.id in
  if p.count + 1 <> a.speed then { p with count = p.count + 1 }
  else if p.frame + 1 > a.count then { p with count = 0; frame = (if a.loop then 1 else a.count) }
  else { p with count = 0; frame = p.frame + 1 }

let ended (p : playing) : bool = p.frame = (get p.id).count

let gostek : Poa.skeleton =
  match Poa.skeleton ~scale:3. Anims_data.gostek with Ok s -> s | Error why -> failwith ("data/objects/gostek.po: " ^ why)
