(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Pms.mli *)

type color = { r : int; g : int; b : int; a : int }
type vertex = { x : float; y : float; color : color; u : float; v : float }

type kind =
  | Normal
  | Only_bullets
  | Only_players
  | No_collide
  | Ice
  | Deadly
  | Bloody_deadly
  | Hurts
  | Regenerates
  | Lava
  | Team_bullets of int
  | Team_players of int
  | Bouncy
  | Explodes
  | Hurts_flaggers
  | Only_flaggers
  | Not_flaggers
  | Non_flagger_collides
  | Background
  | Background_transition
  | Unknown of int

type polygon = { a : vertex; b : vertex; c : vertex; perps : (float * float * float) array; kind : kind }

type prop = {
  active : bool;
  style : int;
  width : int;
  height : int;
  x : float;
  y : float;
  rotation : float;
  scale_x : float;
  scale_y : float;
  alpha : int;
  color : color;
  level : int;
}

type collider = { active : bool; x : float; y : float; radius : float }
type spawnpoint = { active : bool; x : int; y : int; team : int }

type waypoint = {
  active : bool;
  id : int;
  x : int;
  y : int;
  left : bool;
  right : bool;
  up : bool;
  down : bool;
  jetpack : bool;
  path : int;
  action : int;
  connections : int list;
}

type t = {
  version : int;
  name : string;
  texture : string;
  sky_top : color;
  sky_bottom : color;
  jet : int;
  grenade_packs : int;
  medikits : int;
  weather : int;
  steps : int;
  random_id : int;
  polygons : polygon array;
  sectors_division : int;
  sectors_num : int;
  sectors : int array array;
  props : prop array;
  scenery : string array;
  colliders : collider array;
  spawnpoints : spawnpoint array;
  waypoints : waypoint array;
}

(*****************************************************************************)
(* The kinds *)
(*****************************************************************************)

let kind_of_number (n : int) : kind =
  match n with
  | 0 -> Normal
  | 1 -> Only_bullets
  | 2 -> Only_players
  | 3 -> No_collide
  | 4 -> Ice
  | 5 -> Deadly
  | 6 -> Bloody_deadly
  | 7 -> Hurts
  | 8 -> Regenerates
  | 9 -> Lava
  | 10 | 12 | 14 | 16 -> Team_bullets (((n - 10) / 2) + 1)
  | 11 | 13 | 15 | 17 -> Team_players (((n - 11) / 2) + 1)
  | 18 -> Bouncy
  | 19 -> Explodes
  | 20 -> Hurts_flaggers
  | 21 -> Only_flaggers
  | 22 -> Not_flaggers
  | 23 -> Non_flagger_collides
  | 24 -> Background
  | 25 -> Background_transition
  | n -> Unknown n

let number_of_kind (k : kind) : int =
  match k with
  | Normal -> 0
  | Only_bullets -> 1
  | Only_players -> 2
  | No_collide -> 3
  | Ice -> 4
  | Deadly -> 5
  | Bloody_deadly -> 6
  | Hurts -> 7
  | Regenerates -> 8
  | Lava -> 9
  | Team_bullets team -> 10 + (2 * (team - 1))
  | Team_players team -> 11 + (2 * (team - 1))
  | Bouncy -> 18
  | Explodes -> 19
  | Hurts_flaggers -> 20
  | Only_flaggers -> 21
  | Not_flaggers -> 22
  | Non_flagger_collides -> 23
  | Background -> 24
  | Background_transition -> 25
  | Unknown n -> n

(*****************************************************************************)
(* Reading *)
(*****************************************************************************)

(* what was wrong, and where *)
exception Bad of string

(* the bytes, and how far they have been read. Each reader below takes
 * its bytes and moves on, or raises Bad: [parse] alone catches it *)
type reader = { bytes : string; mutable pos : int }

let need (r : reader) (n : int) : unit =
  if n < 0 || r.pos + n > String.length r.bytes then
    raise (Bad (Printf.sprintf "%d bytes wanted at %d, of %d" n r.pos (String.length r.bytes)))

let skip (r : reader) (n : int) : unit =
  need r n;
  r.pos <- r.pos + n

let u8 (r : reader) : int =
  need r 1;
  let v = Char.code r.bytes.[r.pos] in
  r.pos <- r.pos + 1;
  v

let u16 (r : reader) : int =
  need r 2;
  let v = String.get_uint16_le r.bytes r.pos in
  r.pos <- r.pos + 2;
  v

let i32 (r : reader) : int =
  need r 4;
  let v = Int32.to_int (String.get_int32_le r.bytes r.pos) in
  r.pos <- r.pos + 4;
  v

(* an IEEE 754 single, what Pascal's Single is *)
let single (r : reader) : float =
  need r 4;
  let v = Int32.float_of_bits (String.get_int32_le r.bytes r.pos) in
  r.pos <- r.pos + 4;
  v

let bool (r : reader) : bool = u8 r <> 0

(* a byte for its length, then [size] bytes whatever the length: the
 * text is the first of them *)
let text (r : reader) (size : int) : string =
  let n = u8 r in
  need r size;
  let s = if n <= size then String.sub r.bytes r.pos n else "" in
  r.pos <- r.pos + size;
  s

(* blue first *)
let color (r : reader) : color =
  let b = u8 r in
  let g = u8 r in
  let red = u8 r in
  let a = u8 r in
  { r = red; g; b; a }

let vertex (r : reader) : vertex =
  let x = single r in
  let y = single r in
  skip r 8; (* z, rhw *)
  let color = color r in
  let u = single r in
  let v = single r in
  { x; y; color; u; v }

let vec3 (r : reader) : float * float * float =
  let x = single r in
  let y = single r in
  let z = single r in
  (x, y, z)

(* a count, checked against Soldat's limit for it, then that many *)
let counted (r : reader) (what : string) (limit : int) (read : reader -> 'a) : 'a array =
  let n = i32 r in
  if n < 0 || n > limit then raise (Bad (Printf.sprintf "%d %s (at most %d)" n what limit));
  (* Array.init's order is the indexes': the readers move on in turn *)
  Array.init n (fun _ -> read r)

let polygon (r : reader) : polygon =
  let a = vertex r in
  let b = vertex r in
  let c = vertex r in
  let p1 = vec3 r in
  let p2 = vec3 r in
  let p3 = vec3 r in
  let kind = kind_of_number (u8 r) in
  { a; b; c; perps = [| p1; p2; p3 |]; kind }

let prop (r : reader) : prop =
  let active = bool r in
  skip r 1;
  let style = u16 r in
  let width = i32 r in
  let height = i32 r in
  let x = single r in
  let y = single r in
  let rotation = single r in
  let scale_x = single r in
  let scale_y = single r in
  let alpha = u8 r in
  skip r 3;
  let color = color r in
  let level = u8 r in
  skip r 3;
  { active; style; width; height; x; y; rotation; scale_x; scale_y; alpha; color; level }

let scenery (r : reader) : string =
  let name = text r 50 in
  skip r 4; (* the file's date *)
  name

let collider (r : reader) : collider =
  let active = bool r in
  skip r 3;
  let x = single r in
  let y = single r in
  let radius = single r in
  { active; x; y; radius }

let spawnpoint (r : reader) : spawnpoint =
  let active = bool r in
  skip r 3;
  let x = i32 r in
  let y = i32 r in
  let team = i32 r in
  { active; x; y; team }

(* MAX_CONNECTIONS: the file has room for 20, whatever their number *)
let waypoint (r : reader) : waypoint =
  let active = bool r in
  skip r 3;
  let id = i32 r in
  let x = i32 r in
  let y = i32 r in
  let left = bool r in
  let right = bool r in
  let up = bool r in
  let down = bool r in
  let jetpack = bool r in
  let path = u8 r in
  let action = u8 r in
  skip r 5;
  let n = i32 r in
  let all = List.init 20 (fun _ -> i32 r) in
  { active; id; x; y; left; right; up; down; jetpack; path; action; connections = List.filteri (fun i _ -> i < n) all }

let map (r : reader) : t =
  let version = i32 r in
  let name = text r 38 in
  let texture = text r 24 in
  let sky_top = color r in
  let sky_bottom = color r in
  let jet = i32 r in
  let grenade_packs = u8 r in
  let medikits = u8 r in
  let weather = u8 r in
  let steps = u8 r in
  let random_id = i32 r in
  let polygons = counted r "polygons" 5000 polygon in
  let sectors_division = i32 r in
  let sectors_num = i32 r in
  if sectors_num < 0 || sectors_num > 25 then raise (Bad (Printf.sprintf "%d sectors each way (at most 25)" sectors_num));
  let side = (2 * sectors_num) + 1 in
  let sectors =
    Array.init (side * side) (fun _ ->
        let n = u16 r in
        if n > 5000 then raise (Bad (Printf.sprintf "%d polygons in a sector (at most 5000)" n));
        Array.init n (fun _ -> u16 r))
  in
  let props = counted r "props" 500 prop in
  let scenery = counted r "pictures of scenery" 500 scenery in
  let colliders = counted r "colliders" 128 collider in
  let spawnpoints = counted r "spawn points" 255 spawnpoint in
  let waypoints = counted r "waypoints" 5000 waypoint in
  { version; name; texture; sky_top; sky_bottom; jet; grenade_packs; medikits; weather; steps; random_id;
    polygons; sectors_division; sectors_num; sectors; props; scenery; colliders; spawnpoints; waypoints }

let parse (bytes : string) : (t, string) result =
  match map { bytes; pos = 0 } with
  | m -> Ok m
  | exception Bad why -> Error ("not a map: " ^ why)
