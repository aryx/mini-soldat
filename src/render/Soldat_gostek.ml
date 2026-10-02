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
    part "Right_Arm" "ramie" 10 13 0. 0.6 true 0. Shirt;
    part "Right_Forearm" "reka" 13 16 0. 0.6 false 5. Shirt;
    part "Right_Hand" "dlon" 16 20 0. 0.5 true 0. Skin ]

(* the weapons' lines: a weapon's picture and its pivot in the hands
 * (from point 16 to 15), its muzzle's fire and its pivot, and its
 * pivot's height on the back (from 5 to 10; none: not shown there).
 * A picture's mirror is named with -2, its clip's -clip and -clip2 *)
type look = { image : string; cx : float; cy : float; clip : bool; fire : string; fire_cx : float; fire_cy : float; back : float option }

let look (id : Soldat_weapons.id) : look =
  let l image cx cy clip fire fire_cx fire_cy back = { image; cx; cy; clip; fire; fire_cx; fire_cy; back } in
  match id with
  | Eagles -> l "deserteagle" 0.1 0.8 true "eagles-fire" (-0.5) 1. None
  | Mp5 -> l "mp5" 0.15 0.6 true "mp5-fire" (-0.65) 0.85 (Some 0.3)
  | Ak74 -> l "ak74" 0.15 0.5 true "ak74-fire" (-0.37) 0.8 (Some 0.25)
  | Steyr -> l "steyraug" 0.2 0.6 true "steyraug-fire" (-0.24) 0.75 (Some 0.5)
  | Spas -> l "spas12" 0.1 0.6 false "spas12-fire" (-0.2) 0.9 (Some 0.3)
  | Ruger -> l "ruger77" 0.1 0.7 false "ruger77-fire" (-0.35) 0.85 (Some 0.3)
  | M79 -> l "m79" 0.1 0.7 false "m79-fire" (-0.4) 0.8 (Some 0.35)
  | Barrett -> l "barretm82" 0.15 0.7 true "barret-fire" (-0.15) 0.8 (Some 0.35)
  | Minimi -> l "m249" 0.15 0.6 true "m249-fire" (-0.2) 0.9 (Some 0.35)
  | Minigun -> l "minigun" 0.05 0.5 true "minigun-fire" (-0.2) 0.45 (Some 0.5)
  | Socom | Grenade | Hands -> l "colt1911" 0.2 0.55 true "colt1911-fire" (-0.24) 0.85 None

(* what is drawn of the weapon in the hands: [clip], its clip is in;
 * [fire], it fired this tick. Under the right arm, which holds it *)
let in_hands (id : Soldat_weapons.id) ~(clip : bool) ~(fire : bool) : part list =
  if id = Hands then [] else
  let k = look id in
  let mirrored name image cx cy = { (part name image 16 15 cx cy true 0. Plain) with left = Some (image ^ "-2") } in
  let gun = mirrored "Primary" k.image k.cx k.cy in
  let flash = if fire then [ part "Primary_Fire" k.fire 16 15 k.fire_cx k.fire_cy false 0. Plain ] else [] in
  if id = Minigun then
    (* its belt of bullets hangs from the waist, behind the gun *)
    (if clip then [ part "Primary_Clip" "minigun-clip" 8 7 0.5 0.1 false 0. Plain ] else []) @ [ gun ] @ flash
  else [ gun ] @ (if clip && k.clip then [ { (part "Primary_Clip" (k.image ^ "-clip") 16 15 k.cx k.cy true 0. Plain) with left = Some (k.image ^ "-clip2") } ] else []) @ flash

(* and of the one on the back: behind everything *)
let on_back (id : Soldat_weapons.id) : part list =
  let k = look id in
  match k.back with
  | None -> []
  | Some cy -> [ { (part "Secondary" k.image 5 10 (if id = Minigun then 0.2 else 0.3) cy true 0. Plain) with left = Some (k.image ^ "-2") } ]

(* what replaces a part: flying, the feet are the jets'; dead, the
 * head's pivot is its middle *)
let with_jets (p : part) : part =
  if p.name = "Left_Foot" || p.name = "Right_Foot" then { p with image = "lecistopa"; left = Some "lecistopa2" } else p
let when_dead (p : part) : part = if p.name = "Head" then { p with cx = 0.5 } else p

(*****************************************************************************)
(* The pictures *)
(*****************************************************************************)

(* as the build packed them (Gen_pictures): the soldier's own and its
 * pistol, by name *)
let packed : (string, Rgba_image.t) Hashtbl.t =
  let table = Hashtbl.create 64 in
  List.iter
    (fun (name, width, height, base64) ->
      let bytes = Base64.decode base64 in
      let image = Rgba_image.create ~width ~height in
      String.iteri (fun i c -> Bigarray.Array1.set image.rgba i (Char.code c)) bytes;
      Hashtbl.replace table name image)
    Pictures_data.all;
  table

(* a picture by its name: one the program carries, else a file of the
 * content's weapons-gfx/ (the other weapons): there or not, yet or
 * never *)
let source (name : string) : Rgba_image.t option =
  match Hashtbl.find_opt packed name with
  | Some image -> Some image
  | None -> ( match Soldat_assets.picture ~keyed:false "weapons-gfx" name with Here image -> Some image | Loading | Missing -> None)

let find (name : string) : Rgba_image.t =
  match source name with Some image -> image | None -> failwith ("Soldat_gostek: no picture named " ^ name)

(* mod.ini's DefaultScale *)
let scale = 4.5

let size (name : string) : float * float =
  let image = find name in
  (float_of_int image.width /. scale, float_of_int image.height /. scale)

(* the pictures made so far: by name, the colour it is multiplied by,
 * and whether it is turned over. A picture is made once and the same
 * one given back after: a backend knows a picture by itself *)
let made : (string * (int * int * int) * bool, Rgba_image.t) Hashtbl.t = Hashtbl.create 64

let picture (name : string) ((r, g, b) : int * int * int) (turned_over : bool) : Rgba_image.t =
  match Hashtbl.find_opt made (name, (r, g, b), turned_over) with
  | Some image -> image
  | None ->
      let from = find name in
      let (width, height) = (from.width, from.height) in
      let image = Rgba_image.create ~width ~height in
      for y = 0 to height - 1 do
        (* turned over: its rows from the bottom *)
        let from_y = if turned_over then height - 1 - y else y in
        for x = 0 to width - 1 do
          let at k = Bigarray.Array1.get from.rgba ((((from_y * width) + x) * 4) + k) in
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

let view ?(weapon : part list = []) ?(back : part list = []) (colors : colors) ~(point : int -> float * float) ~(direction : int) ~(jets : bool) ~(dead : bool) : shape list =
  (* the weapon goes under the right arm, the last three parts *)
  let body = List.length parts - 3 in
  let all = back @ List.filteri (fun i _ -> i < body) parts @ weapon @ List.filteri (fun i _ -> i >= body) parts in
  List.filter_map
    (fun (p : part) ->
      let p = if jets then with_jets p else p in
      let p = if dead then when_dead p else p in
      (* a weapon's picture not there (yet): it is not drawn *)
      let there name = source name <> None in
      if not (there p.image && match p.left with Some second -> there second | None -> true) then None
      else
        let at = place p (point p.from_) (point p.to_) direction in
        let color = match p.tint with Plain -> (255, 255, 255) | Shirt -> colors.shirt | Trousers -> colors.trousers | Skin -> colors.skin in
        (* the picture's y goes up: its place and its angle the other way *)
        Some (bitmap at.width at.height (picture at.picture color at.turned_over) |> rotate (-.at.angle *. 180. /. Float.pi) |> move at.x (-.at.y)))
    all

(* a weapon lying on the ground (TThing.Render): its picture's left
 * edge, 2 pixels under its top, at a point, turned along an angle
 * (radians, clockwise on the screen) *)
let lying (name : string) ((x, y) : float * float) (angle : float) : shape list =
  match source name with
  | None -> []
  | Some _ ->
      let (w, h) = size name in
      (* the middle, from the pivot (0, 2 pixels), at (x, y - 3) *)
      let (ox, oy) = (w /. 2., (h /. 2.) -. (2. /. scale)) in
      let c = cos angle and s = sin angle in
      let (mx, my) = (x +. (ox *. c) -. (oy *. s), y -. 3. +. (ox *. s) +. (oy *. c)) in
      [ bitmap w h (picture name (255, 255, 255) false) |> rotate (-.angle *. 180. /. Float.pi) |> move mx (-.my) ]

(* a picture of the content's weapons-gfx/ as it is, its middle at a
 * place of the game, turned by [angle] (radians, clockwise on the
 * screen): a grenade in flight *)
let loose (name : string) ((x, y) : float * float) (angle : float) : shape list =
  match source name with
  | None -> []
  | Some _ ->
      let (w, h) = size name in
      [ bitmap w h (picture name (255, 255, 255) false) |> rotate (-.angle *. 180. /. Float.pi) |> move x (-.y) ]
