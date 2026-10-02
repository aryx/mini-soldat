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
 * solver): the soldiers are upright boxes (they don't tip over), run by
 * setting their speed, pushed up by their jets against gravity.
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

(* the world's bodies: the map's, then one per soldier (always there:
 * the solver knows bodies by their place), then the grenades' *)
type play = {
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

type scene = Title | Playing of play | Over of string

type model = scene Scene2d.t

let n_map = List.length Soldat_map.bodies
let body_of (p : play) (i : int) : Physics.body = List.nth p.world.bodies (n_map +.. i)

(* a dead soldier's body waits far away, out of everyone's way *)
let parked (color : color) : Physics.body = soldier_body color (0., 5000.) |> Physics.immovable

let start ?(ai_engine = false) () : play =
  let soldier name color human = { name; color; human; health = 100.; fuel = 100.; reload = 0; grenade_reload = 0; aim = 0.; dead = None; kills = 0 } in
  let soldiers = [| soldier "YOU" (rgb 220 60 50) true; soldier "BLUE" (rgb 60 110 220) false; soldier "GREEN" (rgb 60 170 80) false |] in
  let bodies = Array.to_list (Array.mapi (fun i s -> soldier_body s.color (List.nth Soldat_map.spawns i)) soldiers) in
  let still = { run = 0.; jump = false; jet = false; shoot = false; grenade = false; aim = 0. } in
  { world = Physics.world (Soldat_map.bodies @ bodies);
    soldiers;
    minds = Array.map (fun _ -> Bot.start still) soldiers;
    ai_engine;
    bullets = []; grenades = []; blasts = []; frame = 0 }

let initial_model : model = Scene2d.start Title

(* the direction (dx, dy) as an angle, in degrees *)
let degrees (dx : number) (dy : number) : number = Float.atan2 dy dx * 180. / Float.pi
