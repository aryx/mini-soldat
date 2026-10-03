(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *
 * Adapted from OpenSoldat's shared/mechanics/Things.pas, Copyright
 * 2001-2020 Transhuman Design, Copyright 2020-2023 OpenSoldat
 * contributors (the MIT License).
 *)

(* See Soldat_fall.mli *)

let length ((ax, ay) : float * float) ((bx, by) : float * float) : float = Float.hypot (bx -. ax) (by -. ay)

let move ?(heard : Soldat_event.t list ref option) (map : Soldat_map.t) (thing : Soldat_things.t) : Soldat_things.t =
  let touched = ref 0 in
  (* it is heard as it first lands, and while it still bounces hard:
   * a weapon up to 30 times, a kit 3 *)
  let lands (p : Particles.particle) : unit =
    let often = match thing.kind with Weapon _ -> 30 | _ -> 3 in
    let n = thing.hits + !touched in
    if n = 0 || (length p.pos p.old > 1.5 && n < often) then
      Option.iter (fun l -> l := Soldat_event.Sound ((match thing.kind with Weapon _ -> Weapon_hit | Flag _ -> Flag_fall | _ -> Kit_fall), p.pos) :: !l) heard
  in
  let points =
    Array.map (fun p -> match Soldat_things.out_of_walls map p with Some p -> lands p; incr touched; p | None -> p) thing.points
    |> Particles.step ~drag:(1. -. fst (Soldat_things.physics thing.kind)) ~accel:(0., snd (Soldat_things.physics thing.kind) *. Soldat_soldier.grav) ~dt:1.
    |> Particles.relax ~iterations:1 (Soldat_things.sticks thing)
  in
  let moved i = length points.(i).pos points.(i).old in
  (* at rest: where it was is where it is *)
  if !touched >= 2 && (moved 0 +. moved 1) /. 2. < Soldat_things.min_move_delta then
    { thing with points = Array.map (fun (p : Particles.particle) -> { p with old = p.pos }) points; still = true }
  else { thing with points; hits = thing.hits + !touched }
