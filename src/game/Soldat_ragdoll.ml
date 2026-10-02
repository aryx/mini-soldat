(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *
 * Adapted from OpenSoldat's shared/mechanics/Sprites.pas and
 * shared/Parts.pas, Copyright 2001-2020 Transhuman Design, Copyright
 * 2020-2023 OpenSoldat contributors (the MIT License).
 *)
(* A dead soldier: its own skeleton, let loose.
 *
 * Alive, a soldier's 20 points are put where its animations say
 * (Soldat_soldier). Dead, they are particles joined by the gostek's
 * sticks (Jakobsen's particles and sticks: elm-playground's Particles),
 * falling, tumbling and lying on the map. The speed each starts with is
 * what its last living tick left it: where it was a tick before.
 *
 * A tick, in Soldat's order (TSprite.Update, S:747 and S:1371): each
 * point but the waist, the toes and the hands' ends is taken out of
 * the walls (CheckSkeletonMapCollision: back where it was, less its
 * depth along the nearest edge's perp); then Soldat's Verlet step,
 * which is Particles.step with a drag of 1 - VDamping (0.9945) and a
 * gravity of 1.06 times the game's; then the sticks, once
 * (SatisfyConstraints: Particles.relax, one iteration).
 *
 * Not yet: a head or a leg off on a hard hit (a stick cut), the chain
 * and the hair (points 21 to 24).
 *)

type t = Particles.particle array

(* the gostek's sticks between its first 20 points (28 of its 30), as
 * Particles has them: from 0 *)
let sticks : Particles.stick list =
  Array.to_list Soldat_anims.gostek.sticks
  |> List.filter_map (fun (a, b, length) -> if a <= 20 && b <= 20 then Some { Particles.a = a - 1; b = b - 1; length } else None)

(* the skeleton of a soldier that just died; [hit] is the point a
 * bullet struck, if one did, and the push it gave *)
let of_soldier (s : Soldat_soldier.t) (hit : (int * (float * float)) option) : t =
  Array.mapi
    (fun i pos ->
      let (ox, oy) = s.old_skeleton.(i) in
      let old = match hit with Some (p, (kx, ky)) when p = i + 1 -> (ox -. kx, oy -. ky) | _ -> (ox, oy) in
      { (Particles.particle pos) with old })
    s.skeleton

(* Vec2Normalize *)
let normalize ((x, y) : float * float) : float * float =
  let len = Float.hypot x y in
  if len < 0.001 then (0., 0.) else (x /. len, y /. len)

(* CheckSkeletonMapCollision (S:2958) *)
let out_of_walls (map : Soldat_map.t) (p : Particles.particle) : Particles.particle =
  let (x, y) = p.pos in
  let pushed (probe : float * float) (stops : Pms.kind -> bool) (p : Particles.particle) : Particles.particle option =
    List.fold_left
      (fun acc (w : Soldat_map.wall) ->
        if stops w.kind && Soldat_map.in_edges probe w then begin
          let (perp, depth, _) = Soldat_map.closest_perp w probe in
          let (nx, ny) = normalize perp in
          Some { p with pos = (fst p.old -. (nx *. depth), snd p.old -. (ny *. depth)) }
        end
        else acc)
      None
      (Soldat_map.sector map (fst probe) (snd probe))
  in
  match pushed (x -. 1., y +. 4.) Soldat_map.stops_soldier p with
  | None -> p
  | Some p ->
      let any (kind : Pms.kind) = kind <> No_collide && kind <> Only_bullets in
      Option.value (pushed (x, y +. 1.) any p) ~default:p

let tick (map : Soldat_map.t) (ragdoll : t) : t =
  ragdoll
  |> Array.mapi (fun i p ->
         let n = i + 1 in
         if n = 7 || n = 8 || n >= 17 then p else out_of_walls map p)
  |> Particles.step ~drag:(1. -. 0.9945) ~accel:(0., 1.06 *. Soldat_soldier.grav) ~dt:1.
  |> Particles.relax ~iterations:1 sticks
