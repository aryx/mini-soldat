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
 * A hard hit takes a limb off: a stick of the skeleton is *cut*, and
 * what hung by it goes its own way. Which, by the health the hit left
 * (TSprite.Die, S:1975-2034), the sticks by their numbers in
 * gostek.po:
 *
 *     under 1      dead, whole
 *     -90 or less  a hit in the head cuts 20 (the head from the neck);
 *                  in a knee, 2 or 4 (that thigh from the hip)
 *     -400         both thighs, the head, and both arms (21 and 23,
 *                  from the shoulders)
 *
 * A pistol's bullet takes 30: no. The Barrett's takes 245 of 150, to
 * -95: in the head, the head off. An explosion strikes no point in
 * particular, so it is all or nothing: 1500 / (d + 1) reaches 550
 * only within 1.7 units -- a grenade that hits one in the head, not
 * one that lands near; or the M79's, which adds its own blow to its
 * blast. And a body already dead is still hit, and loses what the
 * living one kept.
 *
 * An explosion throws the dead about (ExplosionHit): each point within
 * its radius is given a speed away from it, 4.5 x d / (d + 1), d its
 * distance, so 4.5 units a tick at most.
 *
 * Not yet: the chain and the hair (points 21 to 24).
 *)

type t = {
  points : Particles.particle array;
  (* the sticks cut, by Soldat's numbers *)
  cut : int list;
  (* times its points have met the map: its fall is heard the first 13
   * (DeadCollideCount) *)
  falls : int;
}

(* the gostek's sticks between its first 20 points (28 of its 30), as
 * Particles has them, from 0; each with its number in the file, from 1 *)
let numbered : (int * Particles.stick) list =
  Array.to_list Soldat_anims.gostek.sticks
  |> List.mapi (fun i (a, b, length) -> if a <= 20 && b <= 20 then Some (i + 1, { Particles.a = a - 1; b = b - 1; length }) else None)
  |> List.filter_map Fun.id

let sticks : Particles.stick list = List.map snd numbered

(* those that still hold *)
let holding (ragdoll : t) : Particles.stick list = List.filter_map (fun (n, stick) -> if List.mem n ragdoll.cut then None else Some stick) numbered

(* the skeleton of a soldier that just died. [push] is what pushed it
 * in its last tick, a bullet or a blast: in Soldat a push is felt a
 * tick or more before the death the network brings, and the body
 * leaves with it; here both are in the same tick, and the push is
 * given to the skeleton *)
let of_soldier (s : Soldat_soldier.t) ~(push : float * float) : t =
  let (px, py) = push in
  { points = Array.mapi (fun i pos -> let (ox, oy) = s.old_skeleton.(i) in { (Particles.particle pos) with old = (ox -. px, oy -. py) }) s.skeleton; cut = []; falls = 0 }

(* BRUTALDEATHHEALTH and HEADCHOPDEATHHEALTH (shared/Constants.pas) *)
let brutal_health = -400.
let headchop_health = -90.

(* the sticks a hit cuts: [health] is what it left, [where] the point
 * of the skeleton it struck (an explosion: 1) *)
let cuts ~(health : float) ~(where : int) : int list =
  if health <= brutal_health then [ 2; 4; 20; 21; 23 ]
  else if health <= headchop_health then (match where with 12 -> [ 20 ] | 3 -> [ 2 ] | 4 -> [ 4 ] | _ -> [])
  else []

let cut (numbers : int list) (ragdoll : t) : t = { ragdoll with cut = List.sort_uniq compare (numbers @ ragdoll.cut) }

(* EXPLOSION_DEADIMPACT_MULTIPLY *)
let dead_impact = 4.5

(* an explosion at a place: its first 16 points within [radius] thrown
 * away from it. With the distance of the last one thrown, if any
 * (what the blast then takes of the body's health goes by it) *)
let blast (ragdoll : t) ~(at : float * float) ~(radius : float) : t * float option =
  let last = ref None in
  let points =
    Array.mapi
      (fun i (p : Particles.particle) ->
        let (dx, dy) = (fst at -. fst p.pos, snd at -. snd p.pos) in
        let d = Float.hypot dx dy in
        if i < 16 && d < radius then begin
          last := Some d;
          let k = 1. /. (d +. 1.) *. dead_impact in
          { p with old = (fst p.old +. (dx *. k), snd p.old +. (dy *. k)) }
        end
        else p)
      ragdoll.points
  in
  ({ ragdoll with points }, !last)

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

let tick ?(heard : Soldat_event.t list ref option) (map : Soldat_map.t) (ragdoll : t) : t =
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
    |> Particles.relax ~iterations:1 (holding ragdoll)
  in
  { ragdoll with points; falls = !falls }
