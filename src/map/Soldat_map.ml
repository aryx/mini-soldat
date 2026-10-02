(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_map.mli *)
open Playground

type wall = {
  a : float * float;
  b : float * float;
  c : float * float;
  perps : (float * float) array;
  bounciness : float;
  kind : Pms.kind;
}

type t = {
  name : string;
  pms : Pms.t option;
  sky : shape list;
  back : shape list;
  front : shape list;
  walls : wall array;
  division : float;
  num : int;
  sectors : int array array;
  colliders : ((float * float) * float) list;
  spawns : (float * float) list;
  jet : int;
  waypoints : Pms.waypoint array;
  medikits : int;
  grenade_kits : int;
  medikit_spawns : (float * float) list;
  grenade_spawns : (float * float) list;
  alpha_spawns : (float * float) list;
  bravo_spawns : (float * float) list;
  alpha_flag : (float * float) option;
  bravo_flag : (float * float) option;
}

(*****************************************************************************)
(* The kinds *)
(*****************************************************************************)

(* [team]: whose soldier, or whose bullet (1 Alpha, 2 Bravo; none: 0).
 * A team's wall stops its own and nobody else (TeamCollides) *)
let stops_soldier ?(team = 0) (kind : Pms.kind) : bool =
  match kind with
  | Normal | Only_players | Ice | Deadly | Bloody_deadly | Hurts | Regenerates | Lava | Bouncy | Explodes | Hurts_flaggers | Not_flaggers -> true
  | Team_players n -> n = team
  | Only_bullets | No_collide | Team_bullets _ | Only_flaggers | Non_flagger_collides | Background | Background_transition | Unknown _ -> false

let stops_bullet ?(team = 0) (kind : Pms.kind) : bool =
  match kind with
  | Normal | Only_bullets | Ice | Deadly | Bloody_deadly | Hurts | Regenerates | Lava | Bouncy | Explodes | Hurts_flaggers -> true
  | Team_bullets n -> n = team
  | Only_players | No_collide | Team_players _ | Only_flaggers | Not_flaggers | Non_flagger_collides | Background | Background_transition | Unknown _ -> false

(*****************************************************************************)
(* Points and walls *)
(*****************************************************************************)

(* Pascal's Round: to the nearest whole number, a half to the even one *)
let round (x : float) : int =
  let f = Float.floor x in
  let d = x -. f in
  let n = int_of_float f in
  if d > 0.5 then n + 1 else if d < 0.5 then n else if n land 1 = 0 then n else n + 1

let sector (map : t) (x : float) (y : float) : wall list =
  let rx = round (x /. map.division) and ry = round (y /. map.division) in
  if rx > -map.num && rx < map.num && ry > -map.num && ry < map.num then
    Array.fold_right (fun w acc -> map.walls.(w) :: acc) map.sectors.(((rx + map.num) * ((2 * map.num) + 1)) + ry + map.num) []
  else []

(* PointInPoly: on the same side of the three edges *)
let in_wall ((px, py) : float * float) (w : wall) : bool =
  let (ax, ay) = w.a and (bx, by) = w.b and (cx, cy) = w.c in
  let ap_x = px -. ax and ap_y = py -. ay in
  let p_ab = ((bx -. ax) *. ap_y) -. ((by -. ay) *. ap_x) > 0. in
  let p_ac = ((cx -. ax) *. ap_y) -. ((cy -. ay) *. ap_x) > 0. in
  p_ac <> p_ab && ((cx -. bx) *. (py -. by)) -. ((cy -. by) *. (px -. bx)) > 0. = p_ab

(* PointInPolyEdges: on the inner side of the three perps *)
let in_edges ((px, py) : float * float) (w : wall) : bool =
  let inner (vx, vy) (nx, ny) = (nx *. (px -. vx)) +. (ny *. (py -. vy)) >= 0. in
  inner w.a w.perps.(0) && inner w.b w.perps.(1) && inner w.c w.perps.(2)

let point_line_distance ((x1, y1) : float * float) ((x2, y2) : float * float) ((x3, y3) : float * float) : float =
  let u = (((x3 -. x1) *. (x2 -. x1)) +. ((y3 -. y1) *. (y2 -. y1))) /. Float.max Float.min_float (((x2 -. x1) ** 2.) +. ((y2 -. y1) ** 2.)) in
  Float.hypot (x1 +. (u *. (x2 -. x1)) -. x3) (y1 +. (u *. (y2 -. y1)) -. y3)

(* ClosestPerpendicular: the first edge unless the second is nearer,
 * the third only if nearer than both *)
let closest_perp (w : wall) (p : float * float) : (float * float) * float * int =
  let d1 = point_line_distance w.a w.b p and d2 = point_line_distance w.b w.c p and d3 = point_line_distance w.c w.a p in
  if d3 < d2 && d3 < d1 then (w.perps.(2), d3, 3) else if d2 < d1 then (w.perps.(1), d2, 2) else (w.perps.(0), d1, 1)

let in_bullet_wall (map : t) ((x, y) : float * float) : bool =
  List.exists (fun (w : wall) -> stops_bullet w.kind && in_wall (x, y) w) (sector map x y)

let clear (map : t) ((ax, ay) : float * float) ((bx, by) : float * float) : bool =
  let steps = max 1 (int_of_float (Float.hypot (bx -. ax) (by -. ay) /. 4.)) in
  let rec go i =
    i > steps
    ||
    let t = float_of_int i /. float_of_int steps in
    (not (in_bullet_wall map (ax +. ((bx -. ax) *. t), ay +. ((by -. ay) *. t)))) && go (i + 1)
  in
  go 0

let edge (map : t) : float = (float_of_int map.num *. map.division) -. 50.

(*****************************************************************************)
(* One of Soldat's *)
(*****************************************************************************)

(* "banana.bmp", "Banana.PNG": banana *)
let stem (file : string) : string =
  String.lowercase_ascii (match String.rindex_opt file '.' with Some i -> String.sub file 0 i | None -> file)

(* the sky, from [top] to [bottom] over the height Soldat grades it
 * over, 25 sectors each way from the middle, in 64 bands (the
 * Playground has no gradient), the two ends going on far above and
 * below. In the picture's coordinates: y upwards *)
let sky (top : Pms.color) (bottom : Pms.color) (division : float) : shape list =
  let bands = 64 in
  let d = 25. *. Float.max division 10. in
  let width = 40000. and height = 2. *. d in
  let mix a b t = int_of_float (Float.round (float_of_int a +. ((float_of_int b -. float_of_int a) *. t))) in
  let color t = rgb (mix top.r bottom.r t) (mix top.g bottom.g t) (mix top.b bottom.b t) in
  [ rectangle (color 0.) width 20000. |> move 0. (d +. 10000.); rectangle (color 1.) width 20000. |> move 0. (-.d -. 10000.) ]
  @ List.init bands (fun i ->
        let t = (float_of_int i +. 0.5) /. float_of_int bands in
        (* more than its share, each over the one before: no seam
         * between two bands, whatever draws them *)
        rectangle (color t) width ((height /. float_of_int bands) +. 6.) |> move 0. (d -. (height *. t) -. 3.))

(* Vec2Normalize: nothing of a vector too short to have a direction *)
let normalized ((x, y) : float * float) : float * float =
  let l = Float.hypot x y in
  if l < 0.001 then (0., 0.) else (x /. l, y /. l)

let of_pms (pms : Pms.t) : t =
  let (tr, tg, tb) = Option.value (List.assoc_opt (stem pms.texture) Texture_tints.all) ~default:(128, 128, 128) in
  let walls =
    Array.map
      (fun (p : Pms.polygon) ->
        let perp i = let (x, y, _) = p.perps.(i) in (x, y) in
        {
          a = (p.a.x, p.a.y); b = (p.b.x, p.b.y); c = (p.c.x, p.c.y);
          perps = [| normalized (perp 0); normalized (perp 1); normalized (perp 2) |];
          bounciness = (let (x, y) = perp 2 in Float.hypot x y);
          kind = p.kind;
        })
      pms.polygons
  in
  (* a polygon's picture: nothing when its corners are all transparent *)
  let shape (p : Pms.polygon) : shape option =
    let tinted tint part = (part p.a.color + part p.b.color + part p.c.color) * tint / (3 * 255) in
    let color = rgb (tinted tr (fun (c : Pms.color) -> c.r)) (tinted tg (fun (c : Pms.color) -> c.g)) (tinted tb (fun (c : Pms.color) -> c.b)) in
    let alpha = p.a.color.a + p.b.color.a + p.c.color.a in
    let corners = [ (p.a.x, -.p.a.y); (p.b.x, -.p.b.y); (p.c.x, -.p.c.y) ] in
    if alpha = 0 then None else if alpha = 3 * 255 then Some (polygon color corners) else Some (polygon color corners |> fade (float_of_int alpha /. 765.))
  in
  let is_back (kind : Pms.kind) = match kind with Background | Background_transition -> true | _ -> false in
  let shapes_where keep = Array.to_list pms.polygons |> List.filter_map (fun (p : Pms.polygon) -> if keep p.kind then shape p else None) in
  (* where anyone may appear (team 0); a map for teams only: wherever a
   * team does; none at all: its middle *)
  let spawns_of keep =
    Array.to_list pms.spawnpoints
    |> List.filter_map (fun (s : Pms.spawnpoint) -> if s.active && keep s.team then Some (float_of_int s.x, float_of_int s.y) else None)
  in
  let spawns =
    match (spawns_of (fun team -> team = 0), spawns_of (fun team -> team >= 1 && team <= 4)) with
    | (_ :: _ as anyone), _ -> anyone
    | [], (_ :: _ as teams) -> teams
    | [], [] -> [ (0., 0.) ]
  in
  let division = float_of_int pms.sectors_division in
  {
    name = pms.name;
    pms = Some pms;
    sky = sky pms.sky_top pms.sky_bottom division;
    back = shapes_where is_back;
    front = shapes_where (fun kind -> not (is_back kind));
    walls;
    division;
    num = pms.sectors_num;
    (* the file numbers its polygons from 1 *)
    sectors = Array.map (fun polys -> Array.of_list (List.filter_map (fun n -> if n >= 1 && n <= Array.length walls then Some (n - 1) else None) (Array.to_list polys))) pms.sectors;
    (* a bullet meets a collider at its radius over 1.7
     * (TBullet.CheckColliderCollision) *)
    colliders = Array.to_list pms.colliders |> List.filter_map (fun (c : Pms.collider) -> if c.active then Some ((c.x, c.y), c.radius /. 1.7) else None);
    spawns;
    (* PolyMap.LoadData's "quickfix" *)
    jet = 119 * pms.jet / 100;
    waypoints = pms.waypoints;
    medikits = pms.medikits;
    grenade_kits = pms.grenade_packs;
    (* the spawn points of "teams" 8 and 7 (SpawnThings) *)
    medikit_spawns = spawns_of (fun team -> team = 8);
    grenade_spawns = spawns_of (fun team -> team = 7);
    (* the two teams' own places, and their flags' (5 and 6) *)
    alpha_spawns = spawns_of (fun team -> team = 1);
    bravo_spawns = spawns_of (fun team -> team = 2);
    alpha_flag = List.nth_opt (spawns_of (fun team -> team = 5)) 0;
    bravo_flag = List.nth_opt (spawns_of (fun team -> team = 6)) 0;
  }

let arena2 : t Lazy.t =
  lazy
    (match Pms.parse (Base64.decode Map_arena2.base64) with
    | Ok pms -> of_pms pms
    | Error why -> failwith ("data/maps/Arena2.pms: " ^ why))
