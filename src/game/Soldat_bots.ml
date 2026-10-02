(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* The bots, still TinySoldat's, now pressing Soldat's keys: a bot gives
 * back what a player's keyboard and mouse would (Soldat_model.intent),
 * and its soldier moves by the same rules. Two ways, chosen with the
 * flag ai=engine:
 *
 *  - by hand, the default: the bot takes the nearest living enemy
 *    wherever it is, through the walls, and asks what it can see only
 *    to decide whether to shoot; it aims with a wobble (a sine of the
 *    time, so every game replays the same), runs towards or away, jumps
 *    or flies when the enemy is above;
 *  - with ai=engine, on Sense and Bot: what a bot may know is a
 *    value rather than the world -- an enemy seen when nothing of the
 *    map is on the segment between them, remembered for 90 frames where
 *    it was last seen, nothing at all before that -- and it acts on
 *    senses 12 frames old, changes its mind every 4 (a hand's quarter
 *    second, not a machine's instant), and aims with an error that
 *    settles the longer it can see you.
 *
 * To be replaced by Soldat's own (docs/plan.md, step 5): shared/AI.pas,
 * whose bots follow the map's waypoints and have a character each, a
 * .bot file.
 *)
open Soldat_model (* its types, used all along *)

(* where a soldier's chest is: what one aims at, and sees from *)
let chest (s : soldier) : float * float = (s.body.x, s.body.y -. 12.)

let living_but (p : play) (i : int) : int list = List.filter (fun j -> j <> i && p.soldiers.(j).dead = None) [ 0; 1; 2 ]

(* the keys for: run this way (-1, 0, 1), jump, fly, pull the trigger *)
let keys ~(run : float) ~(jump : bool) ~(jet : bool) ~(aim : float * float) ~(fire : bool) : intent =
  { Soldat_soldier.no_control with left = run < 0.; right = run > 0.; up = jump; jetpack = jet; aim; fire }

(* a weapon that fires once a pull wants the trigger let go between
 * two shots: every other tick *)
let trigger (p : play) (i : int) (seen : bool) : bool = seen && ((not p.soldiers.(i).body.weapon.kind.single_shot) || p.frame mod 2 = 0)

(* the hand-written bot, the default: it takes the nearest living enemy
 * wherever it is -- through the walls -- and only asks what it can see
 * when it decides whether to shoot *)
let bot (p : play) (i : int) : intent =
  let me = p.soldiers.(i) in
  let (mx, my) = chest me in
  let distance j = let (x, y) = chest p.soldiers.(j) in Float.hypot (x -. mx) (y -. my) in
  match List.sort (fun a b -> compare (distance a) (distance b)) (living_but p i) with
  | [] -> { still with aim = (me.body.aim_x, me.body.aim_y) }
  | target :: _ ->
      let (tx, ty) = chest p.soldiers.(target) in
      (* y goes down: above is less *)
      let dx = tx -. mx and up = my -. ty in
      let seen = Soldat_map.clear p.map (mx, my) (tx, ty) in
      (* the aim wobbles, a sine of the time: no Random *)
      let wobble = 0.15 *. distance target *. sin ((float_of_int p.frame *. 0.07) +. float_of_int i) in
      (* nearer than 60: back off; farther than 130: go; in between,
       * strafe, changing sides every 1.5 s *)
      let strafe = if p.frame / 90 mod 2 = 0 then 1. else -1. in
      let run = if Float.abs dx > 130. then Float.copy_sign 1. dx else if Float.abs dx < 60. then Float.copy_sign 1. (-.dx) else strafe in
      keys ~run
        ~jump:(up > 30. || (Float.abs me.body.vx < 0.2 && run <> 0.))
        ~jet:(up > 50. && me.body.jets > 20)
        ~aim:(tx, ty +. wobble) ~fire:(trigger p i seen)

(*****************************************************************************)
(* The bots on ai/ (ai=engine) *)
(*****************************************************************************)
(* with the flag ai=engine, the same three soldiers on the ai/ layer.
 * The difference is not the tactics -- those are the same numbers
 * below -- but what a bot is allowed to know and how fast it may act
 * on it. *)

(* what soldier [i] may know: its nearest living enemy, seen if nothing
 * of the map is between them, remembered for 90 frames after that *)
let look (p : play) (i : int) (was : (float * float) Sense.target) : (float * float) Sense.target =
  let (mx, my) = chest p.soldiers.(i) in
  let distance j = let (x, y) = chest p.soldiers.(j) in Float.hypot (x -. mx) (y -. my) in
  match List.sort (fun a b -> compare (distance a) (distance b)) (living_but p i) with
  | [] -> Sense.forget ~after:90 (Sense.update ~distance:Float.infinity ~clear:false ~position:(mx, my) was)
  | j :: _ ->
      let t = chest p.soldiers.(j) in
      Sense.update ~distance:(distance j) ~clear:(Soldat_map.clear p.map (mx, my) t) ~position:t was |> Sense.forget ~after:90

let senses_of (was : senses option) ((p, i) : play * int) : senses =
  let me = p.soldiers.(i) in
  let enemy = look p i (match was with Some s -> s.enemy | None -> Sense.unknown) in
  { me = chest me; my_vx = me.body.vx; my_fuel = me.body.jets; seed = i; frame = p.frame; enemy }

(* the mind: nearer than 60, back off; farther than 130, go; in
 * between, strafe. Shoot what it sees, and aim with an error that
 * settles the longer the enemy stays in sight (Bot.mli).
 *
 * A bot that knows only what it can see (Sense.mli) needs one thing
 * the old one didn't: somewhere to go when it sees nobody. The old bot
 * took the nearest enemy through the walls and never had to look for
 * anyone -- which is exactly the cheat this layer is here to take
 * away. So: patrol, turning every two seconds and hopping when it gets
 * stuck against something *)
let decide (s : senses) : intent =
  let (mx, my) = s.me in
  match s.enemy.position with
  | None ->
      let way = if ((s.frame / 120) + s.seed) mod 2 = 0 then 1. else -1. in
      keys ~run:way ~jump:(Float.abs s.my_vx < 0.2) ~jet:false ~aim:(mx +. (way *. 100.), my) ~fire:false
  | Some (tx, ty) ->
      let dx = tx -. mx and up = my -. ty in
      let seen = s.enemy.visible in
      let strafe = if s.enemy.seen_for / 90 mod 2 = 0 then 1. else -1. in
      let run = if Float.abs dx > 130. then Float.copy_sign 1. dx else if Float.abs dx < 60. then Float.copy_sign 1. (-.dx) else strafe in
      (* the error is an angle, in degrees: across, at the enemy's distance *)
      let error = Bot.aim_error ~spread:12. ~settle:25. ~seen_for:s.enemy.seen_for ~seed:s.seed () in
      let off = Float.hypot dx up *. Float.tan (error *. Float.pi /. 180.) in
      keys ~run ~jump:(up > 30. || (Float.abs s.my_vx < 0.2 && run <> 0.)) ~jet:(up > 50. && s.my_fuel > 20) ~aim:(tx, ty +. off) ~fire:seen

(* a human's reaction is about a quarter of a second, and no hand
 * changes its mind sixty times a second (Bot.mli) *)
let mind : (play * int, senses, intent) Bot.t = Bot.make ~delay:12 ~rate:4 ~sense:senses_of ~decide ()
