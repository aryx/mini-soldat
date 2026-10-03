(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *
 * Adapted from OpenSoldat's shared/mechanics/Sparks.pas (TSpark.Render),
 * Copyright 2001-2020 Transhuman Design, Copyright 2020-2023
 * OpenSoldat contributors (the MIT License).
 *)

(* See Soldat_sparks_view.mli *)
open Playground

(* mod.ini's DefaultScale: a picture's pixels a unit *)
let scale = 4.5

(* a picture of a folder, multiplied by a colour: made once *)
let tinted : (string * string * (int * int * int), Rgba_image.t) Hashtbl.t = Hashtbl.create 16

let picture ?(tint = (255, 255, 255)) (folder : string) (name : string) : Rgba_image.t option =
  match Soldat_assets.picture ~keyed:false folder name with
  | Loading | Missing -> None
  | Here image when tint = (255, 255, 255) -> Some image
  | Here image -> (
      match Hashtbl.find_opt tinted (folder, name, tint) with
      | Some made -> Some made
      | None ->
          let (r, g, b) = tint in
          let made = Rgba_image.create ~width:image.width ~height:image.height in
          for i = 0 to (image.width * image.height) - 1 do
            let at k = Bigarray.Array1.get image.rgba ((i * 4) + k) in
            let to_ k v = Bigarray.Array1.set made.rgba ((i * 4) + k) v in
            to_ 0 (at 0 * r / 255); to_ 1 (at 1 * g / 255); to_ 2 (at 2 * b / 255); to_ 3 (at 3)
          done;
          Hashtbl.replace tinted (folder, name, tint) made;
          Some made)

(* a weapon's name in its files' *)
let shell (id : Soldat_weapons.id) : string =
  match id with
  | Eagles -> "eagles-shell"
  | Mp5 -> "mp5-shell"
  | Ak74 -> "ak74-shell"
  | Steyr -> "steyraug-shell"
  | Spas -> "spas12-shell"
  | Ruger -> "ruger77-shell"
  | M79 -> "m79-shell"
  | Barrett -> "barretm82-shell"
  | Minimi -> "m249-shell"
  | Minigun -> "minigun-shell"
  | Socom | Grenade | Hands | Bow | Bow2 -> "colt-shell"

(* GfxDrawSprite: a picture whose top left corner is at a place of the
 * game, [w] by [h] units, turned by [turn] radians, faded to [alpha]
 * of 255 *)
let draw ?(turn = 0.) (image : Rgba_image.t) ((x, y) : float * float) ((w, h) : float * float) (alpha : float) : shape =
  let a = Float.max 0. (Float.min 1. (alpha /. 255.)) in
  bitmap w h image |> rotate (-.turn *. 180. /. Float.pi) |> fade a |> move (x +. (w /. 2.)) (-.(y +. (h /. 2.)))

(* its own size, times [k] *)
let sized ?(k = 1.) (image : Rgba_image.t) (w : int) (h : int) : float * float =
  ignore image;
  (float_of_int w /. scale *. k, float_of_int h /. scale *. k)

let degrees (d : float) : float = d *. Float.pi /. 180.

let spark (s : Soldat_sparks.t) : shape list =
  let l = float_of_int s.life in
  let at = (s.x, s.y) in
  let one ?tint ?turn ?(k = 1.) ?(at = at) folder name (w, h) alpha =
    match picture ?tint folder name with Some image -> [ draw ?turn image at (sized ~k image w h) alpha ] | None -> []
  in
  let fx = "sparks-gfx" in
  match s.kind with
  | Smoke -> one fx "smoke" (18, 18) (l +. 10.)
  | Chip -> one fx "odprysk" (5, 5) ((l *. 3.) +. 10.)
  | Lil_blood -> one fx "lilblood" (9, 9) ~k:0.75 ~turn:(degrees (l *. 10.)) ((l *. 2.) +. 65.)
  | Blood -> one fx "blood" (41, 41) ~k:(if l > 10. then 0.33 +. (10. /. l) else 1.) ~turn:(degrees (l *. 2.)) ((l *. 2.) +. 85.)
  | Splat -> one fx "splat" (54, 36) ~k:(if l > 20. then 0.63 +. (10. /. l) else 1.) ~turn:(degrees l) (Float.min 255. ((l *. 2.) +. 55.))
  | Clip weapon ->
      let name = (Soldat_gostek.look weapon).image ^ "-clip" in
      (match picture "weapons-gfx" name with
      | Some image -> [ draw ~turn:Float.pi image (s.x +. 8., s.y) (float_of_int image.width /. scale, float_of_int image.height /. scale) 255. ]
      | None -> [])
  | Shell weapon -> (
      match picture "weapons-gfx" (shell weapon) with
      | Some image -> [ draw ~turn:(degrees (l *. 4.)) image at (float_of_int image.width /. scale, float_of_int image.height /. scale) 255. ]
      | None -> [])
  | Explosion | Explosion_m79 ->
      (* 16 pictures in turn, the one before under it *)
      let (k, (ox, oy)) = if s.kind = Explosion then (1., (25., 50.)) else (0.75, (19., 38.)) in
      let i = 16 - int_of_float (Float.round (l /. 4.)) in
      let frame n alpha = if n >= 1 && n <= 16 then one fx (Printf.sprintf "explosion/explode%d" n) (320, 450) ~k ~at:(s.x -. ox, s.y -. oy) alpha else [] in
      frame (i - 1) 100. @ frame i (255. -. 80. +. l)
  | Smoke_ring ->
      if l > 40. then []
      else
        let i = 11 - int_of_float (Float.round (l /. 4.)) in
        let frame n alpha = if n >= 1 && n <= 10 then one fx (Printf.sprintf "explosion/smoke%d" n) (302, 302) ~at:(s.x -. 26., s.y -. 48.) alpha else [] in
        frame (i - 1) ((2. *. l) +. 10.) @ frame i ((3. *. l) +. 10.)
  | Big_smoke ->
      let k = 0.5 +. (16. /. (l +. 50.)) in
      let at = (s.x -. (14. *. k), s.y -. 30.) in
      one fx "bigsmoke" (288, 324) ~k ~at (l /. 3.3) @ one fx "bigsmoke2" (288, 324) ~k ~at (if l > 30. then (255. -. l) /. 9. else l)
  | Mini_smoke -> one fx "minismoke" (27, 32) ~at:(s.x -. 3., s.y -. 3.) (2.5 *. l)
  | Spark -> one fx "odprysk" (5, 5) ~tint:(0xFF, 0xFE, 0x35) (Float.min 255. ((l *. 3.) +. 154.))
  | Spark_grey -> one fx "odprysk" (5, 5) ~tint:(0xAA, 0xAA, 0xAA) (Float.min 255. ((l *. 3.) +. 154.))
  | Muzzle -> one fx "lilsmoke" (14, 14) (l *. 13.)
  | Jet_fire -> one fx "jetfire" (23, 23) ~turn:(degrees l) (l *. 5.)

let view (sparks : Soldat_sparks.t list) : shape list = List.concat_map spark sparks

let warm () : int =
  let fx = "sparks-gfx" in
  let names =
    [ "smoke"; "odprysk"; "lilblood"; "blood"; "splat"; "lilsmoke"; "minismoke"; "jetfire"; "bigsmoke"; "bigsmoke2" ]
    @ List.init 16 (fun i -> Printf.sprintf "explosion/explode%d" (i + 1))
    @ List.init 10 (fun i -> Printf.sprintf "explosion/smoke%d" (i + 1))
  in
  List.length (List.filter (fun name -> Soldat_assets.picture ~keyed:false fx name = Loading) names)
