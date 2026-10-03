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

(* See Soldat_tumble.mli *)

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
  match pushed (x -. 1., y +. 4.) (fun kind -> Soldat_map.stops_soldier kind) p with
  | None -> p
  | Some p ->
      let any (kind : Pms.kind) = kind <> No_collide && kind <> Only_bullets in
      Option.value (pushed (x, y +. 1.) any p) ~default:p

let tick ?(heard : Soldat_event.t list ref option) (map : Soldat_map.t) (ragdoll : Soldat_ragdoll.t) : Soldat_ragdoll.t =
  let falls = ref ragdoll.falls in
  let points =
    ragdoll.points
    |> Array.mapi (fun i p ->
           let n = i + 1 in
           if n = 7 || n = 8 || n >= 17 then p
           else begin
             let out = out_of_walls map p in
             (* pushed out of a wall: a body's fall, a bone's crack (S:3011) *)
             if out != p then begin
               let dy = Float.abs (snd out.pos -. snd out.old) in
               let say sfx = Option.iter (fun l -> l := Soldat_event.Sound (sfx, out.pos) :: !l) heard in
               if dy > 0.8 && !falls < 13 then say Bodyfall;
               if dy > 2.1 && !falls < 4 then say Bonecrack;
               incr falls
             end;
             out
           end)
    |> Particles.step ~drag:(1. -. 0.9945) ~accel:(0., 1.06 *. Soldat_soldier.grav) ~dt:1.
    |> Particles.relax ~iterations:1 (Soldat_ragdoll.holding ragdoll)
  in
  { ragdoll with points; falls = !falls }
