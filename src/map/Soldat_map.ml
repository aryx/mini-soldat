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
open Basics (* float arithmetics *)

type t = {
  name : string;
  back : shape list;
  front : shape list;
  walls : (number * number) list list;
  bodies : Physics.body list;
  bullet_walls : (number * number) list list;
  bullet_bodies : Physics.body list;
  spawns : (number * number) list;
  bounds : Camera2d.rect;
}

let scale = 2.
let gravity = 800.

let body_of (corners : (number * number) list) : Physics.body =
  Physics.body (polygon black corners) |> Physics.immovable |> Physics.rough 0.6

let clear (map : t) (a : number * number) (b : number * number) : bool =
  List.for_all (fun corners -> Collide.segment_polygon (a, b) corners = None) map.bullet_walls

(*****************************************************************************)
(* The toy *)
(*****************************************************************************)

let box (x : number) (y : number) (w : number) (h : number) : (number * number) list =
  [ (x - (w / 2.), y - (h / 2.)); (x + (w / 2.), y - (h / 2.)); (x + (w / 2.), y + (h / 2.)); (x - (w / 2.), y + (h / 2.)) ]

(* convex polygons, counterclockwise, in the screen's coordinates: hills,
 * the side walls, platforms, a bunker *)
let toy_polygons : (number * number) list list =
  [ [ (-500., -500.); (-250., -500.); (-250., -330.); (-500., -300.) ];
    [ (-250., -500.); (0., -500.); (0., -380.); (-250., -330.) ];
    [ (0., -500.); (250., -500.); (250., -320.); (0., -380.) ];
    [ (250., -500.); (500., -500.); (500., -280.); (250., -320.) ];
    box (-510.) 0. 40. 1000.;
    box 510. 0. 40. 1000.;
    box (-300.) (-130.) 180. 20.;
    box 280. (-110.) 200. 20.;
    box 0. 50. 240. 20.;
    [ (-60., -390.); (60., -390.); (35., -310.); (-35., -310.) ];
    box (-320.) 220. 160. 20.;
    box 320. 230. 160. 20. ]

let toy : t =
  let bodies = List.map body_of toy_polygons in
  {
    name = "toy";
    (* a sky bigger than any window *)
    back = [ rectangle (rgb 120 160 200) 8000. 8000. ];
    front = List.map (polygon (rgb 110 90 70)) toy_polygons;
    walls = toy_polygons;
    bodies;
    bullet_walls = toy_polygons;
    bullet_bodies = bodies;
    spawns = [ (-400., -250.); (400., -230.); (0., 100.); (-320., 260.); (320., 270.) ];
    (* a screen of 1000 by 1000: the camera stays put *)
    bounds = { left = -500.; right = 500.; bottom = -500.; top = 500. };
  }

(*****************************************************************************)
(* One of Soldat's *)
(*****************************************************************************)

let stops_soldier (kind : Pms.kind) : bool =
  match kind with
  | Normal | Only_players | Ice | Deadly | Bloody_deadly | Hurts | Regenerates | Lava | Bouncy | Explodes | Hurts_flaggers
  | Not_flaggers | Non_flagger_collides ->
      true
  | Only_bullets | No_collide | Team_bullets _ | Team_players _ | Only_flaggers | Background | Background_transition | Unknown _ -> false

let stops_bullet (kind : Pms.kind) : bool =
  match kind with
  | Normal | Only_bullets | Ice | Deadly | Bloody_deadly | Hurts | Regenerates | Lava | Bouncy | Explodes | Hurts_flaggers -> true
  | Only_players | No_collide | Team_bullets _ | Team_players _ | Only_flaggers | Not_flaggers | Non_flagger_collides | Background
  | Background_transition | Unknown _ ->
      false

(* Soldat's point, in the game: twice as big, y turned over *)
let point (x : float) (y : float) : number * number = (scale * x, -.scale * y)

(* twice the area of the triangle, positive when a, b, c turn
 * counterclockwise *)
let area2 ((ax, ay) : number * number) ((bx, by) : number * number) ((cx, cy) : number * number) : number =
  ((bx - ax) * (cy - ay)) - ((cx - ax) * (by - ay))

(* "banana.bmp", "Banana.PNG": banana *)
let stem (file : string) : string =
  String.lowercase_ascii (match String.rindex_opt file '.' with Some i -> String.sub file 0 i | None -> file)

(* a sky from [top] to [bottom] in bands, the Playground having no
 * gradient: 64 of them over the map's height, and the two ends going
 * on far above and below *)
let sky (top : Pms.color) (bottom : Pms.color) (bounds : Camera2d.rect) : shape list =
  let bands = 64 in
  let width = bounds.right - bounds.left + 8000. and height = bounds.top - bounds.bottom in
  let x = (bounds.left + bounds.right) / 2. in
  let mix a b t = int_of_float (Float.round (float_of_int a + ((float_of_int b - float_of_int a) * t))) in
  let color t = rgb (mix top.r bottom.r t) (mix top.g bottom.g t) (mix top.b bottom.b t) in
  [ rectangle (color 0.) width 4000. |> move x (bounds.top + 2000.); rectangle (color 1.) width 4000. |> move x (bounds.bottom - 2000.) ]
  @ List.init bands (fun i ->
        let t = (float_of_int i + 0.5) / float_of_int bands in
        (* a pixel more than its share: no seam between two bands *)
        rectangle (color t) width ((height / float_of_int bands) + 1.) |> move x (bounds.top - (height * t)))

let of_pms (pms : Pms.t) : t =
  let (tr, tg, tb) = Option.value (List.assoc_opt (stem pms.texture) Texture_tints.all) ~default:(128, 128, 128) in
  (* each polygon: its corners counterclockwise, what it looks like
   * (nothing, when its corners are all transparent: a wall one cannot
   * see), its kind; those with no area dropped *)
  let polygons =
    Array.to_list pms.polygons
    |> List.filter_map (fun (p : Pms.polygon) ->
           let a = point p.a.x p.a.y and b = point p.b.x p.b.y and c = point p.c.x p.c.y in
           let area = area2 a b c in
           if Float.abs area < 1e-3 then None
           else
             let corners = if area > 0. then [ a; b; c ] else [ a; c; b ] in
             let tinted tint part = (part p.a.color +.. part p.b.color +.. part p.c.color) *.. tint /.. (3 *.. 255) in
             let color = rgb (tinted tr (fun (c : Pms.color) -> c.r)) (tinted tg (fun (c : Pms.color) -> c.g)) (tinted tb (fun (c : Pms.color) -> c.b)) in
             let alpha = p.a.color.a +.. p.b.color.a +.. p.c.color.a in
             let shape =
               if alpha = 0 then None
               else if alpha = 3 *.. 255 then Some (polygon color corners)
               else Some (polygon color corners |> fade (float_of_int alpha / 765.))
             in
             Some (corners, shape, p.kind))
  in
  let corners_where keep = List.filter_map (fun (corners, _, kind) -> if keep kind then Some corners else None) polygons in
  let is_back (kind : Pms.kind) = match kind with Background | Background_transition -> true | _ -> false in
  let shapes_where keep = List.filter_map (fun (_, shape, kind) -> if keep kind then shape else None) polygons in
  let all = List.concat_map (fun (corners, _, _) -> corners) polygons in
  let over f init = List.fold_left f init all in
  let bounds : Camera2d.rect =
    match all with
    | [] -> { left = -500.; right = 500.; bottom = -500.; top = 500. }
    | (x, y) :: _ ->
        { left = over (fun m (x, _) -> Float.min m x) x; right = over (fun m (x, _) -> Float.max m x) x;
          bottom = over (fun m (_, y) -> Float.min m y) y; top = over (fun m (_, y) -> Float.max m y) y }
  in
  let walls = corners_where stops_soldier and bullet_walls = corners_where stops_bullet in
  (* where anyone may appear (team 0); a map for teams only: wherever a
   * team does; none at all: its middle *)
  let spawns_of keep =
    Array.to_list pms.spawnpoints
    |> List.filter_map (fun (s : Pms.spawnpoint) -> if s.active && keep s.team then Some (point (float_of_int s.x) (float_of_int s.y)) else None)
  in
  let spawns =
    match (spawns_of (fun team -> team = 0), spawns_of (fun team -> team >= 1 && team <= 4)) with
    | (_ :: _ as anyone), _ -> anyone
    | [], (_ :: _ as teams) -> teams
    | [], [] -> [ ((bounds.left + bounds.right) / 2., (bounds.bottom + bounds.top) / 2.) ]
  in
  {
    name = pms.name;
    back = sky pms.sky_top pms.sky_bottom bounds @ shapes_where is_back;
    front = shapes_where (fun kind -> not (is_back kind));
    walls;
    bodies = List.map body_of walls;
    bullet_walls;
    bullet_bodies = List.map body_of bullet_walls;
    spawns;
    bounds;
  }

let arena2 : t Lazy.t =
  lazy
    (match Pms.parse (Base64.decode Map_arena2.base64) with
    | Ok pms -> of_pms pms
    | Error why -> failwith ("data/maps/Arena2.pms: " ^ why))
