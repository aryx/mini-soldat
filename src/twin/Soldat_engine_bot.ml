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

let character : character = Soldat_cast.engine

(* what the bot of ai=engine may know (Sense.mli, Soldat_engine_bot):
 * where it is and how it is, and its nearest enemy -- seen now, or
 * remembered where it was last seen, or not known at all. Not the
 * round: it cannot read through a wall what it has not got *)
type senses = {
  me : float * float;
  my_vx : float;
  my_fuel : int;
  seed : int; (* which soldier: its aim wobbles its own way *)
  frame : int; (* to patrol by, when it has nobody to chase *)
  enemy : (float * float) Sense.target;
  (* the next waypoint of its way, on a map that has some: to where it
   * last saw its enemy, or to a far place of the map when it knows nobody *)
  way : Pms.waypoint option;
}

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
  (* its enemies: everyone, or the other team *)
  let enemy j = team p.soldiers.(i) = 0 || team p.soldiers.(j) <> team p.soldiers.(i) in
  let others = List.filter (fun j -> j <> i && p.soldiers.(j).dead = None && enemy j) (List.init (Array.length p.soldiers) Fun.id) in
  match List.sort (fun a b -> compare (distance a) (distance b)) others with
  | [] -> Sense.forget ~after:90 (Sense.update ~distance:Float.infinity ~clear:false ~position:(mx, my) was)
  | j :: _ ->
      let t = chest p.soldiers.(j) in
      Sense.update ~distance:(distance j) ~clear:(Soldat_map.clear p.map (mx, my) t) ~position:t was |> Sense.forget ~after:90

(* its way (Pathfind.astar): the map's waypoints are a graph, each
 * saying which others one can go to from it; the cheapest path from
 * the one nearest it to the one nearest where it wants to be, a step's
 * cost its length. The next waypoint of that path, if there is one *)
let way (map : Soldat_map.t) (from : float * float) (goal : float * float) : Pms.waypoint option =
  let n = Array.length map.waypoints in
  let at k = let (w : Pms.waypoint) = map.waypoints.(k) in (float_of_int w.x, float_of_int w.y) in
  let far (ax, ay) (bx, by) = Float.hypot (bx -. ax) (by -. ay) in
  let nearest (place : float * float) : int =
    List.fold_left (fun best k -> if map.waypoints.(k).active && (best < 0 || far place (at k) < far place (at best)) then k else best) (-1) (List.init n Fun.id)
  in
  let (start, target) = (nearest from, nearest goal) in
  if start < 0 || target < 0 then None
  else
    let problem : int Pathfind.problem =
      { neighbors = (fun k -> List.filter_map (fun c -> if c >= 1 && c <= n && map.waypoints.(c - 1).active then Some (c - 1, far (at k) (at (c - 1))) else None) map.waypoints.(k).connections);
        goal = (fun k -> k = target);
        estimate = (fun k -> far (at k) (at target)) }
    in
    (* at its first waypoint already (within 40 units): the one after *)
    match (Pathfind.astar problem start).path with
    | first :: next :: _ when far from (at first) < 40. -> Some map.waypoints.(next)
    | first :: _ -> Some map.waypoints.(first)
    | [] -> None

let sense (was : senses option) ((p, i) : play * int) : senses =
  let me = p.soldiers.(i) in
  let enemy = look p i (match was with Some s -> s.enemy | None -> Sense.unknown) in
  (* where it wants to be: where it last saw its enemy; knowing nobody,
   * a waypoint of the map, another every ten seconds *)
  let goal =
    match enemy.position with
    | Some at -> Some at
    | None ->
        let n = Array.length p.map.waypoints in
        if n = 0 then None else let (w : Pms.waypoint) = p.map.waypoints.(((p.frame / 600) + (i * 7)) mod n) in Some (float_of_int w.x, float_of_int w.y)
  in
  { me = chest me; my_vx = me.body.vx; my_fuel = me.body.jets; seed = i; frame = p.frame; enemy; way = Option.bind goal (way p.map (chest me)) }

(*****************************************************************************)
(* Its mind *)
(*****************************************************************************)

(* the keys for: run this way (-1, 0, 1), jump, fly, pull the trigger *)
let keys ~(run : float) ~(jump : bool) ~(jet : bool) ~(aim : float * float) ~(fire : bool) : intent =
  { Soldat_soldier.no_control with left = run < 0.; right = run > 0.; up = jump; jetpack = jet; aim; fire }

(* a bot that knows only what it has seen needs somewhere to go when
 * it knows nobody: it patrols, turning every two seconds and hopping
 * when it is stuck against something *)
type doing = Fight | Travel | Patrol

(* what to do (Behavior): the first of these that holds. A tree, read
 * from the top: a selector tries each in turn, a sequence needs all of
 * its own *)
let tree : (senses, doing) Behavior.t =
  Selector
    [ Sequence [ Condition ("sees its enemy", fun (s : senses) -> s.enemy.visible); Action ("fight", Fight) ];
      Sequence [ Condition ("has a way to go", fun (s : senses) -> s.way <> None); Action ("travel", Travel) ];
      Sequence [ Condition ("remembers its enemy", fun (s : senses) -> s.enemy.position <> None); Action ("go where it was", Fight) ];
      Action ("patrol", Patrol) ]

let decide (s : senses) : intent =
  let (mx, my) = s.me in
  match (Behavior.decide tree s, s.way, s.enemy.position) with
  | (Some Travel, Some w, _) ->
      (* along its way: towards the waypoint, holding the keys it says
       * (the map's maker's: jump here, fly there), hopping when stuck *)
      let (wx, wy) = (float_of_int w.x, float_of_int w.y) in
      let run = if Float.abs (wx -. mx) < 8. then 0. else Float.copy_sign 1. (wx -. mx) in
      keys ~run ~jump:(w.up || Float.abs s.my_vx < 0.2) ~jet:((w.jetpack || my -. wy > 60.) && s.my_fuel > 20) ~aim:(wx, wy) ~fire:false
  | (_, _, None) ->
      let way = if ((s.frame / 120) + s.seed) mod 2 = 0 then 1. else -1. in
      keys ~run:way ~jump:(Float.abs s.my_vx < 0.2) ~jet:false ~aim:(mx +. (way *. 100.), my) ~fire:false
  | (_, _, Some (tx, ty)) ->
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

(*****************************************************************************)
(* The part *)
(*****************************************************************************)

(* a bot's mind in a round: the senses it has seen and not yet acted
 * on, its memory of its enemy among them (Bot.running) *)
type Soldat_state.mind += Mind of (senses, intent) Bot.running

let running (m : Soldat_state.mind) : (senses, intent) Bot.running option = match m with Mind r -> Some r | _ -> None

(* the twin as the game's bots (Soldat_parts): it looks at no thing *)
let part : Soldat_parts.bots =
  {
    owns = (function Mind _ -> true | _ -> false);
    fresh = (fun _ -> Mind (Bot.start still));
    control =
      (fun p i its ~random:_ ->
        match its with
        | Mind running ->
            let (keys, running) = Bot.step mind (p, i) running in
            (keys, Mind running, [])
        | other -> (still, other, []));
  }
