(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* The game's state: the soldiers, what each wants to do this tick,
 * the bullets in flight, the map, and where the camera is.
 *
 * Everything is in Soldat's own units and coordinates (y downwards, a
 * soldier about 20 tall, speeds a tick), as the map is; only the
 * picture turns y over (Soldat_view).
 *
 * In Soldat: a soldier is shared/mechanics/Sprites.pas's TSprite and
 * what it wants to do its TControl (set from the keys or by a bot,
 * turned into moves by Control.pas), a bullet Bullets.pas's TBullet,
 * and the round shared/Game.pas.
 *)
open Playground

type soldier = {
  name : string;
  color : color;
  human : bool;
  (* its particle and its skeleton, moved by Soldat's rules *)
  body : Soldat_soldier.t;
  health : float;
  (* ticks before the next shot *)
  reload : int;
  (* ticks, after appearing, during which it neither fires nor is hit
   * (Soldat's CeaseFireCounter) *)
  safe : int;
  (* None while alive; Some (ticks since, its ragdoll) when dead *)
  dead : (int * Soldat_ragdoll.t) option;
  kills : int;
}

(* what a soldier wants to do this tick: the player's keys and mouse,
 * or a bot's mind *)
type intent = { control : Soldat_soldier.control; fire : bool }

let still : intent = { control = Soldat_soldier.no_control; fire = false }

(* what a bot may know (Sense.mli): where it is and how it is, and
 * its nearest enemy -- seen now, or remembered where it was last seen,
 * or not known at all. Not the world: a bot cannot read through a wall
 * what it hasn't got *)
type senses = {
  me : float * float;
  my_vx : float;
  my_fuel : int;
  seed : int; (* which bot: its aim wobbles its own way *)
  frame : int; (* to patrol by, when it has nobody to chase *)
  enemy : (float * float) Sense.target;
}

type bullet = { x : float; y : float; vx : float; vy : float; owner : int; ttl : int }

type play = {
  map : Soldat_map.t;
  (* the point of the map at the screen's middle *)
  camera : float * float;
  soldiers : soldier array;
  (* with ai=engine, one per soldier: the senses it has seen but not yet
   * acted on, its memory of its enemy among them (Bot.mli) *)
  minds : (senses, intent) Bot.running array;
  ai_engine : bool;
  bullets : bullet list;
  frame : int;
}

(* the map goes from a round to the next: the title's, the round's,
 * and after the round the winner's name over it *)
type scene = Title of Soldat_map.t | Playing of play | Over of string * Soldat_map.t

type model = scene Scene2d.t

(* Soldat's DEFAULT_HEALTH *)
let full_health = 150.

(* and its DEFAULT_CEASEFIRE_TIME *)
let ceasefire = 90

(* the [i]th place to appear at, going round when the map has fewer
 * than there are soldiers *)
let spawn (map : Soldat_map.t) (i : int) : float * float = List.nth map.spawns (i mod List.length map.spawns)

(* of the map's places to appear at, the one farthest from [others] *)
let farthest (map : Soldat_map.t) (others : (float * float) list) : float * float =
  let room (x, y) = List.fold_left (fun m (ox, oy) -> Float.min m (Float.hypot (ox -. x) (oy -. y))) infinity others in
  List.fold_left (fun best sp -> if room sp > room best then sp else best) (List.hd map.spawns) map.spawns

let start ?(ai_engine = false) (map : Soldat_map.t) : play =
  let soldier place name color human =
    { name; color; human; body = Soldat_soldier.create place map.jet; health = full_health; reload = 0; safe = ceasefire; dead = None; kills = 0 }
  in
  (* the player at the map's first place, each bot as far as can be
   * from those before it *)
  let first = spawn map 0 in
  let second = farthest map [ first ] in
  let third = farthest map [ first; second ] in
  let soldiers = [| soldier first "YOU" (rgb 220 60 50) true; soldier second "BLUE" (rgb 60 110 220) false; soldier third "GREEN" (rgb 60 170 80) false |] in
  { map; camera = first; soldiers; minds = Array.map (fun _ -> Bot.start still) soldiers; ai_engine; bullets = []; frame = 0 }

let initial_model (map : Soldat_map.t) : model = Scene2d.start (Title map)

(* Soldat shows 640 units across (DEFAULT_WIDTH): how many of the
 * screen's a unit is *)
let zoom (screen : screen) : float = screen.width /. 640.
