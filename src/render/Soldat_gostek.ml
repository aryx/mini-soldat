(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *
 * Adapted from OpenSoldat's client/GostekGraphics.pas and
 * client/GostekGraphics.inc, Copyright 2001-2020 Transhuman Design,
 * Copyright 2020-2023 OpenSoldat contributors (the MIT License).
 *)

(* See Soldat_gostek.mli *)
open Playground

type colors = { shirt : int * int * int; trousers : int * int * int; skin : int * int * int }
type tint = Plain | Shirt | Trousers | Skin

type part = { name : string; image : string; from_ : int; to_ : int; cx : float; cy : float; left : string option; flex : float; tint : tint }

(*****************************************************************************)
(* The table *)
(*****************************************************************************)
(* GostekGraphics.inc's lines for what is drawn of a soldier today, in
 * its order; the gun's are mod.ini's *)

(* [flip]: Soldat's Flip, a second picture for facing left, the next
 * one in its list: a limb's is named with a 2 *)
let part name image from_ to_ cx cy flip flex tint : part =
  { name; image; from_; to_; cx; cy; left = (if flip then Some (image ^ "2") else None); flex; tint }

let left_foot = part "Left_Foot" "stopa" 2 18 0.35 0.35 true 0. Plain
let right_foot = part "Right_Foot" "stopa" 1 17 0.35 0.35 true 0. Plain
let head = part "Head" "morda" 9 12 0. 0.5 true 0. Skin

let parts : part list =
  [ part "Left_Thigh" "udo" 6 3 0.2 0.5 true 5. Trousers;
    left_foot;
    part "Left_Lowerleg" "noga" 3 2 0.15 0.55 true 0. Trousers;
    part "Left_Arm" "ramie" 11 14 0. 0.5 true 0. Shirt;
    part "Left_Forearm" "reka" 14 15 0. 0.5 false 5. Shirt;
    part "Left_Hand" "dlon" 15 19 0. 0.4 true 0. Skin;
    part "Right_Thigh" "udo" 5 4 0.2 0.65 true 5. Trousers;
    right_foot;
    part "Right_Lowerleg" "noga" 4 1 0.15 0.55 true 0. Trousers;
    part "Chest" "klata" 10 11 0.1 0.3 true 0. Shirt;
    part "Hip" "biodro" 5 6 0.25 0.6 true 0. Shirt;
    head;
    part "Helmet" "helm" 9 12 0. 0.5 true 0. Shirt;
    { (part "Primary_Socom" "colt1911" 16 15 0.2 0.55 true 0. Plain) with left = Some "colt1911-2" };
    part "Right_Arm" "ramie" 10 13 0. 0.6 true 0. Shirt;
    part "Right_Forearm" "reka" 13 16 0. 0.6 false 5. Shirt;
    part "Right_Hand" "dlon" 16 20 0. 0.5 true 0. Skin ]

(* what replaces a part: flying, the feet are the jets'; dead, the
 * head's pivot is its middle *)
let with_jets (p : part) : part =
  if p.name = "Left_Foot" || p.name = "Right_Foot" then { p with image = "lecistopa"; left = Some "lecistopa2" } else p
let when_dead (p : part) : part = if p.name = "Head" then { p with cx = 0.5 } else p

(*****************************************************************************)
(* The pictures *)
(*****************************************************************************)

(* as the build packed them (Gen_pictures): by name, their size and
 * their pixels *)
let pixels : (string, int * int * string) Hashtbl.t =
  let table = Hashtbl.create 64 in
  List.iter (fun (name, width, height, base64) -> Hashtbl.replace table name (width, height, Base64.decode base64)) Pictures_data.all;
  table

let find (name : string) : int * int * string =
  match Hashtbl.find_opt pixels name with Some p -> p | None -> failwith ("Soldat_gostek: no picture named " ^ name)

(* mod.ini's DefaultScale *)
let scale = 4.5

let size (name : string) : float * float =
  let (width, height, _) = find name in
  (float_of_int width /. scale, float_of_int height /. scale)

(* the pictures made so far: by name, the colour it is multiplied by,
 * and whether it is turned over. A picture is made once and the same
 * one given back after: a backend knows a picture by itself *)
let made : (string * (int * int * int) * bool, Rgba_image.t) Hashtbl.t = Hashtbl.create 64

let picture (name : string) ((r, g, b) : int * int * int) (turned_over : bool) : Rgba_image.t =
  match Hashtbl.find_opt made (name, (r, g, b), turned_over) with
  | Some image -> image
  | None ->
      let (width, height, bytes) = find name in
      let image = Rgba_image.create ~width ~height in
      for y = 0 to height - 1 do
        (* turned over: its rows from the bottom *)
        let from_y = if turned_over then height - 1 - y else y in
        for x = 0 to width - 1 do
          let at k = Char.code bytes.[(((from_y * width) + x) * 4) + k] in
          let to_ k v = Bigarray.Array1.set image.rgba ((((y * width) + x) * 4) + k) v in
          to_ 0 (at 0 * r / 255);
          to_ 1 (at 1 * g / 255);
          to_ 2 (at 2 * b / 255);
          to_ 3 (at 3)
        done
      done;
      Hashtbl.replace made (name, (r, g, b), turned_over) image;
      image

(*****************************************************************************)
(* Placing a part *)
(*****************************************************************************)

type placed = { x : float; y : float; width : float; height : float; angle : float; picture : string; turned_over : bool }

(* RenderGostek's loop and DrawGostekSprite's matrix: a point (lx, ly)
 * of the picture goes to
 *   (x1, y1 + 1) + turned by r (sx (lx - cx), sy (ly - cy))
 * and what is wanted here is where the picture's middle goes *)
let place (p : part) ((x1, y1) : float * float) ((x2, y2) : float * float) (direction : int) : placed =
  let facing_left = direction <> 1 in
  let (picture, cy, sy) =
    match p.left with
    | _ when not facing_left -> (p.image, p.cy, 1.)
    | Some second -> (second, 1. -. p.cy, 1.)
    | None -> (p.image, p.cy, -1.)
  in
  let sx = if p.flex > 0. then Float.min 1.5 (Float.hypot (x2 -. x1) (y2 -. y1) /. p.flex) else 1. in
  let (w, h) = size picture in
  let r = Float.atan2 (y2 -. y1) (x2 -. x1) in
  let ox = sx *. ((w /. 2.) -. (p.cx *. w)) and oy = sy *. ((h /. 2.) -. (cy *. h)) in
  let c = cos r and s = sin r in
  { x = x1 +. (ox *. c) -. (oy *. s); y = y1 +. 1. +. (ox *. s) +. (oy *. c); width = sx *. w; height = h; angle = r; picture; turned_over = sy < 0. }

(*****************************************************************************)
(* The soldier *)
(*****************************************************************************)

let view (colors : colors) ~(point : int -> float * float) ~(direction : int) ~(jets : bool) ~(dead : bool) : shape list =
  List.map
    (fun (p : part) ->
      let p = if jets then with_jets p else p in
      let p = if dead then when_dead p else p in
      let at = place p (point p.from_) (point p.to_) direction in
      let color = match p.tint with Plain -> (255, 255, 255) | Shirt -> colors.shirt | Trousers -> colors.trousers | Skin -> colors.skin in
      (* the picture's y goes up: its place and its angle the other way *)
      bitmap at.width at.height (picture at.picture color at.turned_over) |> rotate (-.at.angle *. 180. /. Float.pi) |> move at.x (-.at.y))
    parts
