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
 * shared/mechanics/Control.pas, Copyright 2001-2020 Transhuman Design,
 * Copyright 2020-2023 OpenSoldat contributors (the MIT License).
 *)

(* See Soldat_soldier.mli. The Pascal is followed in its order, with
 * where each part comes from: S is Sprites.pas, C is Control.pas (line
 * numbers of OpenSoldat's develop, bf43a43). A tick changes a copy of
 * the soldier in place, as the Pascal changes Sprite[i]: its fields are
 * mutable, and nothing outside [tick] writes to them. *)

type stance = Standing | Crouching | Lying

type control = {
  left : bool;
  right : bool;
  up : bool;
  down : bool;
  jetpack : bool;
  prone : bool;
  aim : float * float;
}

let no_control : control = { left = false; right = false; up = false; down = false; jetpack = false; prone = false; aim = (0., 0.) }

type t = {
  (* the particle: where it is, its speed, what pushes it until the next
   * step, where it was *)
  mutable x : float;
  mutable y : float;
  mutable vx : float;
  mutable vy : float;
  mutable fx : float;
  mutable fy : float;
  mutable old_x : float;
  mutable old_y : float;
  mutable direction : int;
  mutable old_direction : int;
  mutable stance : stance;
  mutable legs : Soldat_anims.playing;
  mutable body : Soldat_anims.playing;
  mutable on_ground : bool;
  mutable on_ground_last : bool;
  mutable on_ground_permanent : bool;
  mutable jets : int;
  mutable aim_x : float;
  mutable aim_y : float;
  mutable skeleton : (float * float) array;
  mutable old_skeleton : (float * float) array;
  (* a player holding left and right at once: what it was doing before *)
  mutable was_running_left : bool;
  mutable was_jumping : bool;
}

(*****************************************************************************)
(* Soldat's numbers *)
(*****************************************************************************)
(* shared/Constants.pas, shared/Game.pas, and the top of Sprites.pas *)

let grav = 0.06
let runspeed = 0.118
let runspeedup = runspeed /. 6.
let flyspeed = 0.03
let jumpspeed = 0.66
let crouchrunspeed = runspeed /. 0.6
let pronespeed = runspeed *. 4.0
let rollspeed = runspeed /. 1.2
let jumpdirspeed = 0.30
let jetspeed = 0.10
let surfacecoefx = 0.970
let surfacecoefy = 0.970
let crouchmovesurfacecoefx = 0.850
let crouchmovesurfacecoefy = 0.970
let standsurfacecoefx = 0.000
let standsurfacecoefy = 0.000
let slidelimit = 0.2
let max_velocity = 11.
let sprite_col_radius = 3.

(* SpriteParts.EDamping (shared/Anims.pas) *)
let damping = 0.99

(* Vec2Normalize: nothing of a vector too short to have a direction *)
let normalize ((x, y) : float * float) : float * float =
  let len = Float.hypot x y in
  if len < 0.001 then (0., 0.) else (x /. len, y /. len)

(*****************************************************************************)
(* The skeleton *)
(*****************************************************************************)

(* how far above the feet the body's animation hangs (S:562-586) *)
let body_y (s : t) : float =
  let y =
    match s.stance with
    | Standing -> 8.
    | Crouching -> 9.
    | Lying ->
        if s.body.id = Prone_move then 0.
        else if s.body.id = Prone then if s.body.frame > 9 then -2. else float_of_int (14 - s.body.frame)
        else 9.
  in
  if s.body.id = Get_up then if s.body.frame > 18 then 8. else 4. else y

let is_leg (p : int) : bool = p <= 6 || p = 17 || p = 18

(* the 20 points where the two animations put them (S:600-633): the
 * legs' from the particle, the rest hung from the hip (point 6) *)
let place_skeleton (s : t) : (float * float) array =
  let d = float_of_int s.direction in
  let legs p = let (x, y) = Soldat_anims.point s.legs.id s.legs.frame p in (s.x +. (d *. x), s.y +. y) in
  let (_, hip_y) = legs 6 in
  let by = body_y s in
  Array.init 20 (fun i ->
      let p = i + 1 in
      if is_leg p then legs p
      else
        let (x, y) = Soldat_anims.point s.body.id s.body.frame p in
        (s.x +. (d *. x), hip_y -. (s.y -. by) +. s.y +. y))

let create ((x, y) : float * float) (jets : int) : t =
  let s =
    {
      x; y; vx = 0.; vy = 0.; fx = 0.; fy = 0.; old_x = x; old_y = y;
      direction = 1; old_direction = 1;
      stance = Standing;
      legs = Soldat_anims.start Stand 1;
      body = Soldat_anims.start Stand 1;
      on_ground = false; on_ground_last = false; on_ground_permanent = false;
      jets;
      aim_x = x; aim_y = y;
      skeleton = [||]; old_skeleton = [||];
      was_running_left = false; was_jumping = false;
    }
  in
  s.skeleton <- place_skeleton s;
  s.old_skeleton <- s.skeleton;
  s

let point (s : t) (p : int) : float * float = s.skeleton.(p - 1)

(*****************************************************************************)
(* The particle's step *)
(*****************************************************************************)

(* ParticleSystem.Euler (shared/Parts.pas), with a mass and a time step
 * of 1 *)
let euler (s : t) : unit =
  s.fy <- s.fy +. grav;
  s.old_x <- s.x;
  s.old_y <- s.y;
  s.vx <- s.vx +. s.fx;
  s.vy <- s.vy +. s.fy;
  s.x <- s.x +. s.vx;
  s.y <- s.y +. s.vy;
  s.vx <- s.vx *. damping;
  s.vy <- s.vy *. damping;
  s.fx <- 0.;
  s.fy <- 0.

(*****************************************************************************)
(* The animations *)
(*****************************************************************************)

(* LegsApplyAnimation (S:2445): to another animation only, and never
 * out of lying *)
let legs_apply (s : t) (id : Soldat_anims.id) (frame : int) : unit =
  if s.legs.id <> Prone && s.legs.id <> Prone_move && id <> s.legs.id then s.legs <- Soldat_anims.start id frame

(* BodyApplyAnimation (S:2460) *)
let body_apply (s : t) (id : Soldat_anims.id) (frame : int) : unit = if id <> s.body.id then s.body <- Soldat_anims.start id frame

(*****************************************************************************)
(* The keys *)
(*****************************************************************************)

(* ControlSprite, what of it moves a soldier. What it gives back is the
 * keys as it took them: never left and right at once *)
let control (s : t) (c : control) : control =
  (* left and right at once (C:176-202): in a jump the old way goes on,
   * else the new one wins *)
  let pressed_left_right = c.left && c.right in
  let (left, right) =
    if pressed_left_right then
      if s.was_jumping then if s.was_running_left then (true, false) else (false, true)
      else if s.was_running_left then (false, true)
      else (true, false)
    else begin
      s.was_running_left <- c.left;
      s.was_jumping <- c.up;
      (c.left, c.right)
    end
  in
  let up = c.up and down = c.down in
  let prone = ref c.prone in
  (* the aim leads by the speed (C:343-344) *)
  s.aim_x <- Float.round (Float.round (fst c.aim) +. s.vx);
  s.aim_y <- Float.round (Float.round (snd c.aim) +. s.vy);
  let d = float_of_int s.direction in
  (* the jets, and the backflip that takes their key (C:350-424) *)
  if
    c.jetpack
    && ((s.legs.id = Jump_side && ((s.direction = -1 && right) || (s.direction = 1 && left) || pressed_left_right))
       || (s.legs.id = Roll_back && up))
  then begin
    body_apply s Roll_back 1;
    legs_apply s Roll_back 1
  end
  else if c.jetpack && s.jets > 0 then begin
    if s.on_ground then s.fy <- -2.5 *. jetspeed
    else if s.stance <> Lying then s.fy <- s.fy -. jetspeed
    else s.fx <- s.fx +. (d *. jetspeed /. 2.);
    if s.legs.id <> Get_up && s.body.id <> Roll && s.body.id <> Roll_back then legs_apply s Fall 1;
    s.jets <- s.jets - 1
  end;
  (* going prone (C:863-882) *)
  if !prone && s.legs.id <> Get_up && s.legs.id <> Prone && s.legs.id <> Prone_move then begin
    legs_apply s Prone 1;
    body_apply s Prone 1;
    s.old_direction <- s.direction;
    prone := false
  end;
  (* getting up: the key again, or turning round (C:885-905) *)
  if s.stance = Lying && (!prone || s.direction <> s.old_direction) && ((s.legs.id = Prone && s.legs.frame > 23) || s.legs.id = Prone_move) then begin
    if s.legs.id <> Get_up then begin
      s.legs <- Soldat_anims.start Get_up 9;
      prone := false
    end;
    body_apply s Get_up 9
  end;
  (* the end of getting up is a jump's wind-up (C:907-955) *)
  let unprone =
    if s.legs.id = Get_up && s.legs.frame > 20 && s.on_ground && up && (right || left) then begin
      legs_apply s Jump_side (s.legs.frame - 20);
      true
    end
    else if s.legs.id = Get_up && s.legs.frame > 20 && s.on_ground && up then begin
      legs_apply s Jump (s.legs.frame - 15);
      true
    end
    else if s.legs.id = Get_up && s.legs.frame > 23 then begin
      if right || left then if (s.direction = 1) <> left then legs_apply s Run 1 else legs_apply s Run_back 1
      else if (not s.on_ground) && up then legs_apply s Run 1
      else legs_apply s Stand 1;
      true
    end
    else false
  in
  if unprone then begin
    s.stance <- Standing;
    body_apply s Stand 1
  end;
  (* the keys as animations and forces, the first case that holds
   * (C:1621-2024) *)
  let roll_on_ground (legs : Soldat_anims.id) : bool =
    legs = Run || legs = Run_back || legs = Fall || legs = Prone_move || (s.legs.id = Prone && s.legs.frame >= 24)
  in
  (* down and a side on the ground: a roll, forwards when [forwards],
   * or a crouched walk; [way] is 1 to the right, -1 to the left *)
  let down_and_side (way : float) (forwards : bool) : unit =
    if s.on_ground then begin
      if roll_on_ground s.legs.id then begin
        if s.legs.id = Prone_move || (s.legs.id = Prone && Soldat_anims.ended s.legs) then begin
          prone := false;
          s.stance <- Standing
        end;
        let roll : Soldat_anims.id = if forwards then Roll else Roll_back in
        body_apply s roll 1;
        s.legs <- Soldat_anims.start roll 1
      end
      else legs_apply s (if forwards then Crouch_run else Crouch_run_back) 1;
      if s.legs.id = Crouch_run || s.legs.id = Crouch_run_back then s.fx <- way *. crouchrunspeed
      else if s.legs.id = Roll || s.legs.id = Roll_back then s.fx <- way *. 2. *. crouchrunspeed
    end
  in
  (* up and a side: a jump sideways *)
  let up_and_side (way : float) (facing : bool) : unit =
    if s.on_ground then begin
      (match s.legs.id with Run | Run_back | Stand | Crouch | Crouch_run | Crouch_run_back -> legs_apply s Jump_side 1 | _ -> ());
      if Soldat_anims.ended s.legs then legs_apply s Run 1
    end
    else if s.legs.id = Roll || s.legs.id = Roll_back then legs_apply s (if facing then Run else Run_back) 1;
    if s.legs.id = Jump && s.legs.frame < 10 then legs_apply s Jump_side 1;
    if s.legs.id = Jump_side && s.legs.frame > 3 && s.legs.frame < 11 then begin
      s.fx <- way *. jumpdirspeed;
      s.fy <- -.jumpdirspeed /. 1.2
    end
  in
  if s.body.id = Roll || s.body.id = Roll_back then begin
    if s.legs.id = Roll then s.fx <- (if s.on_ground then d *. rollspeed else d *. 2. *. flyspeed)
    else if s.legs.id = Roll_back then begin
      s.fx <- (if s.on_ground then -.d *. rollspeed else -.d *. 2. *. flyspeed);
      (* the backflip's lift *)
      if s.legs.frame > 1 && s.legs.frame < 8 && up then begin
        s.fy <- s.fy -. (jumpdirspeed *. 1.5);
        s.fx <- s.fx *. 0.5;
        s.vx <- s.vx *. 0.8
      end
    end
  end
  else if right && down then down_and_side 1. (s.direction = 1)
  else if left && down then down_and_side (-1.) (s.direction = -1)
  else if s.legs.id = Prone || s.legs.id = Prone_move || s.legs.id = Get_up then begin
    (* lying: a crawl, in pulses, or still *)
    if s.on_ground && ((s.legs.id = Prone && s.legs.frame > 25) || s.legs.id = Prone_move) then
      if left || right then begin
        if s.legs.frame < 4 || s.legs.frame > 14 then s.fx <- (if left then -.pronespeed else pronespeed);
        legs_apply s Prone_move 1;
        body_apply s Prone_move 1;
        if s.legs.id <> Prone_move then s.legs <- Soldat_anims.start Prone_move 1
      end
      else s.legs <- { (if s.legs.id <> Prone then Soldat_anims.start Prone 1 else s.legs) with frame = 26 }
  end
  else if right && up then up_and_side 1. (s.direction = 1)
  else if left && up then up_and_side (-1.) (s.direction = -1)
  else if up then begin
    if s.on_ground then begin
      if s.legs.id <> Jump then legs_apply s Jump 1;
      if Soldat_anims.ended s.legs then legs_apply s Stand 1
    end;
    if s.legs.id = Jump then begin
      (* the force of a jump, while its animation is at these frames *)
      if s.legs.frame > 8 && s.legs.frame < 15 then s.fy <- -.jumpspeed;
      if Soldat_anims.ended s.legs then legs_apply s Fall 1
    end
  end
  else if down then begin
    if s.on_ground then legs_apply s Crouch 1
  end
  else if right || left then begin
    let way = if right then 1. else -1. in
    legs_apply s (if (s.direction = 1) = right then Run else Run_back) 1;
    if s.on_ground then begin
      s.fx <- way *. runspeed;
      s.fy <- -.runspeedup
    end
    else s.fx <- way *. flyspeed
  end
  else legs_apply s (if s.on_ground then Stand else Fall) 1;
  (* a roll's legs and body kept together (C:2043-2066) *)
  if s.legs.id = Roll && s.body.id <> Roll then body_apply s Roll 1;
  if s.body.id = Roll && s.legs.id <> Roll then legs_apply s Roll 1;
  if s.legs.id = Roll_back && s.body.id <> Roll_back then body_apply s Roll_back 1;
  if s.body.id = Roll_back && s.legs.id <> Roll_back then legs_apply s Roll_back 1;
  if (s.body.id = Roll || s.body.id = Roll_back) && s.legs.frame <> s.body.frame then
    if s.legs.frame > s.body.frame then s.body <- { s.body with frame = s.legs.frame } else s.legs <- { s.legs with frame = s.body.frame };
  (* a roll's end (C:2068-2115) *)
  if (s.body.id = Roll || s.body.id = Roll_back) && Soldat_anims.ended s.body then begin
    let crouched () =
      if left || right then legs_apply s (if s.body.id = Roll then Crouch_run else Crouch_run_back) 1 else legs_apply s Crouch 15
    in
    if s.on_ground then begin
      if down then crouched ()
    end
    else if s.body.id = Roll_back && up then
      if left || right then legs_apply s (if (s.direction = 1) <> left then Run else Run_back) 1 else legs_apply s Fall 1
    else if down then crouched ();
    body_apply s Stand 1
  end;
  (* what the body does when it has nothing else to do (C:2117-2178);
   * with weapons, when their animations are over *)
  let busy = match s.body.id with Roll | Roll_back | Prone | Get_up | Prone_move -> true | _ -> false in
  if (not busy) || (Soldat_anims.ended s.body && s.body.id <> Prone) then begin
    match s.stance with
    | Standing -> body_apply s Stand 1
    | Crouching -> body_apply s Aim 1
    | Lying -> body_apply s Prone 26
  end;
  (* how it stands is what its legs do (C:2180-2189) *)
  s.stance <-
    (match s.legs.id with
    | Prone | Prone_move -> Lying
    | Crouch | Crouch_run | Crouch_run_back -> Crouching
    | _ -> Standing);
  { c with left; right }

(*****************************************************************************)
(* The map *)
(*****************************************************************************)

(* CheckMapCollision (S:2623): a point of the soldier, where it will
 * be, in a wall: the particle pushed out and slowed. [feet]: the point
 * is a foot (the Pascal's Area 0), else the head (1) *)
let check_map (map : Soldat_map.t) (s : t) (c : control) (x : float) (y : float) ~(feet : bool) : bool =
  let pos = (x +. s.vx, y +. s.vy) in
  match List.find_opt (fun (w : Soldat_map.wall) -> Soldat_map.stops_soldier w.kind && Soldat_map.in_wall pos w) (Soldat_map.sector map (fst pos) (snd pos)) with
  | None -> false
  | Some w ->
      let (step, depth, _) = Soldat_map.closest_perp w pos in
      let speed = Float.hypot s.vx s.vy in
      (* out along the perp, by how deep it is, never more than its speed *)
      let (nx, ny) = normalize step in
      let (px, py) = (nx *. depth, ny *. depth) in
      let (px, py) = if Float.hypot px py > speed then (let (ux, uy) = normalize (px, py) in (ux *. speed, uy *. speed)) else (px, py) in
      if feet || s.vy < 0. || s.vx > slidelimit || s.vx < -.slidelimit then begin
        s.old_x <- s.x;
        s.old_y <- s.y;
        s.x <- s.x -. px;
        s.y <- s.y -. py;
        let (px, py) = if w.kind = Bouncy then (let (ux, uy) = normalize (px, py) in (ux *. w.bounciness *. speed, uy *. w.bounciness *. speed)) else (px, py) in
        s.vx <- s.vx -. px;
        s.vy <- s.vy -. py
      end;
      if feet then begin
        let floor = snd step > slidelimit in
        match s.legs.id with
        | Stand | Crouch | Prone | Prone_move | Get_up | Fall | Mercy | Mercy2 | Own ->
            (* still, on a floor: it stays where it was, and does not fall *)
            if s.vx < slidelimit && s.vx > -.slidelimit && floor then begin
              s.x <- s.old_x;
              s.y <- s.old_y;
              s.fy <- s.fy -. grav
            end;
            if floor && w.kind <> Ice && w.kind <> Bouncy then begin
              let stop () =
                s.vx <- s.vx *. standsurfacecoefx;
                s.vy <- s.vy *. standsurfacecoefy;
                s.fx <- s.fx -. s.vx
              and slide () =
                s.vx <- s.vx *. surfacecoefx;
                s.vy <- s.vy *. surfacecoefy
              in
              match s.legs.id with
              | Stand | Fall | Crouch -> stop ()
              | Prone -> if s.legs.frame > 24 then (if not (c.down && (c.left || c.right)) then stop ()) else slide ()
              | Get_up -> slide ()
              | Prone_move ->
                  s.vx <- s.vx *. standsurfacecoefx;
                  s.vy <- s.vy *. standsurfacecoefy
              | _ -> ()
            end
        | Crouch_run | Crouch_run_back ->
            s.vx <- s.vx *. crouchmovesurfacecoefx;
            s.vy <- s.vy *. crouchmovesurfacecoefy
        | _ ->
            s.vx <- s.vx *. surfacecoefx;
            s.vy <- s.vy *. surfacecoefy
      end;
      true

(* CheckRadiusMapCollision (S:2512): the soldier as a circle of radius
 * 3, along its way in steps of 1, against the walls' edges: sent back
 * where it was, its speed what pushes it less the way into the wall *)
let check_radius (map : Soldat_map.t) (s : t) (x : float) (y : float) : bool =
  let steps = max 1 (int_of_float (Float.hypot s.vx s.vy)) in
  let (dx, dy) = (s.vx /. float_of_int steps, s.vy /. float_of_int steps) in
  let rec along (z : int) (sx : float) (sy : float) : bool =
    z < steps
    &&
    let (sx, sy) = (sx +. dx, sy +. dy) in
    let hit (w : Soldat_map.wall) : bool =
      Soldat_map.stops_soldier w.kind
      && Array.exists
           (fun (nx, ny) ->
             let pos = (sx -. (nx *. sprite_col_radius), sy -. (ny *. sprite_col_radius)) in
             Soldat_map.in_edges pos w
             && begin
                  let ((px, py), _, edge) = Soldat_map.closest_perp w (sx, sy) in
                  let (p1, p2) = match edge with 1 -> (w.a, w.b) | 2 -> (w.b, w.c) | _ -> (w.c, w.a) in
                  let depth = Soldat_map.point_line_distance p1 p2 pos in
                  s.x <- s.old_x;
                  s.y <- s.old_y;
                  s.vx <- s.fx -. (px *. depth);
                  s.vy <- s.fy -. (py *. depth);
                  true
                end)
           w.perps
    in
    List.exists hit (Soldat_map.sector map sx sy) || along (z + 1) sx sy
  in
  along 0 x (y -. 3.)

(* CheckMapVerticesCollision (S:2898): within 3 of a wall's corner, a
 * push of 1 away from it *)
let check_vertices (map : Soldat_map.t) (s : t) (x : float) (y : float) : bool =
  let near ((vx, vy) : float * float) : bool =
    Float.hypot (vx -. x) (vy -. y) < 3.
    && begin
         let (ux, uy) = normalize (x -. vx, y -. vy) in
         s.x <- s.x +. ux;
         s.y <- s.y +. uy;
         true
       end
  in
  List.exists (fun (w : Soldat_map.wall) -> Soldat_map.stops_soldier w.kind && (near w.a || near w.b || near w.c)) (Soldat_map.sector map x y)

(* the head, the feet, the circle, the corners (S:861-918); [c] is the
 * keys as [control] took them *)
let collide (map : Soldat_map.t) (s : t) (c : control) : unit =
  s.on_ground <- false;
  ignore (check_map map s c (s.x -. 3.5) (s.y -. 12.) ~feet:false);
  ignore (check_map map s c (s.x +. 3.5) (s.y -. 12.) ~feet:false);
  (* walking, the leading foot is lifted a little; and a foot already
   * in the ground too, not to lose it on a slope *)
  let (front, back) = if c.left <> c.right then if c.left <> (s.direction = 1) then (0., 0.25) else (0.25, 0.) else (0., 0.) in
  let front = if front = 0. && Soldat_map.in_bullet_wall map (s.x +. 2., s.y +. 1.9) then 0.25 else front in
  let back = if back = 0. && Soldat_map.in_bullet_wall map (s.x -. 2., s.y +. 1.9) then 0.25 else back in
  (* one foot is enough: two would push twice *)
  s.on_ground <- check_map map s c (s.x +. 2.) (s.y +. 2. -. front) ~feet:true || check_map map s c (s.x -. 2.) (s.y +. 2. -. back) ~feet:true;
  ignore (check_radius map s s.x (s.y -. 1.));
  s.on_ground <- check_vertices map s s.x s.y || s.on_ground;
  if s.on_ground = s.on_ground_last then s.on_ground_permanent <- s.on_ground;
  s.on_ground_last <- s.on_ground

(*****************************************************************************)
(* A tick *)
(*****************************************************************************)

let tick (map : Soldat_map.t) ~(ticks : int) (before : t) (c : control) : t =
  let s = { before with x = before.x } in
  (* client/UpdateFrame.pas: the step, then TSprite.Update *)
  euler s;
  let c = control s c in
  s.direction <- (if s.aim_x >= s.x then 1 else -1);
  s.old_skeleton <- s.skeleton;
  s.skeleton <- place_skeleton s;
  s.body <- Soldat_anims.advance s.body;
  s.legs <- Soldat_anims.advance s.legs;
  collide map s c;
  (* the jets fill again when not used: every tick on the ground, every
   * other in the air (S:1182-1186) *)
  if s.jets < map.jet && (not c.jetpack) && (s.on_ground || ticks mod 2 = 0) then s.jets <- s.jets + 1;
  let cap v = Float.max (-.max_velocity) (Float.min max_velocity v) in
  s.vx <- cap s.vx;
  s.vy <- cap s.vy;
  s

let out_of_map (map : Soldat_map.t) (s : t) : bool =
  let edge = Soldat_map.edge map in
  Float.abs s.x > edge || Float.abs s.y > edge
