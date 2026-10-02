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
 * the bullets in flight, the explosions still seen, the map, where
 * the camera is, and the seed of the game's chance.
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
  (* the same, as red, green and blue: its shirt's *)
  shirt : int * int * int;
  human : bool;
  (* its particle and its skeleton, moved by Soldat's rules *)
  body : Soldat_soldier.t;
  (* 150 at most; dead, it goes on down as the body is hit, to -400 *)
  health : float;
  (* None while alive; Some (ticks since, its ragdoll) when dead *)
  dead : (int * Soldat_ragdoll.t) option;
  kills : int;
  (* the weapon it will appear with next *)
  primary : Soldat_weapons.id;
}

(* what a soldier wants to do this tick: the player's keys and mouse,
 * or a bot's mind *)
type intent = Soldat_soldier.control

let still : intent = Soldat_soldier.no_control

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

(* a bullet, a pellet, a grenade: Soldat's TBullet *)
type bullet = {
  x : float;
  y : float;
  vx : float;
  vy : float;
  (* where it was a tick before *)
  old : float * float;
  owner : int;
  weapon : Soldat_weapons.id;
  (* what a hit takes, times its speed: the weapon's Damage, halved
   * beyond 500 units and again beyond 900 (HitMultiply) *)
  damage : float;
  ttl : int;
  (* where it left from, and how many times it was halved *)
  start : float * float;
  halved : int;
  (* where it last bounced off a wall: not again within 50 of there *)
  bounced_at : float * float;
  (* the last soldier it went through, not hit twice; none: -1 *)
  through : int;
}

(* an explosion, for the picture: nothing of the game reads it *)
type explosion = { at : float * float; radius : float; age : int }

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
  explosions : explosion list;
  (* the game's chance: the next number comes from it (Lehmer) *)
  seed : Lehmer.t;
  frame : int;
}

(* the map goes from a round to the next: the title's, the round's,
 * and after the round the winner's name over it *)
type scene =
  | Loading of string (* a map asked by its name, its file not there yet *)
  | Title of Soldat_map.t
  | Playing of play
  | Over of string * Soldat_map.t

(* how much of Soldat's look is drawn, the steps this game was made
 * in (docs/plan.md), each one a key away (g) to see what it added:
 *   1  the soldiers as their skeletons' sticks, the map in flat colours
 *   2  the soldiers' pictures
 *   3  the map's texture and scenery *)
let graphics_levels = 3

let graphics_name (level : int) : string =
  match level with 1 -> "1: skeletons, flat colours" | 2 -> "2: the soldiers' pictures" | _ -> "3: the map's texture and scenery"

type model = {
  scenes : scene Scene2d.t;
  graphics : int;
  (* frames its name still shows for, after a change *)
  graphics_shown : int;
  (* the weapon the player appears with: the keys 1 to 9 and 0 *)
  primary : Soldat_weapons.id;
  (* the rounds started: a round's number is its chance's seed *)
  rounds : int;
}

(* Soldat's DEFAULT_HEALTH *)
let full_health = 150.

(* the [i]th place to appear at, going round when the map has fewer
 * than there are soldiers *)
let spawn (map : Soldat_map.t) (i : int) : float * float = List.nth map.spawns (i mod List.length map.spawns)

(* of the map's places to appear at, the one farthest from [others] *)
let farthest (map : Soldat_map.t) (others : (float * float) list) : float * float =
  let room (x, y) = List.fold_left (fun m (ox, oy) -> Float.min m (Float.hypot (ox -. x) (oy -. y))) infinity others in
  List.fold_left (fun best sp -> if room sp > room best then sp else best) (List.hd map.spawns) map.spawns

(* [primary]: the player's weapon; [seed]: the game's chance, the same
 * game from the same one *)
let start ?(ai_engine = false) ?(primary : Soldat_weapons.id = Ak74) ?(seed = 1) (map : Soldat_map.t) : play =
  let soldier place name ((r, g, b) as shirt) human primary =
    { name; color = rgb r g b; shirt; human; body = Soldat_soldier.create ~primary place map.jet; health = full_health; dead = None; kills = 0; primary }
  in
  (* the player at the map's first place, each bot as far as can be
   * from those before it *)
  let first = spawn map 0 in
  let second = farthest map [ first ] in
  let third = farthest map [ first; second ] in
  let soldiers = [| soldier first "YOU" (220, 60, 50) true primary; soldier second "BLUE" (60, 110, 220) false Mp5; soldier third "GREEN" (60, 170, 80) false Steyr |] in
  { map; camera = first; soldiers; minds = Array.map (fun _ -> Bot.start still) soldiers; ai_engine; bullets = []; explosions = []; seed = Lehmer.scramble seed; frame = 0 }

let model_at ?(graphics = graphics_levels) (first : scene) : model =
  { scenes = Scene2d.start first; graphics = max 1 (min graphics_levels graphics); graphics_shown = 0; primary = Ak74; rounds = 0 }

let initial_model ?graphics (map : Soldat_map.t) : model = model_at ?graphics (Title map)

(* starting on a map asked by its name (maps/NAME.pms of the content) *)
let loading_model ?graphics (name : string) : model = model_at ?graphics (Loading name)

(* Soldat shows 640 units across (DEFAULT_WIDTH): how many of the
 * screen's a unit is *)
let zoom (screen : screen) : float = screen.width /. 640.
