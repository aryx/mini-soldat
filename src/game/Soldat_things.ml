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

(* See Soldat_things.mli *)

type kind = Weapon of Soldat_soldier.gun | Medikit | Grenade_kit

type t = { kind : kind; points : Particles.particle array; ttl : int; interest : int; still : bool; facing : int; place : int; hits : int }

(* shared/Constants.pas *)
let gun_time = 1200
let flag_timeout = 1500
let default_interest = 350
let gun_radius = 10.
let kit_radius = 12.
let min_move_delta = 0.63
let spawn_random = 25.
let max_grenades = 2

(*****************************************************************************)
(* Their shapes *)
(*****************************************************************************)

(* objects/karabin.po, two points 4 apart, at the scale CreateThing
 * gives each weapon (RifleSkeleton10 to 55); with its VDamping and its
 * GravityMultiplier *)
let rifle (id : Soldat_weapons.id) : float * float * float =
  match id with
  | Socom | Grenade | Hands -> (1.0, 0.994, 1.05)
  | Eagles -> (1.1, 0.996, 1.09)
  | Mp5 -> (2.2, 0.995, 1.11)
  | Ak74 | Steyr -> (3.7, 0.994, 1.16)
  | Spas -> (3.6, 0.993, 1.15)
  | Ruger -> (3.6, 0.993, 1.13)
  | M79 -> (2.8, 0.994, 1.15)
  | Barrett -> (4.3, 0.993, 1.18)
  | Minimi -> (3.9, 0.993, 1.2)
  | Minigun -> (5.5, 0.991, 1.4)

(* objects/kit.po at its scale of 2.15: a box, its first point at the
 * bottom right (a .po's x is turned over and divided by 1.2) *)
let box : (float * float) array =
  let w = 5. *. 2.15 /. 1.2 and h = 4. *. 2.15 in
  [| (0., 0.); (-.w, 0.); (-.w, -.h); (0., -.h) |]

let length ((ax, ay) : float * float) ((bx, by) : float * float) : float = Float.hypot (bx -. ax) (by -. ay)

let sticks (thing : t) : Particles.stick list =
  match thing.kind with
  | Weapon g ->
      let (scale, _, _) = rifle g.kind.id in
      [ { a = 1; b = 0; length = 4. *. scale } ]
  | Medikit | Grenade_kit ->
      let l a b : Particles.stick = { a; b; length = length box.(a) box.(b) } in
      [ l 3 2; l 2 1; l 1 0; l 0 3; l 3 1; l 2 0 ]

(* VDamping and GravityMultiplier *)
let physics (kind : kind) : float * float =
  match kind with
  | Weapon g ->
      let (_, damping, weight) = rifle g.kind.id in
      (damping, weight)
  | Medikit -> (0.989, 1.05)
  | Grenade_kit -> (0.989, 1.07)

let radius (kind : kind) : float = match kind with Weapon _ -> gun_radius | Medikit | Grenade_kit -> kit_radius

(*****************************************************************************)
(* Made *)
(*****************************************************************************)

let normalize ((x, y) : float * float) : float * float =
  let len = Float.hypot x y in
  if len < 0.001 then (0., 0.) else (x /. len, y /. len)

(* DropWeapon and CreateThing's throw: at the hand, its points moved
 * while where they were stays: that is their speed *)
let weapon (s : Soldat_soldier.t) ~(alive : bool) (g : Soldat_soldier.gun) : t =
  let (scale, _, _) = rifle g.kind.id in
  let (hx, hy) = Soldat_soldier.point s 16 in
  let (ax, ay) = let (px, py) = Soldat_soldier.point s 15 in normalize (s.aim_x -. px, s.aim_y -. py) in
  let (first, second) = if alive then (0.01, 3.) else (0.02, 0.64) in
  let point (dy : float) (throw : float) : Particles.particle =
    let old = (hx, hy +. dy) in
    { (Particles.particle (fst old +. s.vx +. (ax *. throw), snd old +. s.vy +. (ay *. throw))) with old }
  in
  { kind = Weapon g; points = [| point (2. *. scale) first; point (-2. *. scale) second |]; ttl = gun_time; interest = 0; still = false; facing = s.direction; place = -1; hits = 0 }

let kit_at (kind : kind) ((x, y) : float * float) (place : int) : t =
  { kind; points = Array.map (fun (bx, by) -> Particles.particle (x +. bx, y +. by)) box; ttl = flag_timeout; interest = default_interest; still = false; facing = 1; place; hits = 0 }

let places (map : Soldat_map.t) (kind : kind) : (float * float) list =
  match kind with Medikit -> map.medikit_spawns | Grenade_kit -> map.grenade_spawns | Weapon _ -> []

(* Random(n): a whole number from 0 to n - 1 *)
let pick ~(random : unit -> float) (n : int) : int = if n <= 0 then 0 else min (n - 1) (int_of_float (random () *. float_of_int n))

(* a place of the map for this kind, not [but] if there is another
 * (SpawnBoxes): its number, and a point within 4 of it *)
let somewhere (map : Soldat_map.t) ~(random : unit -> float) (kind : kind) ~(but : int) : (int * (float * float)) option =
  let all = List.mapi (fun i p -> (i, p)) (places map kind) in
  let others = List.filter (fun (i, _) -> i <> but) all in
  match if others = [] then all else others with
  | [] -> None
  | choice ->
      let (i, (x, y)) = List.nth choice (pick ~random (List.length choice)) in
      let dx = float_of_int (pick ~random 8) in
      let dy = float_of_int (pick ~random 4) in
      Some (i, (x -. 4. +. dx, y -. 4. +. dy))

let kits (map : Soldat_map.t) ~(random : unit -> float) : t list =
  let some (kind : kind) (count : int) : t list =
    List.init count Fun.id
    |> List.filter_map (fun _ ->
           match somewhere map ~random kind ~but:(-1) with
           | None -> None
           | Some (place, (x, y)) ->
               let jitter () = -.spawn_random +. (float_of_int (pick ~random (int_of_float (200. *. spawn_random))) /. 100.) in
               let x = x +. jitter () in
               let y = y +. jitter () in
               Some (kit_at kind (x, y) place))
  in
  let medikits = some Medikit map.medikits in
  medikits @ some Grenade_kit map.grenade_kits

let again (map : Soldat_map.t) ~(random : unit -> float) (thing : t) : t =
  match somewhere map ~random thing.kind ~but:thing.place with Some (place, at) -> kit_at thing.kind at place | None -> thing

(*****************************************************************************)
(* A tick *)
(*****************************************************************************)

(* what a thing lies on (TThing.CheckMapCollision): not what stops
 * only bullets, only players or only some of them *)
let holds (kind : Pms.kind) : bool =
  match kind with
  | Normal | Ice | Deadly | Bloody_deadly | Hurts | Regenerates | Lava | Bouncy | Explodes | Hurts_flaggers | Non_flagger_collides -> true
  | Only_bullets | Only_players | No_collide | Only_flaggers | Not_flaggers | Team_bullets _ | Team_players _ | Background | Background_transition
  | Unknown _ ->
      false

(* a point in a wall: back where it was, less its depth along the perp *)
let out_of_walls (map : Soldat_map.t) (p : Particles.particle) : Particles.particle option =
  let pos = (fst p.pos, snd p.pos -. 0.5) in
  List.fold_left
    (fun acc (w : Soldat_map.wall) ->
      if holds w.kind && Soldat_map.in_edges pos w then begin
        let (perp, depth, _) = Soldat_map.closest_perp w pos in
        let (nx, ny) = normalize perp in
        let (p : Particles.particle) = Option.value acc ~default:p in
        Some { p with pos = (fst p.old -. (nx *. depth), snd p.old -. (ny *. depth)) }
      end
      else acc)
    None
    (Soldat_map.sector map (fst pos) (snd pos))

let lost (map : Soldat_map.t) (thing : t) : bool =
  let bound = (float_of_int map.num *. map.division) -. 10. in
  Array.exists (fun (p : Particles.particle) -> Float.abs (fst p.pos) > bound || Float.abs (snd p.pos) > bound) thing.points

let tick ?(heard : Soldat_event.t list ref option) (map : Soldat_map.t) (thing : t) : t option =
  let thing =
    if thing.still then thing
    else begin
      let touched = ref 0 in
      (* it is heard as it first lands, and while it still bounces hard:
       * a weapon up to 30 times, a kit 3 *)
      let lands (p : Particles.particle) : unit =
        let often = match thing.kind with Weapon _ -> 30 | Medikit | Grenade_kit -> 3 in
        let n = thing.hits + !touched in
        if n = 0 || (length p.pos p.old > 1.5 && n < often) then
          Option.iter (fun l -> l := Soldat_event.Sound ((match thing.kind with Weapon _ -> Weapon_hit | Medikit | Grenade_kit -> Kit_fall), p.pos) :: !l) heard
      in
      let points =
        Array.map (fun p -> match out_of_walls map p with Some p -> lands p; incr touched; p | None -> p) thing.points
        |> Particles.step ~drag:(1. -. fst (physics thing.kind)) ~accel:(0., snd (physics thing.kind) *. Soldat_soldier.grav) ~dt:1.
        |> Particles.relax ~iterations:1 (sticks thing)
      in
      let moved i = length points.(i).pos points.(i).old in
      (* at rest: where it was is where it is *)
      if !touched >= 2 && (moved 0 +. moved 1) /. 2. < min_move_delta then
        { thing with points = Array.map (fun (p : Particles.particle) -> { p with old = p.pos }) points; still = true }
      else { thing with points; hits = thing.hits + !touched }
    end
  in
  let ttl = max (-1000) (thing.ttl - 1) in
  match thing.kind with
  | Weapon _ when ttl = 0 || lost map thing -> None
  | _ -> Some { thing with ttl }

(*****************************************************************************)
(* Reached *)
(*****************************************************************************)

let middle (thing : t) : float * float =
  let (ax, ay) = thing.points.(0).pos and (bx, by) = thing.points.(1).pos in
  ((ax +. bx) /. 2., (ay +. by) /. 2.)

let reach (thing : t) (at : float * float) : float option =
  let r = radius thing.kind in
  let d = length at (middle thing) in
  let d = if d >= r then length at thing.points.(0).pos else d in
  let d = if d >= r then length at thing.points.(1).pos else d in
  if d < r then Some d else None
