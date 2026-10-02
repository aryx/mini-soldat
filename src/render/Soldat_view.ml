(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* The picture of a frame: the map, the soldiers (or their ragdolls),
 * the bullets, grenades and blasts, the score. All of it the
 * Playground's shapes in flat colours for now; the flag hitboxes draws
 * what the physics sees.
 *
 * In Soldat: client/GameRendering.pas, over MapGraphics.pas (the
 * map's textured triangles and its scenery), GostekGraphics.pas (a
 * soldier's sprites, one per limb, on its skeleton) and
 * InterfaceGraphics.pas (the health and jets' bars, the score, the
 * cursor).
 *)
open Playground
open Basics (* float arithmetics *)
open Soldat_model (* its types, used all along *)

let text (color : color) (size : number) (s : string) : shape = words color s |> scale size

let segment (color : color) (width : number) ((x1, y1) : number * number) ((x2, y2) : number * number) : shape =
  rectangle color (Float.hypot (x2 - x1) (y2 - y1)) width
  |> rotate (degrees (x2 - x1) (y2 - y1))
  |> move ((x1 + x2) / 2.) ((y1 + y2) / 2.)

let bar (color : color) (width : number) (fraction : number) (x : number) (y : number) : shape list =
  [ rectangle (rgb 40 40 40) width 4. |> move x y; rectangle color (width * max 0. fraction) 4. |> move (x - (width * (1. - max 0. fraction) / 2.)) y ]

let view_soldier (s : soldier) (b : Physics.body) : shape list =
  match s.dead with
  | Some (_, ps) ->
      List.map (fun (st : Particles.stick) -> segment s.color 4. ps.(st.a).pos ps.(st.b).pos) Soldat_ragdoll.bones
      @ [ circle s.color 7. |> move (fst ps.(0).pos) (snd ps.(0).pos) ]
  | None ->
      (* the legs swing as it runs *)
      let swing = 25. * sin (b.x / 12.) in
      let leg angle = rectangle s.color 6. 20. |> move_y (-10.) |> rotate angle |> move b.x (b.y - 8.) in
      [ leg swing; leg (-.swing);
        rectangle s.color 18. 24. |> move b.x (b.y + 4.);
        circle s.color 8. |> move b.x (b.y + 22.);
        rectangle (rgb 40 40 40) 26. 4. |> move_x 13. |> rotate s.aim |> move b.x (b.y + 10.) ]
      @ bar (rgb 220 60 60) 30. (s.health / 100.) b.x (b.y + 38.)
      @ bar (rgb 240 200 60) 30. (s.fuel / 100.) b.x (b.y + 33.)

(* the map alone, seen from where the first soldier will appear: what
 * is behind a title *)
let view_map (computer : computer) (map : Soldat_map.t) : shape =
  Camera2d.view (camera_at computer.screen map (spawn map 0)) (map.back @ map.front)

(* through the camera, in Soldat's order: what is behind, the soldiers
 * and what flies, then the map's polygons over them; over it all and
 * not moving with the map, the score *)
let view_play (computer : computer) (p : play) : shape list =
  let n_soldiers = 3 in
  let top = computer.screen.top in
  Camera2d.view p.camera
    (p.map.back
    @ List.concat (List.mapi (fun i s -> view_soldier s (body_of p i)) (Array.to_list p.soldiers))
    @ List.map (fun bl -> Physics.draw bl.b) p.bullets
    @ List.mapi (fun k _ -> Physics.draw (List.nth p.world.bodies (p.n_map +.. n_soldiers +.. k))) p.grenades
    @ List.map (fun bl -> circle orange (10. + (float_of_int bl.age * 7.)) |> fade (1. - (float_of_int bl.age / 20.)) |> move bl.x bl.y) p.blasts
    @ p.map.front
    @ if List.mem_assoc "hitboxes" computer.flags then List.map Physics.debug p.world.bodies else [])
  :: List.mapi
       (fun i s ->
         text s.color 2.5 (Printf.sprintf "%s %d" s.name s.kills) |> move (-300. + (300. * float_of_int i)) (top - 40.))
       (Array.to_list p.soldiers)
  @ (if p.soldiers.(0).dead <> None then [ text white 3. "respawning..." |> move_y (top - 120.) ] else [])

let view (computer : computer) (model : model) : shape list =
  match model.scene with
  | Title map ->
      [ view_map computer map;
        text white 6. "MINI SOLDAT" |> move_y 300.;
        text white 2. "a/d run   w jump, hold w in the air: jets" |> move_y 200.;
        text white 2. "mouse aim   click or space shoot   q grenade" |> move_y 160.;
        text white 2. "you against two bots: first to 5 kills" |> move_y 120.;
        text white 2. map.name |> move_y 40. ]
      @ Scene2d.blink 1. model [ text white 3. "PRESS SPACE" |> move_y (-50.) ]
  | Playing p -> view_play computer p
  | Over (name, map) ->
      [ view_map computer map; text white 5. (if name = "YOU" then "YOU WIN!" else name ^ " WINS") |> move_y 200. ]
      @ Scene2d.blink 1. model [ text white 3. "PRESS SPACE" |> move_y (-50.) ]
