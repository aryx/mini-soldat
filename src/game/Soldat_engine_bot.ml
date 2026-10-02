(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_engine_bot.mli *)
open Soldat_model (* its types, used all along *)

let character : character =
  { bot = "Engine"; bot_shirt = (60, 110, 220); bot_trousers = (30, 55, 110); bot_skin = (230, 180, 120); favourite = Ak74; accuracy = 0; shoot_dead = false; grenade_freq = -1; camper = 0 }

(* where a soldier's chest is: what one aims at, and sees from *)
let chest (s : soldier) : float * float = (s.body.x, s.body.y -. 12.)

(*****************************************************************************)
(* Its senses *)
(*****************************************************************************)

(* its nearest living enemy: seen if nothing of the map is between
 * them, remembered for 90 ticks after that (Sense.update and forget) *)
let look (p : play) (i : int) (was : (float * float) Sense.target) : (float * float) Sense.target =
  let (mx, my) = chest p.soldiers.(i) in
  let distance j = let (x, y) = chest p.soldiers.(j) in Float.hypot (x -. mx) (y -. my) in
  let others = List.filter (fun j -> j <> i && p.soldiers.(j).dead = None) (List.init (Array.length p.soldiers) Fun.id) in
  match List.sort (fun a b -> compare (distance a) (distance b)) others with
  | [] -> Sense.forget ~after:90 (Sense.update ~distance:Float.infinity ~clear:false ~position:(mx, my) was)
  | j :: _ ->
      let t = chest p.soldiers.(j) in
      Sense.update ~distance:(distance j) ~clear:(Soldat_map.clear p.map (mx, my) t) ~position:t was |> Sense.forget ~after:90

let sense (was : senses option) ((p, i) : play * int) : senses =
  let me = p.soldiers.(i) in
  let enemy = look p i (match was with Some s -> s.enemy | None -> Sense.unknown) in
  { me = chest me; my_vx = me.body.vx; my_fuel = me.body.jets; seed = i; frame = p.frame; enemy }

(*****************************************************************************)
(* Its mind *)
(*****************************************************************************)

(* the keys for: run this way (-1, 0, 1), jump, fly, pull the trigger *)
let keys ~(run : float) ~(jump : bool) ~(jet : bool) ~(aim : float * float) ~(fire : bool) : intent =
  { Soldat_soldier.no_control with left = run < 0.; right = run > 0.; up = jump; jetpack = jet; aim; fire }

(* a bot that knows only what it has seen needs somewhere to go when
 * it knows nobody: it patrols, turning every two seconds and hopping
 * when it is stuck against something *)
let decide (s : senses) : intent =
  let (mx, my) = s.me in
  match s.enemy.position with
  | None ->
      let way = if ((s.frame / 120) + s.seed) mod 2 = 0 then 1. else -1. in
      keys ~run:way ~jump:(Float.abs s.my_vx < 0.2) ~jet:false ~aim:(mx +. (way *. 100.), my) ~fire:false
  | Some (tx, ty) ->
      (* y goes down: above is less *)
      let dx = tx -. mx and up = my -. ty in
      let seen = s.enemy.visible in
      let strafe = if s.enemy.seen_for / 90 mod 2 = 0 then 1. else -1. in
      let run = if Float.abs dx > 130. then Float.copy_sign 1. dx else if Float.abs dx < 60. then Float.copy_sign 1. (-.dx) else strafe in
      (* the error is an angle, in degrees: across, at the enemy's distance *)
      let error = Bot.aim_error ~spread:12. ~settle:25. ~seen_for:s.enemy.seen_for ~seed:s.seed () in
      let off = Float.hypot dx up *. Float.tan (error *. Float.pi /. 180.) in
      keys ~run ~jump:(up > 30. || (Float.abs s.my_vx < 0.2 && run <> 0.)) ~jet:(up > 50. && s.my_fuel > 20) ~aim:(tx, ty +. off) ~fire:seen

(* a hand's reaction is about a fifth of a second, and no hand changes
 * its mind sixty times a second (Bot.mli) *)
let mind : (play * int, senses, intent) Bot.t = Bot.make ~delay:12 ~rate:4 ~sense ~decide ()
