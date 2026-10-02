(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* The game's state: the soldiers, what each wants to do this frame,
 * the bullets, grenades and blasts in flight, and the world they are
 * all in.
 *
 * The map and the soldiers are a Physics.world (the Playground's
 * solver): the map's walls are bodies nothing moves, the soldiers are
 * upright boxes (they don't tip over), run by setting their speed,
 * pushed up by their jets against gravity. The map is a value the round
 * carries (Soldat_map.t), bigger than the screen when it is one of
 * Soldat's: a camera (the Playground's Camera2d) follows the player.
 *
 * In Soldat: a soldier is shared/mechanics/Sprites.pas's TSprite and
 * what it wants to do its TControl (set from the keys or by a bot,
 * turned into moves by Control.pas), a bullet Bullets.pas's TBullet,
 * what lies on the map (flags, kits, a weapon dropped) Things.pas's
 * TThing, and the round shared/Game.pas.
 *)
open Playground
open Basics (* float arithmetics *)

let soldier_body (color : color) ((x, y) : number * number) : Physics.body =
  Physics.body (rectangle color 22. 44.) |> Physics.at x y |> Physics.upright |> Physics.rough 0.2

type soldier = {
  name : string;
  color : color;
  human : bool;
  health : number;
  fuel : number;
  (* frames before the next shot, the next grenade *)
  reload : int;
  grenade_reload : int;
  (* where it aims, in degrees *)
  aim : number;
  (* None while alive; Some (frames since, its ragdoll) when dead *)
  dead : (int * Particles.particle array) option;
  kills : int;
}

(* what a soldier wants to do this frame: the player's keys, or a bot's
 * mind *)
type intent = { run : number; (* -1, 0, 1 *) jump : bool; jet : bool; shoot : bool; grenade : bool; aim : number }

(* what a bot may know (Sense.mli): where it is and how it is, and
 * its nearest enemy -- seen now, or remembered where it was last seen,
 * or not known at all. Not the world: a bot cannot read through a wall
 * what it hasn't got *)
type senses = {
  me : number * number;
  my_vx : number;
  my_fuel : number;
  seed : int; (* which bot: its aim wobbles its own way *)
  frame : int; (* to patrol by, when it has nobody to chase *)
  enemy : (number * number) Sense.target;
}

type bullet = { b : Physics.body; owner : int; ttl : int }
type grenade = { fuse : int; thrower : int }
type blast = { x : number; y : number; age : int }

(* the world's bodies: the map's ([n_map] of them), then one per
 * soldier (always there: the solver knows bodies by their place), then
 * the grenades' *)
type play = {
  map : Soldat_map.t;
  n_map : int;
  (* the part of the map the screen shows: it follows the player *)
  camera : Camera2d.t;
  world : Physics.world;
  soldiers : soldier array;
  (* with ai=engine, one per soldier: the senses it has seen
   * but not yet acted on, its memory of its enemy among them
   * (Bot.mli) *)
  minds : (senses, intent) Bot.running array;
  ai_engine : bool;
  bullets : bullet list;
  grenades : grenade list;
  blasts : blast list;
  frame : int;
}

(* the map goes from a round to the next: the title's, the round's,
 * and after the round the winner's name over it *)
type scene = Title of Soldat_map.t | Playing of play | Over of string * Soldat_map.t

type model = scene Scene2d.t

let body_of (p : play) (i : int) : Physics.body = List.nth p.world.bodies (p.n_map +.. i)

(* a dead soldier's body waits far above the map, out of everyone's way *)
let parked (map : Soldat_map.t) (color : color) : Physics.body = soldier_body color (0., map.bounds.top + 5000.) |> Physics.immovable

(* the [i]th place to appear at, going round when the map has fewer
 * than there are soldiers *)
let spawn (map : Soldat_map.t) (i : int) : number * number = List.nth map.spawns (i mod List.length map.spawns)

(* the camera on (x, y), as far as the map goes *)
let camera_at (screen : screen) (map : Soldat_map.t) ((x, y) : number * number) : Camera2d.t =
  Camera2d.clamp screen map.bounds (Camera2d.look_at x y Camera2d.origin)

let start ?(ai_engine = false) (map : Soldat_map.t) : play =
  let soldier name color human = { name; color; human; health = 100.; fuel = 100.; reload = 0; grenade_reload = 0; aim = 0.; dead = None; kills = 0 } in
  let soldiers = [| soldier "YOU" (rgb 220 60 50) true; soldier "BLUE" (rgb 60 110 220) false; soldier "GREEN" (rgb 60 170 80) false |] in
  let bodies = Array.to_list (Array.mapi (fun i s -> soldier_body s.color (spawn map i)) soldiers) in
  let still = { run = 0.; jump = false; jet = false; shoot = false; grenade = false; aim = 0. } in
  let (x, y) = spawn map 0 in
  { map;
    n_map = List.length map.bodies;
    camera = Camera2d.look_at x y Camera2d.origin;
    world = Physics.world (map.bodies @ bodies);
    soldiers;
    minds = Array.map (fun _ -> Bot.start still) soldiers;
    ai_engine;
    bullets = []; grenades = []; blasts = []; frame = 0 }

let initial_model (map : Soldat_map.t) : model = Scene2d.start (Title map)

(* the direction (dx, dy) as an angle, in degrees *)
let degrees (dx : number) (dy : number) : number = Float.atan2 dy dx * 180. / Float.pi
