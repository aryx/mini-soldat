(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* The picture of a tick: the map, the soldiers, the bullets, the
 * score.
 *
 * The game is in Soldat's coordinates, y downwards; the Playground's y
 * goes up. Here, and only here, a point (x, y) of the game is drawn at
 * (x, -y) ([at]), through a camera that shows 640 units across, as
 * Soldat does.
 *
 * A soldier is drawn as its skeleton's own sticks, the gostek's, in
 * its colour: enough to see how it moves. Its pictures (a sprite on
 * each limb) are docs/plan.md's step 2. The flag hitboxes shows what
 * the game tests: the particle, the points of the head and the feet,
 * the circles a bullet hits.
 *
 * In Soldat: client/GameRendering.pas, whose order this follows (what
 * is behind, the bullets, the soldiers, then the map's polygons over
 * them), over MapGraphics.pas, GostekGraphics.pas and
 * InterfaceGraphics.pas.
 *)
open Playground
open Basics (* float arithmetics *)
open Soldat_model (* its types, used all along *)

(* a point of the game, in the picture *)
let at ((x, y) : float * float) : float * float = (x, -.y)

let text (color : color) (size : number) (s : string) : shape = words color s |> scale size

(* a line from a to b, points of the game *)
let segment (color : color) (width : number) (a : float * float) (b : float * float) : shape =
  let (x1, y1) = at a and (x2, y2) = at b in
  rectangle color (Float.hypot (x2 - x1) (y2 - y1)) width
  |> rotate (Float.atan2 (y2 - y1) (x2 - x1) * 180. / Float.pi)
  |> move ((x1 + x2) / 2.) ((y1 + y2) / 2.)

let dot (color : color) (radius : number) (p : float * float) : shape =
  let (x, y) = at p in
  circle color radius |> move x y

let bar (color : color) (width : number) (fraction : number) ((x, y) : float * float) : shape list =
  let fraction = Float.max 0. (Float.min 1. fraction) in
  [ rectangle (rgb 40 40 40) width 1.5 |> move x y; rectangle color (width * fraction) 1.5 |> move (x - (width * (1. - fraction) / 2.)) y ]

(* the skeleton's sticks, and a head *)
let figure (color : color) (points : (float * float) array) : shape list =
  List.map (fun (st : Particles.stick) -> segment color 1.6 points.(st.a) points.(st.b)) Soldat_ragdoll.sticks @ [ dot color 2.6 points.(11) ]

let view_soldier (map : Soldat_map.t) (s : soldier) : shape list =
  match s.dead with
  | Some (_, ragdoll) -> figure s.color (Array.map (fun (p : Particles.particle) -> p.pos) ragdoll)
  | None ->
      let b = s.body in
      (* the gun: from the hand towards the cursor *)
      let (hx, hy) = Soldat_soldier.point b 15 in
      let d = Float.hypot (b.aim_x - hx) (b.aim_y - hy) in
      let gun = if d < 1. then [] else [ segment (rgb 30 30 30) 1.4 (hx, hy) (hx + ((b.aim_x - hx) / d * 9.), hy + ((b.aim_y - hy) / d * 9.)) ] in
      let over = at (b.x, b.y - 30.) in
      figure s.color b.skeleton @ gun
      @ bar (rgb 220 60 60) 16. (s.health / full_health) over
      @ bar (rgb 240 200 60) 16. (float_of_int b.jets / float_of_int (max 1 map.jet)) (fst over, snd over - 2.5)

(* what the game tests, over a soldier *)
let view_tested (s : soldier) : shape list =
  if s.dead <> None then []
  else
    let b = s.body in
    List.map (fun p -> dot (rgb 255 255 255) 7. (Soldat_soldier.point b p) |> fade 0.25) Soldat_update.hit_points
    @ List.map (dot (rgb 255 0 255) 0.8) [ (b.x, b.y); (b.x - 3.5, b.y - 12.); (b.x + 3.5, b.y - 12.); (b.x + 2., b.y + 2.); (b.x - 2., b.y + 2.) ]

(* the map alone, seen from where the first soldier will appear: what
 * is behind a title *)
let view_map (computer : computer) (map : Soldat_map.t) : shape =
  let (x, y) = at (spawn map 0) in
  Camera2d.view { x; y; zoom = zoom computer.screen; angle = 0. } (map.back @ map.front)

(* through the camera, in Soldat's order: what is behind, the bullets,
 * the soldiers, then the map's polygons over them; over it all and
 * not moving with the map, the score *)
let view_play (computer : computer) (p : play) : shape list =
  let top = computer.screen.top in
  let (x, y) = at p.camera in
  let soldiers = Array.to_list p.soldiers in
  Camera2d.view
    { x; y; zoom = zoom computer.screen; angle = 0. }
    (p.map.back
    @ List.map (fun (b : bullet) -> segment (rgb 250 230 120) 0.8 (b.x, b.y) (b.x - (b.vx * 0.6), b.y - (b.vy * 0.6))) p.bullets
    @ List.concat_map (view_soldier p.map) soldiers
    @ p.map.front
    @ if List.mem_assoc "hitboxes" computer.flags then List.concat_map view_tested soldiers else [])
  :: List.mapi (fun i s -> text s.color 2.5 (Printf.sprintf "%s %d" s.name s.kills) |> move (-300. + (300. * float_of_int i)) (top - 40.)) soldiers
  @ (if p.soldiers.(0).dead <> None then [ text white 3. "respawning..." |> move_y (top - 120.) ] else [])

let view (computer : computer) (model : model) : shape list =
  match model.scene with
  | Title map ->
      [ view_map computer map;
        text white 6. "MINI SOLDAT" |> move_y 300.;
        text white 2. "a/d run   w jump   s crouch   x lie down" |> move_y 200.;
        text white 2. "mouse aim   left button shoot   right button (or shift) jets" |> move_y 160.;
        text white 2. "you against two bots: first to 5 kills" |> move_y 120.;
        text white 2. map.name |> move_y 40. ]
      @ Scene2d.blink 1. model [ text white 3. "PRESS SPACE" |> move_y (-50.) ]
  | Playing p -> view_play computer p
  | Over (name, map) ->
      [ view_map computer map; text white 5. (if name = "YOU" then "YOU WIN!" else name ^ " WINS") |> move_y 200. ]
      @ Scene2d.blink 1. model [ text white 3. "PRESS SPACE" |> move_y (-50.) ]
