(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *
 * Adapted from OpenSoldat's shared/mechanics/Bullets.pas and
 * shared/mechanics/Sprites.pas (HealthHit, Die), Copyright 2001-2020
 * Transhuman Design, Copyright 2020-2023 OpenSoldat contributors (the
 * MIT License).
 *)

(* The bullets: what flies, and what it does to what it meets.
 *
 * A bullet is a particle, as a soldier is: a place and a speed, pulled
 * down 2.25 times as hard as a soldier, losing a hundredth of its
 * speed a tick. Each tick it is first *tested along where it is
 * going*, from where it is to where its speed takes it, and then
 * moved (TBullet.Update, then the particles' step):
 *
 *   the map         every 2.5 units of its way or less, is that point
 *                   in a wall?
 *   the colliders   the map's circles (a crate, a barrel): the segment
 *                   of its way against each
 *   the soldiers    the nearest first; each is 7 circles of radius 7
 *                   at points of its skeleton: the head (12), the
 *                   shoulders and the hips (11, 10, 6, 5), the knees
 *                   (4, 3). The dead are hit too
 *   its time        7 seconds, a grenade 3
 *   its strength    halved 500 units from where it left, and again at
 *                   900 (not the Barrett's)
 *
 * What is hit first along its way is what counts: a soldier behind
 * the wall the bullet ends in this tick is not hit.
 *
 * **A wall.** A bullet more than 50 from where it last bounced
 * *ricochets*:
 *
 *       speed' = 25/35 speed + 10/35 |speed| x (out of the wall)
 *
 * so it keeps most of its way and is turned a little out of the wall,
 * the wall's own speed-keeping nothing to do with it. It then dies if
 * a sixth of a tick further along its new way is still in a wall:
 * which is nearly always. Only a grazing shot goes on: at 10 degrees
 * to a floor, speed (0.98, 0.17) becomes (0.70, 0.12 - 0.29) = (0.70,
 * -0.16), up and out; straight into it, (0, 1) becomes (0, 0.43),
 * still in: dead.
 *
 * **A soldier.** A hit takes
 *
 *       the bullet's speed x its weapon's Damage x the place's
 *
 * (the place: head, chest or legs, weapons.ini's modifiers) and pushes
 * the soldier by the weapon's Push of the bullet's speed. The bullet
 * then *goes through* or stops: through a body already dead keeping
 * 0.9 of its speed; through one it just killed, or at more than 23 a
 * tick, 0.75; through any other while still at 0.9 of its weapon's
 * speed (and more than 5), 0.66; else it stops there. So an Ak-74's
 * bullet (24 a tick) goes through a first soldier at 18, hurts a
 * second one 0.75 as much, and stops in it. A soldier's own bullet
 * cannot hit it in its first 20 ticks; a grenade, its first 50.
 *
 * **A grenade** bounces off walls (it is moved out and keeps 0.88 of
 * its speed, less what went into the wall), and explodes on a living
 * soldier, on a collider, or after 3 seconds. The M79's explodes on
 * anything, or ricochets as a bullet does.
 *
 * **An explosion** (ExplosionHit) reaches 85 units (the M79's: 64).
 * Each living soldier whose nearest point is within it at a distance d
 * is pushed away by 3.75 d / (d + 1), twice that upwards or downwards,
 * and loses
 *
 *       Damage / (d + 1) x the place's
 *
 * with the grenade's Damage of 1500: 136 at 10 units, 48 at 30, 18 at
 * the edge; under one's feet, everything. The dead within it are
 * thrown (Soldat_ragdoll.blast), and every grenade within 50 goes off
 * too. Walls do not shelter from it.
 *
 * Where the Pascal is not followed: a bullet that ends in a wall there
 * explodes at once and is tested against the soldiers after, so that
 * an M79 hitting a soldier against a wall explodes twice. Here what is
 * nearest along its way is found first, and it explodes once.
 *
 * Left out: the flame, the arrow, the knife, the cluster grenades, the
 * things a bullet hits (a flag, a dropped weapon), the teams' walls,
 * the sparks and the sounds of a hit.
 *
 * In Soldat: TBullet.Update, CheckMapCollision, CheckColliderCollision,
 * CheckSpriteCollision, ExplosionHit (shared/mechanics/Bullets.pas);
 * TSprite.HealthHit and TSprite.Die (shared/mechanics/Sprites.pas).
 *)
open Soldat_model (* its types, used all along *)

(* BulletParts.GravityMultiplier and EDamping (shared/Anims.pas) *)
let gravity = 2.25 *. Soldat_soldier.grav
let damping = 0.99

(* PART_RADIUS: a soldier, to a bullet, is circles of this radius *)
let part_radius = 7.

(* at these points of its skeleton, the head first (BodyPartsPriority) *)
let hit_points = [ 12; 11; 10; 6; 5; 4; 3 ]

(* the explosions' reach, a hand grenade's and the M79's; within
 * [after_radius] other grenades go off; EXPLOSION_IMPACT_MULTIPLY *)
let frag_radius = 85.
let m79_radius = 64.
let after_radius = 50.
let impact = 3.75

(* GRENADE_SURFACECOEF *)
let grenade_bounce = 0.88

let normalize ((x, y) : float * float) : float * float =
  let len = Float.hypot x y in
  if len < 0.001 then (0., 0.) else (x /. len, y /. len)

let distance ((ax, ay) : float * float) ((bx, by) : float * float) : float = Float.hypot (bx -. ax) (by -. ay)

let of_shot ~(owner : int) (shot : Soldat_soldier.shot) : bullet =
  let w = Soldat_weapons.get shot.weapon in
  let (x, y) = shot.from and (vx, vy) = shot.velocity in
  { x; y; vx; vy; old = shot.from; owner; weapon = shot.weapon; damage = w.damage; ttl = w.timeout; start = shot.from; halved = 0; bounced_at = (0., 0.); through = -1 }

(*****************************************************************************)
(* The soldiers, as a bullet sees them *)
(*****************************************************************************)

(* a tick's bullets act on these, one after the other: what a bullet
 * did, the next one finds *)
type world = {
  map : Soldat_map.t;
  soldiers : soldier array;
  (* what pushed each this tick: a body dying leaves with it *)
  pushes : (float * float) array;
  (* the bullets, each gone once it is None *)
  bullets : bullet option array;
  mutable explosions : explosion list;
  (* what is to be heard and seen of it all, the last first *)
  mutable events : Soldat_event.t list;
  (* a Rambomatch: its rules of who is hurt and what a kill is worth *)
  rambo : bool;
}

let emit (w : world) (e : Soldat_event.t) : unit = w.events <- e :: w.events

(* a point of its skeleton, by Soldat's number: placed alive, loose dead *)
let point (s : soldier) (n : int) : float * float = match s.dead with None -> Soldat_soldier.point s.body n | Some (_, ragdoll) -> ragdoll.points.(n - 1).pos

let place (s : soldier) : float * float = match s.dead with None -> (s.body.x, s.body.y) | Some (_, ragdoll) -> ragdoll.points.(11).pos

let push (w : world) (i : int) ((px, py) : float * float) : unit =
  let s = w.soldiers.(i) in
  if s.dead = None then begin
    w.soldiers.(i) <- { s with body = { s.body with vx = s.body.vx +. px; vy = s.body.vy +. py } };
    let (ax, ay) = w.pushes.(i) in
    w.pushes.(i) <- (ax +. px, ay +. py)
  end

(* HealthHit and Die: [amount] taken from soldier [i] by soldier [by]'s
 * hand, at the point [where] of its skeleton. Under 1 it dies, and its
 * killer has a kill more -- or one less, if it killed itself *)
let hurt ?(weapon : Soldat_weapons.id option) (w : world) (i : int) ~(by : int) ~(where : int) (amount : float) : unit =
  let s = w.soldiers.(i) in
  (* a Rambomatch: while somebody else is Rambo, these two do nothing
   * to each other (HealthHit, S:3326) *)
  let third = ref false in
  if w.rambo && by <> i then Array.iteri (fun j o -> if j <> i && j <> by && rambo o then third := true) w.soldiers;
  if !third then () else
  (* its own team's bullets do nothing to it (sv_friendlyfire is off);
   * its own do *)
  if by <> i && by >= 0 && team s <> 0 && team w.soldiers.(by) = team s then ()
  else
  let health = Float.max Soldat_ragdoll.brutal_health (Float.min full_health (s.health -. amount)) in
  let cuts = Soldat_ragdoll.cuts ~health ~where in
  match s.dead with
  | Some (ticks, ragdoll) -> w.soldiers.(i) <- { s with health; dead = Some (ticks, Soldat_ragdoll.cut cuts ragdoll) }
  | None when health < 1. ->
      (* its last cry, by how it dies (TSprite.Die) *)
      let (hx, hy) = point s 12 in
      emit w (Sound ((if health <= Soldat_ragdoll.brutal_health then Bryzg else if cuts <> [] then Headchop else Death), (hx, hy)));
      if cuts <> [] then List.iter (fun k -> emit w (Blood ((hx, hy), (k, -1.5)))) [ -2.; 0.; 2. ];
      (* its weapon falls from its hands *)
      w.soldiers.(i) <-
        { s with health; body = Soldat_soldier.let_go s.body; dead = Some (0, Soldat_ragdoll.cut cuts (Soldat_ragdoll.of_soldier s.body ~push:w.pushes.(i))) };
      let killer = w.soldiers.(by) in
      let kills =
        if by = i then max 0 (killer.kills - 1)
        else if not w.rambo then killer.kills + 1
        else if (match weapon with Some id -> Soldat_weapons.is_bow id | None -> false) || Soldat_weapons.is_bow s.body.weapon.kind.id then
          (* a Rambomatch (TSprite.Die, S:1785): Rambo's kill, or Rambo killed *)
          killer.kills + 1
        else if Array.exists rambo w.soldiers then max 0 (killer.kills - 1) (* another killed while somebody is Rambo *)
        else killer.kills
      in
      w.soldiers.(by) <- { killer with kills }
  | None -> w.soldiers.(i) <- { s with health; hit_by = (if by <> i then by else s.hit_by) }

(*****************************************************************************)
(* An explosion *)
(*****************************************************************************)

(* ARROW_RESIST: the ticks an arrow stays in a wall; with that much
 * left or less, it hits nobody *)
let arrow_resist = 280

let explosive (b : bullet) : bool = match (Soldat_weapons.get b.weapon).style with Thrown | Explosive -> true | Plain | Pellets | Arrow -> false

(* ExplosionHit: [b] goes off at a place. [direct]: the soldier it
 * struck and where, if it struck one: that point is the one measured
 * from *)
let rec explode (w : world) (b : bullet) ~(at : float * float) ~(direct : (int * int) option) : unit =
  let m79 = b.weapon = M79 in
  let gun = Soldat_weapons.get (if m79 then M79 else Grenade) in
  let radius = if m79 then m79_radius else frag_radius in
  w.explosions <- { at; radius; age = 0 } :: w.explosions;
  emit w (Blast ((if m79 then M79 else Grenade), at));
  for i = 0 to Array.length w.soldiers - 1 do
    let s = w.soldiers.(i) in
    match s.dead with
    | None ->
        let nearest () =
          List.fold_left (fun best p -> if distance at (point s p) < distance at (point s best) then p else best) (List.hd hit_points) hit_points
        in
        let where = match direct with Some (j, where) when j = i -> where | _ -> nearest () in
        let (cx, cy) = point s where in
        let (ax, ay) = (fst at -. cx, snd at -. cy) in
        let d = Float.hypot ax ay in
        if d < radius then begin
          let k = 1. /. (d +. 1.) in
          emit w (Sound (Explosion_erg, place s));
          push w i (-.ax *. k *. impact, -.ay *. k *. impact *. 2.);
          if s.body.ceasefire = 0 then hurt w i ~by:b.owner ~where:1 (k *. gun.damage *. Soldat_weapons.modifier gun where)
        end
    | Some (ticks, ragdoll) -> (
        let (ragdoll, last) = Soldat_ragdoll.blast ragdoll ~at ~radius in
        w.soldiers.(i) <- { s with dead = Some (ticks, ragdoll) };
        match last with
        | None -> ()
        | Some d ->
            let d = if m79 then Float.max d 20.0000001 else d in
            hurt w i ~by:b.owner ~where:1 (1. /. (d +. 1.) *. gun.damage))
  done;
  (* the grenades near it go off too *)
  Array.iteri
    (fun k other ->
      match other with
      | Some (o : bullet) when explosive o && distance at (o.x, o.y) < after_radius ->
          w.bullets.(k) <- None;
          explode w o ~at:(o.x, o.y) ~direct:None
      | _ -> ())
    w.bullets

(*****************************************************************************)
(* The map *)
(*****************************************************************************)

type met = Free | Lost | Bounced of bullet | Stopped of (float * float)

(* CheckMapCollision: the bullet's way sampled, the first point of it
 * in a wall. [lift]: looked for that much above (a grenade is tested
 * twice, 2 above and where it is) *)
let against_map ?(team = 0) (map : Soldat_map.t) (b : bullet) ~(lift : float) : met =
  let style = (Soldat_weapons.get b.weapon).style in
  let steps = max 1 (int_of_float (Float.max (Float.abs b.vx) (Float.abs b.vy) /. 2.5)) in
  let (sx, sy) = (b.vx /. float_of_int steps, b.vy /. float_of_int steps) in
  let stops ((x, y) as pos) = List.find_opt (fun (w : Soldat_map.wall) -> Soldat_map.stops_bullet ~team w.kind && Soldat_map.in_edges pos w) (Soldat_map.sector map x y) in
  let outside (x, y) = Float.abs (Float.round (x /. map.division)) > float_of_int map.num || Float.abs (Float.round (y /. map.division)) > float_of_int map.num in
  let rec along (k : int) : met =
    if k >= steps then Free
    else
      let pos = (b.x +. (float_of_int k *. sx), b.y -. lift +. (float_of_int k *. sy)) in
      if outside pos then Lost
      else
        match stops pos with
        | None -> along (k + 1)
        | Some wall -> (
            match style with
            | Thrown ->
                (* out of the wall, and what went into it lost *)
                let (perp, depth, _) = Soldat_map.closest_perp wall (b.x, b.y) in
                let (nx, ny) = normalize perp in
                Bounced { b with x = fst pos; y = snd pos; vx = (b.vx -. (nx *. depth)) *. grenade_bounce; vy = (b.vy -. (ny *. depth)) *. grenade_bounce }
            (* an arrow goes into what it meets, and stays *)
            | Arrow -> Stopped pos
            | Plain | Pellets | Explosive ->
                let back = (fst pos -. b.vx, snd pos -. b.vy) in
                if distance back b.bounced_at > 50. then begin
                  (* the ricochet: turned out of the wall *)
                  let (perp, _, _) = Soldat_map.closest_perp wall back in
                  let speed = Float.hypot b.vx b.vy in
                  let (nx, ny) = normalize perp in
                  let vx = (b.vx *. (25. /. 35.)) -. (nx *. speed *. (10. /. 35.)) in
                  let vy = (b.vy *. (25. /. 35.)) -. (ny *. speed *. (10. /. 35.)) in
                  let (ux, uy) = normalize (vx, vy) in
                  let ahead = (fst pos +. (ux *. speed /. 6.), snd pos +. (uy *. speed /. 6.)) in
                  if outside ahead || stops ahead = None then Bounced { b with x = fst pos; y = snd pos; old = pos; vx; vy; bounced_at = pos } else Stopped pos
                end
                else Stopped pos)
  in
  along 0

(*****************************************************************************)
(* A circle *)
(*****************************************************************************)

(* LineCircleCollision (shared/Calc.pas): where a segment meets a
 * circle: its start if that is inside, else its end if that is, else
 * where it first crosses *)
let line_circle ((ax, ay) as a : float * float) ((bx, by) as b : float * float) ((cx, cy) as c : float * float) (r : float) : (float * float) option =
  if distance a c <= r then Some a
  else if distance b c <= r then Some b
  else begin
    let (dx, dy) = (bx -. ax, by -. ay) in
    let (fx, fy) = (ax -. cx, ay -. cy) in
    let qa = (dx *. dx) +. (dy *. dy) in
    let qb = 2. *. ((fx *. dx) +. (fy *. dy)) in
    let qc = (fx *. fx) +. (fy *. fy) -. (r *. r) in
    let disc = (qb *. qb) -. (4. *. qa *. qc) in
    if qa < 1e-12 || disc < 0. then None
    else
      let t = (-.qb -. sqrt disc) /. (2. *. qa) in
      if t >= 0. && t <= 1. then Some (ax +. (t *. dx), ay +. (t *. dy)) else None
  end

(*****************************************************************************)
(* A bullet's tick *)
(*****************************************************************************)

(* TBullet.Update for the bullet at [k], then its step if it lives *)
let update (w : world) (k : int) (b : bullet) : unit =
  let gun = Soldat_weapons.get b.weapon in
  let style = gun.style in
  let bound = (float_of_int w.map.num *. w.map.division) -. 10. in
  (* its owner's team: a team's wall stops its own bullets only *)
  let team = if b.owner >= 0 && b.owner < Array.length w.soldiers then w.soldiers.(b.owner).body.team else 0 in
  (* gone, for the others to see, before it acts on them *)
  w.bullets.(k) <- None;
  if Float.abs b.x > bound || Float.abs b.y > bound then ()
  else begin
    (* 1. the map. [ended]: where the bullet ended, if it did; [limit]:
     * how far from where it was a tick before: nothing farther is hit *)
    let ended = ref None and limit = ref None and lost = ref false in
    (* an arrow in a wall, from this tick or an earlier one *)
    let stuck = ref false in
    let b =
      match style with
      | Thrown -> (
          let bounce (b : bullet) (b' : bullet) : bullet =
            if Float.hypot b.vx b.vy > 1.5 then emit w (Sound (Grenade_bounce, (b.x, b.y)));
            b'
          in
          let lifted = match against_map ~team w.map b ~lift:2. with Bounced b' -> bounce b b' | Lost -> lost := true; b | Free | Stopped _ -> b in
          match against_map ~team w.map lifted ~lift:0. with Bounced b' -> bounce lifted b' | Lost -> lost := true; lifted | Free | Stopped _ -> lifted)
      | Arrow -> (
          (* B:1268: in a wall it stays where it is, for ARROW_RESIST
           * ticks at most; one that has lived that long harms nobody,
           * and falls again if the wall is no longer there *)
          match against_map ~team w.map b ~lift:0. with
          | Free -> b
          | Lost -> lost := true; b
          | Bounced _ | Stopped _ ->
              stuck := true;
              if b.ttl > arrow_resist then emit w (Wall ((b.x, b.y), (b.vx, b.vy)));
              b)
      | Plain | Pellets | Explosive -> (
          match against_map ~team w.map b ~lift:0. with
          | Free -> b
          | Lost -> lost := true; b
          | Bounced b' ->
              emit w (Ricochet ((b.x, b.y), (b.vx, b.vy)));
              b'
          | Stopped hit ->
              ended := Some (fst hit -. b.vx, snd hit -. b.vy);
              limit := Some (distance hit b.old);
              (* a bullet's end in a wall; the M79's is its explosion *)
              if style <> Explosive then emit w (Wall ((fst hit -. b.vx, snd hit -. b.vy), (b.vx, b.vy)));
              b)
    in
    if not !lost then begin
      let within (hit : float * float) : bool = match !limit with Some l -> distance hit b.old <= l | None -> true in
      (* 2. the colliders *)
      (match List.find_map (fun (c, r) -> line_circle (b.x, b.y) (b.x +. b.vx, b.y +. b.vy) c r) w.map.colliders with
      | Some hit when within hit && (not !stuck) && (style <> Thrown || b.ttl < gun.timeout - 2) ->
          ended := Some (b.x, b.y);
          limit := Some (distance hit b.old)
      | _ -> ());
      (* 3. the soldiers, the nearest first *)
      let pos = ref (b.x, b.y) and v = ref (b.vx, b.vy) and through = ref b.through in
      let blown = ref false in
      let vulnerable = gun.timeout - if style = Thrown then 50 else 20 in
      let radius = if style = Thrown then part_radius +. 1. else part_radius in
      let targets =
        List.init (Array.length w.soldiers) Fun.id
        |> List.filter (fun i -> (i <> b.owner || b.ttl < vulnerable) && i <> b.through)
        (* B:1453: an arrow that has stopped, or flown too long, hits nobody *)
        |> List.filter (fun _ -> not (style = Arrow && (!stuck || b.ttl <= arrow_resist)))
        |> List.map (fun i -> (distance (b.x, b.y) (place w.soldiers.(i)), i))
        |> List.sort compare |> List.map snd
      in
      let rec each = function
        | [] -> ()
        | j :: rest -> (
            let s = w.soldiers.(j) in
            let (vx, vy) = !v in
            let finish = (fst !pos +. vx, snd !pos +. vy) in
            (* the nearest of its circles the way goes through (each
             * 2 to the left of its point: Soldat's own correction) *)
            let struck =
              List.fold_left
                (fun best p ->
                  let (px, py) = point s p in
                  match line_circle !pos finish (px -. 2., py) radius with
                  | Some hit -> ( match best with Some (_, at) when distance !pos at <= distance !pos hit -> best | _ -> Some (p, hit))
                  | None -> best)
                None hit_points
            in
            match struck with
            | None -> each rest
            | Some (_, hit) when not (within hit) -> ()
            | Some _ when s.dead = None && s.body.ceasefire > 0 -> each rest
            | Some (where, hit) -> (
                let was_dead = s.dead <> None in
                if style <> Thrown then push w j (vx *. gun.push, vy *. gun.push);
                match style with
                | Plain | Pellets ->
                    pos := hit;
                    emit w (Blood (hit, (vx, vy)));
                    emit w (Sound ((if was_dead then Dead_hit else Hit_arg), hit));
                    let speed = Float.hypot vx vy in
                    hurt w j ~by:b.owner ~where (speed *. b.damage *. Soldat_weapons.modifier gun where);
                    through := j;
                    let on k =
                      v := (vx *. k, vy *. k);
                      emit w (Flesh (hit, !v));
                      each (List.filter (fun i -> i <> j) rest)
                    in
                    if was_dead then on 0.9
                    else if w.soldiers.(j).dead <> None || speed > 23. then on 0.75
                    else if speed > 5. && speed /. gun.speed >= 0.9 then on 0.66
                    else ended := Some hit
                | Arrow ->
                    (* B:1749: it stops in who it hits *)
                    pos := hit;
                    emit w (Blood (hit, (vx, vy)));
                    emit w (Sound ((if was_dead then Dead_hit else Hit_arg), hit));
                    hurt ~weapon:b.weapon w j ~by:b.owner ~where (Float.hypot vx vy *. b.damage *. Soldat_weapons.modifier gun where);
                    ended := Some hit
                | Thrown ->
                    if not was_dead then begin
                      blown := true;
                      explode w b ~at:!pos ~direct:(Some (j, where))
                    end
                | Explosive ->
                    if not was_dead then begin
                      blown := true;
                      explode w b ~at:!pos ~direct:(Some (j, where));
                      hurt w j ~by:b.owner ~where (Float.hypot vx vy *. b.damage)
                    end))
      in
      each targets;
      (* 4. its time *)
      let ttl = b.ttl - 1 in
      if !blown then ()
      else if !stuck then begin
        let ttl = min ttl arrow_resist in
        if ttl > 0 then w.bullets.(k) <- Some { b with ttl }
      end
      else if !ended <> None || ttl = 0 then begin
        (* what explodes does, where it ended *)
        if explosive b then explode w b ~at:(Option.value !ended ~default:(b.x, b.y)) ~direct:None
      end
      else begin
        (* 5. weaker with the distance, looked at every 6 ticks *)
        let far = distance b.start !pos in
        let weakens = ttl mod 6 = 0 && b.weapon <> Barrett && b.weapon <> M79 && ((b.halved = 0 && far > 500.) || (b.halved = 1 && far > 900.)) in
        let (damage, halved) = if weakens then (b.damage *. 0.5, b.halved + 1) else (b.damage, b.halved) in
        (* 6. ParticleSystem.Euler *)
        let (x, y) = !pos and (vx, vy) = !v in
        let vy = vy +. gravity in
        w.bullets.(k) <- Some { b with x = x +. vx; y = y +. vy; vx = vx *. damping; vy = vy *. damping; old = (x, y); ttl; damage; halved; through = !through }
      end
    end
  end

let world ?(rambo = false) (map : Soldat_map.t) (soldiers : soldier array) (bullets : bullet list) : world =
  { rambo; map; soldiers = Array.copy soldiers; pushes = Array.make (Array.length soldiers) (0., 0.); bullets = Array.of_list (List.map Option.some bullets); explosions = []; events = [] }

(* a tick of all the bullets, [fired] the ones that left this tick,
 * over these soldiers: the soldiers after, the bullets left, and the
 * explosions there were *)
let tick ?rambo (map : Soldat_map.t) (soldiers : soldier array) (bullets : bullet list) : soldier array * bullet list * explosion list =
  let w = world ?rambo map soldiers bullets in
  Array.iteri (fun k b -> match w.bullets.(k) with Some _ -> update w k (Option.get b) | None -> ()) (Array.copy w.bullets);
  (w.soldiers, List.filter_map Fun.id (Array.to_list w.bullets), List.rev w.explosions)

(* the same, with what is to be heard and seen of it, in its order *)
let tick_heard ?rambo (map : Soldat_map.t) (soldiers : soldier array) (bullets : bullet list) : soldier array * bullet list * Soldat_event.t list =
  let w = world ?rambo map soldiers bullets in
  Array.iteri (fun k b -> match w.bullets.(k) with Some _ -> update w k (Option.get b) | None -> ()) (Array.copy w.bullets);
  (w.soldiers, List.filter_map Fun.id (Array.to_list w.bullets), List.rev w.events)
