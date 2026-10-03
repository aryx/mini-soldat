(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *
 * Adapted from OpenSoldat's shared/mechanics/Sparks.pas and the
 * client's branches of Sprites.pas, Control.pas and Bullets.pas,
 * Copyright 2001-2020 Transhuman Design, Copyright 2020-2023
 * OpenSoldat contributors (the MIT License).
 *)

(* See Soldat_sparks.mli *)

(* with Soldat's style numbers: 1, 3, 4, 5, 55; 9 10 11 18 19 20 23;
 * 65 to 73, 51 and 52; 17, 12, 54, 60, 56; 26, 27, 35, 62 *)
type kind =
  | Smoke
  | Chip
  | Lil_blood
  | Blood
  | Splat
  | Clip of Soldat_weapons.id
  | Shell of Soldat_weapons.id
  | Explosion
  | Explosion_m79
  | Smoke_ring
  | Big_smoke
  | Mini_smoke
  | Spark
  | Spark_grey
  | Muzzle
  | Jet_fire

type t = { kind : kind; x : float; y : float; vx : float; vy : float; life : int; owner : int; hits : int }

(* SparkParts (shared/Anims.pas), SPARK_SURFACECOEF, EXPLOSION_ANIMS
 * and SMOKE_ANIMS *)
let gravity = Soldat_soldier.grav /. 1.4
let damping = 0.998
let surface = 0.7
let explosion_anims = 16
let smoke_anims = 10

(* NONEULER_STYLE: shown where they were made *)
let still (kind : kind) : bool = match kind with Explosion | Explosion_m79 | Smoke_ring | Big_smoke | Mini_smoke -> true | _ -> false

(* COLLIDABLE_STYLE *)
let meets_map (kind : kind) : bool = match kind with Lil_blood | Blood | Clip _ | Shell _ | Jet_fire -> true | _ -> false

(*****************************************************************************)
(* Made *)
(*****************************************************************************)

let of_event (map : Soldat_map.t) ~(random : unit -> float) ~(owner : int) (event : Soldat_event.t) : t list * (Soldat_sfx.t * (float * float)) list =
  (* Random(n) / 10 *)
  let tenths n = float_of_int (min (n - 1) (int_of_float (random () *. float_of_int n))) /. 10. in
  let one_in n = random () *. float_of_int n < 1. in
  let spark kind (x, y) (vx, vy) life : t = { kind; x; y; vx; vy; life; owner; hits = 0 } in
  match event with
  | Sound (sfx, at) -> ([], [ (sfx, at) ])
  | Shot { weapon; hand = (hx, hy); bullet = (bx, by); aim = (ax, ay); speed = (vx, vy); facing } ->
      let d = float_of_int facing in
      (* thrown across the way one aims *)
      let across () =
        let k = (random () *. 0.5) +. 0.8 in
        let k' = (random () *. 0.5) +. 0.8 in
        (vx +. (d *. ay *. k), vy -. (d *. ax *. k'))
      in
      let c = across () in
      let usual = (hx +. 2. -. (d *. 0.015 *. bx), hy -. 2. -. (d *. 0.015 *. by)) in
      let (at, shells) =
        match weapon with
        | Ak74 | Minimi | Ruger | Steyr | Barrett | Minigun -> (usual, [ (usual, c) ])
        | Mp5 | Socom ->
            let at = (hx +. 2. -. (0.2 *. bx), hy -. 2. -. (0.2 *. by)) in
            (at, [ (at, c) ])
        | Eagles ->
            let first = (hx +. 3. -. (0.17 *. bx), hy -. 2. -. (0.15 *. by)) in
            let second = (hx -. 3. -. (0.25 *. bx), hy -. 3. -. (0.3 *. by)) in
            (second, [ (first, c); (second, across ()) ])
        | _ -> (usual, [])
      in
      (* none out of a muzzle that is in a wall *)
      let shells = if Soldat_map.in_bullet_wall map usual then [] else List.map (fun (at, v) -> spark (Shell weapon) at v 255) shells in
      (shells @ [ spark Muzzle (fst at +. (bx *. 0.5), snd at +. (by *. 0.5)) (bx *. 0.1, by *. 0.1) 10 ], [])
  | Pumped { hand = (hx, hy); along = (_, ay); speed = (vx, vy); facing } ->
      let d = float_of_int facing in
      let speed = (Soldat_weapons.get Spas).speed in
      let bx = (d *. 0.025 *. ay *. speed) +. vx in
      let by = (-.d *. 0.025 *. bx) +. vy in
      ([ spark (Shell Spas) (hx +. 2. -. (d *. 0.015 *. bx), hy -. 2. -. (d *. 0.015 *. by)) (bx, by) 255 ], [])
  | Clip { weapon; hand = (hx, hy); speed = (vx, vy) } ->
      let kind = if weapon = M79 then Shell M79 else Clip weapon in
      (spark kind (hx, hy +. 6.) (vx, vy -. 0.001) 255 :: (if weapon = Eagles then [ spark kind (hx -. 2., hy +. 7.) (vx +. 0.3, vy -. 0.003) 255 ] else []), [])
  | Jets { feet = (f1, f2); legs = (l1, l2); speed } ->
      let foot (fx, fy) (lx, ly) =
        let at = (fx -. 1., fy +. 3.) in
        let smoke = if one_in 8 then [ spark Smoke at speed 75 ] else [] in
        let fire = if one_in 7 then [ spark Jet_fire at (lx *. -0.5, ly *. -0.5) 40 ] else [] in
        smoke @ fire
      in
      let first = foot f1 l1 in
      (first @ foot f2 l2, [])
  | Dust { at; speed = (vx, _); up } ->
      let k = 0.4 +. tenths 4 in
      ([ spark Smoke at (vx /. 4. *. k, -.up *. k) 70 ], [])
  | Wall ((px, py), (vx, vy)) ->
      (* thrown back from the wall, each a little its own way *)
      let at = (px +. vx, py +. vy) in
      let (bx, by) = (vx *. -0.06, (vy *. -0.06) -. 1.) in
      let bx = bx *. (0.6 +. tenths 8) in
      let by = by *. (0.8 +. tenths 4) in
      let first = spark Chip at (bx, by) 60 in
      let bx = bx *. (0.8 +. tenths 4) in
      let by = by *. (0.6 +. tenths 8) in
      let second = spark Chip at (bx, by) 65 in
      let k = 0.4 +. tenths 4 in
      let (bx, by) = (bx *. k, by *. k) in
      let smoke = spark Smoke at (bx, by) 60 in
      let bx = bx *. (0.5 +. tenths 4) in
      let by = by *. (0.7 +. tenths 8) in
      ([ first; second; smoke; spark Chip at (bx, by) 50; spark Mini_smoke at (0., 0.) 22 ], [ (Ric, (px, py)) ])
  | Ricochet ((px, py), (vx, vy)) ->
      let at = (px +. vx, py +. vy) in
      let any range =
        let x = -.range +. tenths (int_of_float (range *. 20.)) in
        let y = -.range +. tenths (int_of_float (range *. 20.)) in
        (x, y)
      in
      let two = [ spark Spark at (any 2.) 35; spark Spark at (any 2.) 35 ] in
      let three = [ spark Spark at (any 3.) 35; spark Spark at (any 3.) 35; spark Spark at (any 3.) 35 ] in
      (two @ three @ [ spark Spark_grey at (any 3.) 35 ], [ (Ricochet, (px, py)) ])
  | Blood (at, (vx, vy)) ->
      let (bx, by) = (vx *. 0.025 *. 1.2, vy *. 0.025 *. 0.85) in
      let a = spark Lil_blood at (bx, by) 70 in
      let (bx, by) = (bx *. 0.745, by *. 1.1) in
      let b = spark Lil_blood at (bx, by) 75 in
      let (bx, by) = (bx *. 0.9, by *. 0.85) in
      let c = if one_in 2 then [ spark Lil_blood at (bx, by) 75 ] else [] in
      let (bx, by) = (bx *. 1.2, by *. 0.85) in
      let d = spark Blood at (bx, by) 80 in
      let e = spark Blood at (bx, by) 85 in
      let (bx, by) = (bx *. 0.5, by *. 1.05) in
      let f = if one_in 2 then [ spark Blood at (bx, by) 75 ] else [] in
      (* and all around *)
      let around =
        List.init 7 Fun.id
        |> List.filter_map (fun _ ->
               if one_in 6 then begin
                 let angle = random () *. 100. in
                 Some (spark Lil_blood at (sin angle *. 1.6, cos angle *. 1.6) 55)
               end
               else None)
      in
      ([ a; b ] @ c @ [ d; e ] @ f @ around, [])
  | Flesh (at, (vx, vy)) ->
      let (bx, by) = (vx *. 0.075 *. 1.2, vy *. 0.075 *. 0.85) in
      let a = spark Lil_blood at (bx, by) 60 in
      let (bx, by) = (bx *. 0.745, by *. 1.1) in
      let b = spark Lil_blood at (bx, by) 65 in
      let (bx, by) = (bx *. 1.5, by *. 0.4) in
      ([ a; b; spark Blood at (bx, by) 70; spark Blood at (bx, by) 75 ], [])
  | Blast (weapon, at) ->
      let m79 = weapon = M79 || weapon = Law in
      ( [ spark Big_smoke at (0., 0.) (if m79 then 255 else 190);
          spark Smoke_ring at (0., 0.) ((smoke_anims * 4) + 10);
          spark (if m79 then Explosion_m79 else Explosion) at (0., 0.) (explosion_anims * 3) ],
        [ ((if m79 then M79_explosion else if weapon = Cluster then Cluster_explosion else Grenade_explosion), at) ] )

(*****************************************************************************)
(* A tick *)
(*****************************************************************************)

let normalize ((x, y) : float * float) : float * float =
  let len = Float.hypot x y in
  if len < 0.001 then (0., 0.) else (x /. len, y /. len)

(* what a spark bounces on (TSpark.CheckMapCollision) *)
let holds (kind : Pms.kind) : bool =
  match kind with
  | Normal | Ice | Deadly | Bloody_deadly | Hurts | Regenerates | Lava | Explodes | Hurts_flaggers | Only_flaggers | Not_flaggers | Non_flagger_collides -> true
  | Bouncy | Only_bullets | Only_players | No_collide | Team_bullets _ | Team_players _ | Background | Background_transition | Unknown _ -> false

let tick (map : Soldat_map.t) ~(random : unit -> float) (sparks : t list) : t list * (Soldat_sfx.t * (float * float)) list =
  let bound = (float_of_int map.num *. map.division) -. 10. in
  let made = ref [] and heard = ref [] in
  let one_in n = random () *. float_of_int n < 1. in
  let step (s : t) : t option =
    (* ParticleSystem.Euler *)
    let s =
      if still s.kind then s
      else
        let vy = s.vy +. gravity in
        { s with x = s.x +. s.vx; y = s.y +. vy; vx = s.vx *. damping; vy = vy *. damping }
    in
    if Float.abs s.x > bound || Float.abs s.y > bound then None
    else begin
      let pos = (s.x -. 8., s.y -. 1.) in
      let wall = if meets_map s.kind then List.find_opt (fun (w : Soldat_map.wall) -> holds w.kind && Soldat_map.in_edges pos w) (Soldat_map.sector map (fst pos) (snd pos)) else None in
      let s =
        match wall with
        | None -> Some s
        | Some w ->
            let (perp, depth, _) = Soldat_map.closest_perp w pos in
            let (nx, ny) = normalize perp in
            let (px, py) = (nx *. depth, ny *. depth) in
            let bounced = { s with vx = (s.vx -. px) *. surface; vy = (s.vy -. py) *. surface; hits = s.hits + 1 } in
            let at = (s.x, s.y) in
            let gone_after n = if s.hits > n then None else Some bounced in
            (match s.kind with
            | Jet_fire ->
                (* sparks off the ground *)
                if one_in 2 then begin
                  let jitter = float_of_int (min 10 (int_of_float (random () *. 11.))) /. 10. in
                  let kind = if one_in 2 then Spark else Spark_grey in
                  made := { kind; x = fst pos; y = snd pos; vx = (px *. 2.5) -. 0.5 +. jitter; vy = -.py *. 2.5; life = 35; owner = s.owner; hits = 0 } :: !made
                end;
                Some bounced
            | Lil_blood -> gone_after 1
            | Blood ->
                made := { s with kind = Splat; life = 30; hits = 0 } :: !made;
                gone_after 1
            | Shell weapon ->
                if weapon = Spas then heard := (Soldat_sfx.Gauge_shell, at) :: !heard
                else if s.hits = 0 || s.hits = 2 || s.hits = 4 then heard := (Soldat_sfx.Shell, at) :: !heard;
                gone_after 4
            | Clip _ ->
                if s.hits = 0 || s.hits = 4 then heard := (Soldat_sfx.Clip_fall, at) :: !heard;
                gone_after 4
            | _ -> Some bounced)
      in
      match s with Some s when s.life > 1 -> Some { s with life = s.life - 1 } | _ -> None
    end
  in
  let left = List.filter_map step sparks in
  (left @ List.rev !made, List.rev !heard)

(* r_maxsparks: when there are more, the oldest go. In a browser each
 * is an element of the page moved every frame, and 250 of them cost
 * a third of the frames: fewer there *)
let most = ref (if Soldat_assets.in_browser then 150 else 558)

let rec drop n l = if n <= 0 then l else match l with [] -> [] | _ :: rest -> drop (n - 1) rest

let capped (sparks : t list) : t list = drop (List.length sparks - !most) sparks

(* an explosion's fire in its first ticks: the camera thrown about, by
 * a sixth of what is left of its life *)
let wobble ~(random : unit -> float) (sparks : t list) : float * float =
  List.fold_left
    (fun (x, y) (s : t) ->
      match s.kind with
      | (Explosion | Explosion_m79) when float_of_int s.life > float_of_int explosion_anims *. 2.3 ->
          let w = s.life / 6 in
          let dx = Float.floor (random () *. float_of_int ((2 * w) + 1)) in
          let dy = Float.floor (random () *. float_of_int (2 * w)) in
          (x -. float_of_int w +. dx, y -. float_of_int w +. dy)
      | _ -> (x, y))
    (0., 0.) sparks
