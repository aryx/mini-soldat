(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *
 * Adapted from OpenSoldat's client/Sound.pas, Copyright 2002-2003
 * Michal Marcinkowski, Copyright 2020-2023 OpenSoldat contributors
 * (the MIT License).
 *)

(* See Soldat_sound.mli *)

let mute = ref false

(* SOUND_MAXDIST and SOUND_PANWIDTH (shared/Constants.pas) *)
let max_dist = 750.
let pan_width = 1000.

(* the most started in a tick: each is mixed anew, its loudness and
 * its side its own, which a browser does more slowly *)
let most = if Soldat_assets.in_browser then 5 else 12

(*****************************************************************************)
(* The files *)
(*****************************************************************************)

let u16 (s : string) (i : int) : int = Char.code s.[i] lor (Char.code s.[i + 1] lsl 8)
let u32 (s : string) (i : int) : int = u16 s i lor (u16 s (i + 2) lsl 16)

(* a RIFF file's chunks, walked for "fmt " and "data" *)
let to_16_bit (wav : string) : string =
  let n = String.length wav in
  let rec chunks i fmt data =
    if i + 8 > n then (fmt, data)
    else
      let name = String.sub wav i 4 and size = u32 wav (i + 4) in
      let size = min size (n - i - 8) in
      let body = String.sub wav (i + 8) size in
      let next = i + 8 + size + (size land 1) in
      if name = "fmt " then chunks next (Some body) data else if name = "data" then chunks next fmt (Some body) else chunks next fmt data
  in
  if n < 12 || String.sub wav 0 4 <> "RIFF" then wav
  else
    match chunks 12 None None with
    | (Some fmt, Some data) when String.length fmt >= 16 && u16 fmt 14 = 8 ->
        let channels = u16 fmt 2 and rate = u32 fmt 4 in
        let out = Buffer.create ((2 * String.length data) + 44) in
        let add16 v = Buffer.add_char out (Char.chr (v land 255)); Buffer.add_char out (Char.chr ((v lsr 8) land 255)) in
        let add32 v = add16 (v land 0xffff); add16 ((v lsr 16) land 0xffff) in
        Buffer.add_string out "RIFF";
        add32 (36 + (2 * String.length data));
        Buffer.add_string out "WAVEfmt ";
        add32 16; add16 1; add16 channels; add32 rate; add32 (rate * channels * 2); add16 (channels * 2); add16 16;
        Buffer.add_string out "data";
        add32 (2 * String.length data);
        (* 8-bit samples are 0 to 255 around 128; 16-bit ones signed *)
        String.iter (fun c -> add16 (((Char.code c - 128) * 256) land 0xffff)) data;
        Buffer.contents out
    | _ -> wav

(* the recordings got so far, by their file's name; None: there is none *)
let sounds : (string, Audio.sound option) Hashtbl.t = Hashtbl.create 64

let sound (name : string) : Audio.sound option =
  match Hashtbl.find_opt sounds name with
  | Some known -> known
  | None -> (
      match Soldat_assets.bytes ("sfx/" ^ name ^ ".wav") with
      | Loading -> None
      | Missing ->
          Hashtbl.replace sounds name None;
          None
      | Here bytes ->
          (* frozen: its samples made once, not at each play *)
          let s = Some (Audio.recorded (Audio.wav (to_16_bit bytes))) in
          Hashtbl.replace sounds name s;
          s)

(* In a browser, making a sound louder and to a side each time it is
 * played is too slow (the whole recording is computed again: 2.6 ms
 * for an explosion natively, ten times that there), where playing a
 * recording as it is costs nothing. So there a recording is kept at
 * four loudnesses, each made the first time it is wanted, and played
 * from the middle: no left and right *)
let levels = [| 1.; 0.7; 0.45; 0.25 |]

let at_level : (string * int, Audio.sound) Hashtbl.t = Hashtbl.create 64

let leveled (name : string) (s : Audio.sound) (volume : float) : Audio.sound =
  (* the nearest of the four *)
  let level = ref 0 in
  Array.iteri (fun i l -> if Float.abs (l -. volume) < Float.abs (levels.(!level) -. volume) then level := i) levels;
  if !level = 0 then s
  else
    match Hashtbl.find_opt at_level (name, !level) with
    | Some made -> made
    | None ->
        let made = Audio.recorded (s |> Audio.louder levels.(!level)) in
        Hashtbl.replace at_level (name, !level) made;
        made

(* a recording at a loudness, from a side *)
let start (name : string) (s : Audio.sound) ~(volume : float) ~(pan : float) : unit =
  if Soldat_assets.in_browser then Audio.play (leveled name s volume) else Audio.play (s |> Audio.louder volume |> Audio.pan pan)

(*****************************************************************************)
(* Played *)
(*****************************************************************************)

(* the sound's layer (docs/twins.md): 0 silence; 1 every sound as loud;
 * 2 the Playground's Space; 3 Soldat's *)
let level = ref 3

let heard ~(listener : float * float) ((x, y) : float * float) : (float * float) option =
  let (dx, dy) = (x -. fst listener, y -. snd listener) in
  let d = Float.hypot dx dy /. max_dist in
  match !level with
  | 0 -> None
  | 1 -> Some (1., 0.)
  | 2 ->
      (* the twin: full within 100 units then as their inverse
       * (Space.attenuation), and the sine of its angle from straight
       * ahead for a listener looking into the screen (Space.direction) *)
      let volume = Space.attenuation ~reference:100. (Float.hypot dx dy) in
      Some (volume, Space.direction ~listener:(Space.vec 0. 0. (-300.)) ~right:(Space.vec 1. 0. 0.) (Space.vec dx dy 0.))
  | _ -> if d > 1. then None else Some (1. -. d, dx /. Float.hypot dx pan_width)

(* what is heard of it from far, in its place and besides *)
let distant (sfx : Soldat_sfx.t) : Soldat_sfx.t option =
  match sfx with Fire id when id <> M79 -> Some Dist_gun | Grenade_explosion -> Some Dist_grenade | M79_explosion -> Some Dist_m79 | _ -> None

let play ~(listener : float * float) ~(frame : int) (sounds : (Soldat_sfx.t * (float * float)) list) : unit =
  if not !mute then begin
    (* each with how loud it is and its pan; a far one's rumble too *)
    let all =
      List.concat (List.mapi
        (fun i (sfx, ((x, y) as at)) ->
          let (dx, dy) = (x -. fst listener, y -. snd listener) in
          let d = Float.hypot dx dy /. max_dist in
          let pan = dx /. Float.hypot dx pan_width in
          let far =
            match distant sfx with
            | Some rumble when d > 0.5 && !level = 3 ->
                (* louder up to the sound's own reach, fading over as much again *)
                let d' = if d > 1. then d -. 1. else 1. -. (2. *. d) in
                if d' > 1. then [] else [ (Float.min 1. (1. -. d'), pan, Soldat_sfx.file rumble (frame + i)) ]
            | _ -> []
          in
          (match heard ~listener at with Some (volume, pan) -> [ (volume, pan, Soldat_sfx.file sfx (frame + i)) ] | None -> []) @ far)
        sounds)
    in
    List.sort (fun (a, _, _) (b, _, _) -> compare b a) all
    |> List.filteri (fun i (volume, _, _) -> i < most && volume > 0.02)
    |> List.iter (fun (volume, pan, name) ->
           match sound name with Some s -> start name s ~volume ~pan | None -> ())
  end

(* ask for the recordings ahead, a few at each call (each is read and
 * brought to the mixer's rate once, a moment's work): how many have
 * not come yet *)
let warm () : int =
  let budget = ref 3 in
  List.fold_left
    (fun waiting name ->
      if Hashtbl.mem sounds name then waiting
      else if !budget = 0 then waiting + 1
      else begin
        decr budget;
        match sound name with Some _ -> waiting | None -> if Hashtbl.mem sounds name then waiting else waiting + 1
      end)
    0
    (List.sort_uniq compare Soldat_sfx.files)

(* which soldiers' jets are sounding: by their number *)
let flying : (int, unit) Hashtbl.t = Hashtbl.create 8

let jets ~(listener : float * float) ~(soldiers : int) (now : (int * (float * float)) list) : unit =
  if not !mute then
    for i = 0 to soldiers - 1 do
      let name = "jets" ^ string_of_int i in
      match (List.assoc_opt i now, Hashtbl.mem flying i) with
      | (Some at, false) -> (
          match (heard ~listener at, sound (Soldat_sfx.file Rocketz 0)) with
          | (Some (volume, pan), Some s) ->
              Audio.loop name (s |> Audio.louder volume |> Audio.pan pan);
              Hashtbl.replace flying i ()
          | _ -> ())
      | (None, true) ->
          Audio.stop name;
          Hashtbl.remove flying i
      | _ -> ()
    done
