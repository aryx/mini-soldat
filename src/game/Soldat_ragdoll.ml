(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* A dead soldier: Jakobsen's particles and sticks (Particles, the
 * Hitman technique), 9 particles, a stick figure falling, tumbling and
 * lying on the map's walls (Particles.keep_out).
 *
 * In Soldat the living soldier is such a skeleton too (the "gostek":
 * shared/Parts.pas's ParticleSystem, its points and sticks read from
 * objects/gostek.po), posed by its animations (shared/Anims.pas, the
 * .poa files) and let loose when it dies.
 *)
open Playground
open Basics (* float arithmetics *)

(* a stick figure: head, neck, hip, the knees and feet, the hands *)
let figure = [ (0., 18.); (0., 10.); (0., -8.); (-5., -16.); (-7., -24.); (5., -16.); (7., -24.); (-10., 0.); (10., 0.) ]
let bones : Particles.stick list =
  List.map
    (fun (a, b) -> { Particles.a; b; length = Vec2.length (Vec2.sub (List.nth figure b) (List.nth figure a)) })
    [ (0, 1); (1, 2); (2, 3); (3, 4); (2, 5); (5, 6); (1, 7); (1, 8); (0, 2) ]

(* the figure where the soldier fell, moving as it moved plus the hit's
 * push: its old positions a tick back along that velocity *)
let ragdoll (b : Physics.body) ((kx, ky) : number * number) : Particles.particle array =
  let (vx, vy) = (b.vx + kx, b.vy + ky) in
  Array.of_list
    (List.mapi
       (fun i (x, y) ->
         (* the head flies a bit faster: the figure starts tumbling *)
         let spin = if i = 0 then 1.5 else 1. in
         let pos = (b.x + x, b.y + y) in
         { (Particles.particle pos) with old = (fst pos - (vx * spin / 60.), snd pos - (vy / 60.)) })
       figure)

let move (map : Soldat_map.t) (ps : Particles.particle array) : Particles.particle array =
  ps
  |> Particles.step ~drag:0.01 ~accel:(0., -.Soldat_map.gravity) ~dt:(1. / 60.)
  |> Particles.relax ~iterations:5 bones
  |> Particles.keep_out map.walls
