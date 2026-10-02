(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* The bots, two ways, chosen with the flag ai=engine:
 *
 *  - by hand, the default: the bot takes the nearest living enemy
 *    wherever it is, through the walls, and asks what it can see only
 *    to decide whether to shoot; it aims with a wobble (a sine of the
 *    time, so every game replays the same), runs towards or away, jumps
 *    or flies when the enemy is above, and throws a grenade at what it
 *    cannot see;
 *  - with ai=engine, on Sense and Bot: what a bot may know is a
 *    value rather than the world -- an enemy seen when nothing of the
 *    map is on the segment between them, remembered for 90 frames where
 *    it was last seen, nothing at all before that -- and it acts on
 *    senses 12 frames old, changes its mind every 4 (a hand's quarter
 *    second, not a machine's instant), and aims with an error that
 *    settles the longer it can see you.
 *
 * The second is the interesting one to read next to the first: taking
 * away the knowledge costs a behaviour the hand-written bot never
 * needed. Never having to look for anyone, it had nothing to do when it
 * saw nobody; the ai/ one patrols, turning every two seconds and hopping
 * when it gets stuck, and hunts what it remembers, lobbing a grenade at
 * where you went.
 *
 * In Soldat: shared/AI.pas, whose bots follow the map's waypoints
 * (shared/Waypoints.pas) and have a character each, a .bot file
 * (accuracy, favourite weapon, how often they throw grenades, what
 * they say when they kill).
 *)
open Playground
open Basics (* float arithmetics *)
open Soldat_model (* its types, used all along *)

(* the hand-written bot, the default: it takes the nearest living enemy
 * wherever it is -- through the walls -- and only asks what it can see
 * when it decides whether to shoot *)
let bot (p : play) (i : int) : intent =
  let me = body_of p i in
  let others = List.filter (fun j -> j <> i && p.soldiers.(j).dead = None) [ 0; 1; 2 ] in
  let distance j = let b = body_of p j in Float.hypot (b.x - me.x) (b.y - me.y) in
  match List.sort (fun a b -> compare (distance a) (distance b)) others with
  | [] -> { run = 0.; jump = false; jet = false; shoot = false; grenade = false; aim = p.soldiers.(i).aim }
  | target :: _ ->
      let t = body_of p target in
      let dx = t.x - me.x and dy = t.y - me.y in
      let seen = Soldat_map.clear p.map (me.x, me.y + 10.) (t.x, t.y) in
      (* the aim wobbles, a sine of the time: no Random *)
      let wobble = 5. * sin ((float_of_int p.frame * 0.07) + float_of_int i) in
      (* nearer than 120: back off; farther than 260: go; in between,
       * strafe, changing sides every 1.5 s *)
      let strafe = if (p.frame /.. 90) mod 2 = 0 then 1. else -1. in
      let run = if Float.abs dx > 260. then Float.copy_sign 1. dx else if Float.abs dx < 120. then Float.copy_sign 1. (-.dx) else strafe in
      {
        run;
        jump = dy > 60. || (Float.abs me.vx < 20. && run <> 0.);
        jet = dy > 100. && p.soldiers.(i).fuel > 20.;
        shoot = seen;
        grenade = (not seen) && Float.abs dx < 450.;
        aim = (if seen then degrees dx dy + wobble else degrees dx (dy + 200.));
      }

(*****************************************************************************)
(* The bots on ai/ (ai=engine) *)
(*****************************************************************************)
(* with the flag ai=engine, the same three soldiers on the ai/
 * layer. The difference is not the tactics -- those are the same
 * numbers below -- but what a bot is allowed to know and how fast it
 * may act on it. *)

(* what soldier [i] may know: its nearest living enemy, seen if nothing
 * of the map is between them, remembered for 90 frames after that *)
let look (p : play) (i : int) (was : (number * number) Sense.target) : (number * number) Sense.target =
  let me = body_of p i in
  let others = List.filter (fun j -> j <> i && p.soldiers.(j).dead = None) [ 0; 1; 2 ] in
  let distance j = let b = body_of p j in Float.hypot (b.x - me.x) (b.y - me.y) in
  match List.sort (fun a b -> compare (distance a) (distance b)) others with
  | [] -> Sense.forget ~after:90 (Sense.update ~distance:Float.infinity ~clear:false ~position:(me.x, me.y) was)
  | j :: _ ->
      let t = body_of p j in
      Sense.update ~distance:(distance j) ~clear:(Soldat_map.clear p.map (me.x, me.y + 10.) (t.x, t.y)) ~position:(t.x, t.y) was
      |> Sense.forget ~after:90

let senses_of (was : senses option) ((p, i) : play * int) : senses =
  let me = body_of p i in
  let enemy = look p i (match was with Some s -> s.enemy | None -> Sense.unknown) in
  { me = (me.x, me.y); my_vx = me.vx; my_fuel = p.soldiers.(i).fuel; seed = i; frame = p.frame; enemy }

(* the mind: nearer than 120, back off; farther than 260, go; in
 * between, strafe. Shoot what it sees, lob a grenade at what it
 * remembers, and aim with an error that settles the longer the enemy
 * stays in sight (Bot.mli).
 *
 * a bot that knows only what it can see (Sense.mli) needs
 * one thing the old one didn't: somewhere to go when it sees nobody.
 * The old bot took the nearest enemy through the walls and never had
 * to look for anyone -- which is exactly the cheat this layer is here
 * to take away. So: patrol, turning every two seconds and hopping when
 * it gets stuck against something *)
let decide (s : senses) : intent =
  let still = { run = 0.; jump = false; jet = false; shoot = false; grenade = false; aim = 0. } in
  match s.enemy.position with
  | None ->
      let way = if ((s.frame /.. 120) +.. s.seed) mod 2 = 0 then 1. else -1. in
      { still with run = way; jump = Float.abs s.my_vx < 20.; aim = if way > 0. then 0. else 180. }
  | Some (tx, ty) ->
      let (mx, my) = s.me in
      let dx = tx - mx and dy = ty - my in
      let seen = s.enemy.visible in
      let strafe = if (s.enemy.seen_for /.. 90) mod 2 = 0 then 1. else -1. in
      let run = if Float.abs dx > 260. then Float.copy_sign 1. dx else if Float.abs dx < 120. then Float.copy_sign 1. (-.dx) else strafe in
      let error = Bot.aim_error ~spread:12. ~settle:25. ~seen_for:s.enemy.seen_for ~seed:s.seed () in
      {
        run;
        jump = dy > 60. || (Float.abs s.my_vx < 20. && run <> 0.);
        jet = dy > 100. && s.my_fuel > 20.;
        shoot = seen;
        grenade = (not seen) && Float.abs dx < 450.;
        aim = (if seen then degrees dx dy + error else degrees dx (dy + 200.));
      }

(* a human's reaction is about a quarter of a second, and no hand
 * changes its mind sixty times a second (Bot.mli) *)
let mind : (play * int, senses, intent) Bot.t =
  Bot.make ~delay:12 ~rate:4 ~sense:senses_of ~decide ()
