(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* A tick of the game, in Soldat's order (server/ServerLoop.pas): each
 * living soldier moves (Soldat_soldier.tick: its keys, the player's or
 * a bot's), each bullet is tested along where it is going and then
 * moves, the dead tumble and come back; then the camera.
 *
 * [tick] knows no keyboard and no screen: it is given what the player
 * wants (an intent, as the bots give theirs) and where it looks. So a
 * test calls it, and one day a server will, with the intents the
 * network brought. [update] is the Playground's: it reads the keys and
 * the mouse, and calls [tick].
 *
 * The gun is still TinySoldat's one gun, with the numbers of Soldat's
 * USSOCOM (server/configs/weapons.ini): a shot every 10 ticks, a
 * bullet leaving the hand at 18 a tick plus half the soldier's speed,
 * pulled down 2.25 times as hard as a soldier, losing a hundredth of
 * its speed a tick; a hit takes speed x 1.49 x the place's (head 1.1,
 * chest 0.95, legs 0.85) of a health of 150, and pushes. A soldier
 * that just appeared neither fires nor is hit for 90 ticks (Soldat's
 * cease-fire). No ammunition,
 * no reload, no going through bodies, no ricochet, no grenades yet:
 * the weapons are docs/plan.md's step 4.
 *
 * In Soldat: client/UpdateFrame.pas and server/ServerLoop.pas (the
 * tick), shared/mechanics/Bullets.pas (TBullet.Update,
 * CheckMapCollision, CheckSpriteCollision), TSprite.Fire and
 * TSprite.Respawn (Sprites.pas).
 *)
open Playground
open Soldat_model (* its types, used all along *)

(*****************************************************************************)
(* The player *)
(*****************************************************************************)

(* Soldat's keys (client/configs/controls.cfg): A and D, W to jump, S to
 * crouch, X to lie down, the left button to fire, the right one for the
 * jets (shift too, for a pad without one). The mouse is on the screen,
 * y upwards; the soldier in the map, y downwards *)
let human (computer : computer) (p : play) : intent =
  let k = computer.keyboard and m = computer.mouse in
  let key l = Set_.mem l k.keys in
  let z = zoom computer.screen in
  let (cx, cy) = p.camera in
  {
    control =
      {
        left = key "a"; right = key "d"; up = key "w"; down = key "s"; prone = key "x";
        jetpack = m.mrdown || k.kshift;
        aim = (cx +. (m.mx /. z), cy -. (m.my /. z));
      };
    fire = m.mdown;
  }

(*****************************************************************************)
(* The gun *)
(*****************************************************************************)

let fire_interval = 10
let bullet_speed = 18.
let bullet_damage = 1.49
let bullet_push = 0.02
let bullet_gravity = 2.25 *. Soldat_soldier.grav
let bullet_timeout = 420

(* PART_RADIUS: a soldier, to a bullet, is circles of this radius *)
let part_radius = 7.

(* at these points of its skeleton, the head first (Bullets.pas's
 * BodyPartsPriority) *)
let hit_points = [ 12; 11; 10; 6; 5; 4; 3 ]

(* what a hit there is worth: the legs, the chest, the head *)
let modifier (point : int) : float = if point <= 4 then 0.85 else if point <= 11 then 0.95 else 1.1

let normalize ((x, y) : float * float) : float * float =
  let len = Float.hypot x y in
  if len < 0.001 then (0., 0.) else (x /. len, y /. len)

(* a shot: from the hand (point 15) towards the cursor *)
let shoot (owner : int) (s : soldier) : bullet =
  let (hx, hy) = Soldat_soldier.point s.body 15 in
  let (dx, dy) = normalize (s.body.aim_x -. hx, s.body.aim_y -. hy) in
  { x = hx; y = hy; vx = (dx *. bullet_speed) +. (s.body.vx *. 0.5); vy = (dy *. bullet_speed) +. (s.body.vy *. 0.5); owner; ttl = bullet_timeout }

(* the bullet's way this tick ends in a wall, looked at every 2.5 units
 * or less (TBullet.CheckMapCollision), or goes through one of the
 * map's colliders (CheckColliderCollision) *)
let hits_map (map : Soldat_map.t) (b : bullet) : bool =
  let steps = max 1 (int_of_float (Float.max (Float.abs b.vx) (Float.abs b.vy) /. 2.5)) in
  let rec go k = k <= steps && (Soldat_map.in_bullet_wall map (b.x +. (b.vx *. float_of_int k /. float_of_int steps), b.y +. (b.vy *. float_of_int k /. float_of_int steps)) || go (k + 1)) in
  go 1 || List.exists (fun collider -> Collide.segment_circle ((b.x, b.y), (b.x +. b.vx, b.y +. b.vy)) collider <> None) map.colliders

(* what the walls a soldier touched this tick do to its health
 * (HandleSpecialPolyTypes, S:3071, the server's branches): the deadly
 * ones take all of it and more, the hurting ones and lava 5 now and
 * then, the healing ones give 2 back every 12 ticks. Soldat hurts one
 * tick in ten by chance; here every tenth tick, a tick having no
 * chance in it *)
let wall_damage (ticks : int) (s : soldier) : float =
  List.fold_left
    (fun damage (kind : Pms.kind) ->
      match kind with
      | Deadly -> Float.max damage (s.health +. 50.)
      | Bloody_deadly -> Float.max damage (s.health +. 450.)
      | Explodes -> Float.max damage 4000.
      | Hurts | Lava -> if ticks mod 10 = 0 then Float.max damage 5. else damage
      | Regenerates -> if ticks mod 12 = 0 && damage = 0. && s.health < full_health then -2. else damage
      | _ -> damage)
    0. s.body.touched

(* the first of a soldier's points the bullet's way this tick goes
 * through *)
let hits_soldier (b : bullet) (s : soldier) : int option =
  let way = ((b.x, b.y), (b.x +. b.vx, b.y +. b.vy)) in
  List.find_opt (fun point -> Collide.segment_circle way (Soldat_soldier.point s.body point, part_radius) <> None) hit_points

(*****************************************************************************)
(* A tick *)
(*****************************************************************************)

(* Soldat's camera (client/UpdateFrame.pas): 0.14 of the way to the
 * player each tick, and moved by a seventh of [look], where the cursor
 * is from the screen's middle: one sees farther where one points. Dead,
 * it follows the body's head *)
let follow (p : play) (me : soldier) ((lx, ly) : float * float) : float * float =
  let (cx, cy) = p.camera in
  let (px, py) = match me.dead with None -> (me.body.x, me.body.y) | Some (_, ragdoll) -> ragdoll.(11).pos in
  (cx +. (0.14 *. (px -. cx)) +. (lx /. 7.), cy +. (0.14 *. (py -. cy)) +. (ly /. 7.))

let respawn_ticks = 180

(* a tick: [player] is what the human soldier wants, [look] where its
 * cursor is from the screen's middle, in the map's units *)
let tick (p : play) (player : intent) ~(look : float * float) : play =
  let p = { p with frame = p.frame + 1 } in
  let soldiers = Array.copy p.soldiers in
  let minds = Array.copy p.minds in
  let n = Array.length soldiers in
  let shots = ref [] in
  (* 1. the living soldiers: their keys, their move, their shot *)
  soldiers
  |> Array.iteri (fun i s ->
         if s.dead = None then begin
           let it =
             if s.human then player
             else if not p.ai_engine then Soldat_bots.bot p i
             else begin
               let (it, mind') = Bot.step Soldat_bots.mind (p, i) minds.(i) in
               minds.(i) <- mind';
               it
             end
           in
           let body = Soldat_soldier.tick p.map ~ticks:p.frame s.body it.control in
           (* out of the map: back at a spawn point, as Soldat does *)
           let body = if Soldat_soldier.out_of_map p.map body then Soldat_soldier.create (spawn p.map (i + p.frame)) p.map.jet else body in
           let s = { s with body; reload = max 0 (s.reload - 1); safe = max 0 (s.safe - 1) } in
           let s =
             if it.fire && s.reload = 0 && s.safe = 0 then begin
               shots := shoot i s :: !shots;
               { s with reload = fire_interval }
             end
             else s
           in
           soldiers.(i) <- s
         end);
  (* 2. the bullets: tested along their way, then moved *)
  let damage = Array.make n 0. and killer = Array.make n (-1) and hit = Array.make n None in
  let bullets =
    (p.bullets @ List.rev !shots)
    |> List.filter_map (fun (b : bullet) ->
           let struck =
             List.find_map
               (fun i -> if i <> b.owner && soldiers.(i).dead = None && soldiers.(i).safe = 0 then Option.map (fun point -> (i, point)) (hits_soldier b soldiers.(i)) else None)
               (List.init n Fun.id)
           in
           match struck with
           | Some (i, point) ->
               damage.(i) <- damage.(i) +. (Float.hypot b.vx b.vy *. bullet_damage *. modifier point);
               killer.(i) <- b.owner;
               hit.(i) <- Some (point, (b.vx *. bullet_push *. 10., b.vy *. bullet_push *. 10.));
               let body = soldiers.(i).body in
               soldiers.(i) <- { (soldiers.(i)) with body = { body with vx = body.vx +. (b.vx *. bullet_push); vy = body.vy +. (b.vy *. bullet_push) } };
               None
           | None ->
               if b.ttl = 0 || hits_map p.map b then None
               else
                 (* ParticleSystem.Euler, with the bullets' gravity *)
                 let vx = b.vx and vy = b.vy +. bullet_gravity in
                 Some { b with x = b.x +. vx; y = b.y +. vy; vx = vx *. 0.99; vy = vy *. 0.99; ttl = b.ttl - 1 })
  in
  (* 3. the damage: the bullets', and the walls' (by nobody's hand); the
   * dead become ragdolls, and come back after 3 s *)
  soldiers
  |> Array.iteri (fun i s ->
         match s.dead with
         | None ->
             let health = Float.min full_health (s.health -. damage.(i) -. wall_damage p.frame s) in
             if health < 1. then begin
               soldiers.(i) <- { s with health = 0.; dead = Some (0, Soldat_ragdoll.of_soldier s.body hit.(i)) };
               if killer.(i) >= 0 && killer.(i) <> i then soldiers.(killer.(i)) <- { (soldiers.(killer.(i))) with kills = soldiers.(killer.(i)).kills + 1 }
             end
             else soldiers.(i) <- { s with health }
         | Some (ticks, ragdoll) ->
             if ticks > respawn_ticks then begin
               (* at the spawn point farthest from the living *)
               let living = List.filter_map (fun (o : soldier) -> if o.dead = None then Some (o.body.x, o.body.y) else None) (Array.to_list soldiers) in
               let spot = farthest p.map living in
               soldiers.(i) <- { s with dead = None; health = full_health; reload = 0; safe = ceasefire; body = Soldat_soldier.create spot p.map.jet }
             end
             else soldiers.(i) <- { s with dead = Some (ticks + 1, Soldat_ragdoll.tick p.map ragdoll) });
  { p with camera = follow p soldiers.(0) look; soldiers; minds; bullets }

(*****************************************************************************)
(* The rounds *)
(*****************************************************************************)

let winner (p : play) : soldier option = Array.to_list p.soldiers |> List.find_opt (fun s -> s.kills >= 5)

let update (computer : computer) (model : model) : model =
  let scenes = Scene2d.update computer model.scenes in
  let space = Scene2d.pressed (fun k -> k.kspace) scenes in
  (* g: the next way of drawing, round to the first *)
  let model =
    if Scene2d.pressed (fun k -> Set_.mem "g" k.keys) scenes then { model with graphics = (model.graphics mod graphics_levels) + 1; graphics_shown = 150 }
    else { model with graphics_shown = max 0 (model.graphics_shown - 1) }
  in
  let scenes =
    match scenes.scene with
    | Loading name -> (
        (* the map asked by its name: its file comes when it comes; if
         * it does not, or is no map, the one the program carries *)
        match Soldat_assets.bytes ("maps/" ^ name ^ ".pms") with
        | Loading -> scenes
        | Missing -> Scene2d.go (Title (Lazy.force Soldat_map.arena2)) scenes
        | Here bytes -> (
            match Pms.parse bytes with
            | Ok pms -> Scene2d.go (Title (Soldat_map.of_pms pms)) scenes
            | Error _ -> Scene2d.go (Title (Lazy.force Soldat_map.arena2)) scenes))
    | Title map | Over (_, map) ->
        (* ai=engine chooses the bots, at the start of a round *)
        let ai_engine = List.assoc_opt "ai" computer.flags = Some "engine" in
        if space then Scene2d.go (Playing (start ~ai_engine map)) scenes else scenes
    | Playing p -> (
        let z = zoom computer.screen in
        let p = tick p (human computer p) ~look:(computer.mouse.mx /. z, -.computer.mouse.my /. z) in
        match winner p with Some s -> Scene2d.go (Over (s.name, p.map)) scenes | None -> { scenes with scene = Playing p })
  in
  { model with scenes }
