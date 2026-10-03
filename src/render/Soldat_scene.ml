(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_scene.mli *)
open Playground

let side = 256.
let pixels = 512
let scale = float_of_int pixels /. side

(* a tile: nothing of the map in its square, or its picture *)
type drawn = Empty | Picture of Rgba_image.t

(* which tile: in front or behind, and its column and row *)
type key = bool * int * int

(* what is kept for a map: its tiles, and its texture once it came, at
 * the size it is drawn at *)
type t = {
  tiles : (key, drawn) Hashtbl.t;
  mutable texture : Rgba_image.t option;
  (* the whole map as a small picture, once it was asked for: the
   * picture, the map's left and top, and how many pixels a unit is *)
  mutable mini : (Rgba_image.t * float * float * float) option;
}

(* the maps drawn so far: by themselves. A game plays one at a time,
 * and the last few are enough *)
let scenes : (Soldat_map.t * t) list ref = ref []

let scene (map : Soldat_map.t) : t =
  match List.find_opt (fun (m, _) -> m == map) !scenes with
  | Some (_, s) -> s
  | None ->
      let s = { tiles = Hashtbl.create 64; texture = None; mini = None } in
      scenes := List.filteri (fun i _ -> i < 2) ((map, s) :: !scenes);
      s

let drawn (map : Soldat_map.t) : int = Hashtbl.length (scene map).tiles

let is_back (kind : Pms.kind) : bool = match kind with Background | Background_transition -> true | _ -> false

(*****************************************************************************)
(* What a map needs *)
(*****************************************************************************)

(* the scenery's picture for a prop: its style is its place in the
 * map's list, from 1 *)
let prop_picture (pms : Pms.t) (p : Pms.prop) : Rgba_image.t Soldat_assets.asked =
  if p.style >= 1 && p.style <= Array.length pms.scenery then Soldat_assets.picture ~keyed:true "scenery-gfx" pms.scenery.(p.style - 1) else Missing

let shown (p : Pms.prop) : bool = p.active && p.level <= 2

(* everything the map's picture needs has come, or will not: asked for
 * on the way *)
let settled (pms : Pms.t) : bool =
  let texture = Soldat_assets.picture ~keyed:false "textures" pms.texture <> Loading in
  (* every one is asked for, even after a first that has not come *)
  Array.fold_left (fun ok p -> ((not (shown p)) || prop_picture pms p <> Loading) && ok) texture pms.props

(*****************************************************************************)
(* Drawing a tile *)
(*****************************************************************************)

let corner (v : Pms.vertex) : Soldat_raster.corner =
  { x = v.x; y = v.y; u = v.u; v = v.v; r = float_of_int v.color.r; g = float_of_int v.color.g; b = float_of_int v.color.b; a = float_of_int v.color.a }

(* a square and a thing's bounds meet *)
let meets (left, top, right, bottom) (points : (float * float) list) : bool =
  let least f = List.fold_left (fun m p -> Float.min m (f p)) infinity points and most f = List.fold_left (fun m p -> Float.max m (f p)) neg_infinity points in
  least fst <= right && most fst >= left && least snd <= bottom && most snd >= top

let draw (s : t) (pms : Pms.t) ((front, column, row) : key) : drawn =
  (* a pixel more on each side *)
  let margin = 1. /. scale in
  let left = (float_of_int column *. side) -. margin and top = (float_of_int row *. side) -. margin in
  let square = (left, top, left +. side +. (2. *. margin), top +. side +. (2. *. margin)) in
  let polygons =
    Array.to_list pms.polygons
    |> List.filter (fun (p : Pms.polygon) ->
           is_back p.kind <> front
           && p.a.color.a + p.b.color.a + p.c.color.a > 0
           && meets square [ (p.a.x, p.a.y); (p.b.x, p.b.y); (p.c.x, p.c.y) ])
  in
  let props (level : int) : (Pms.prop * Rgba_image.t) list =
    Array.to_list pms.props
    |> List.filter_map (fun (p : Pms.prop) ->
           if shown p && p.level = level then
             match prop_picture pms p with
             | Here picture
               when meets square
                      (Soldat_raster.sprite_corners ~x:p.x ~y:p.y ~w:(float_of_int p.width) ~h:(float_of_int p.height) ~sx:p.scale_x ~sy:p.scale_y ~rotation:p.rotation) ->
                 Some (p, picture)
             | _ -> None
           else None)
  in
  let layers = if front then [ props 1; props 2 ] else [ props 0 ] in
  if polygons = [] && List.for_all (fun l -> l = []) layers then Empty
  else begin
    let tile = Soldat_raster.tile ~left ~top ~scale ~pixels:(pixels + 2) in
    let sprites =
      List.iter (fun ((p : Pms.prop), picture) ->
          Soldat_raster.sprite tile picture ~x:p.x ~y:p.y ~w:(float_of_int p.width) ~h:(float_of_int p.height) ~sx:p.scale_x ~sy:p.scale_y ~rotation:p.rotation
            ~color:(p.color.r, p.color.g, p.color.b, p.alpha))
    in
    let triangles () = List.iter (fun (p : Pms.polygon) -> Soldat_raster.triangle tile s.texture (corner p.a) (corner p.b) (corner p.c)) polygons in
    (match layers with
    | [ behind; over ] ->
        sprites behind;
        triangles ();
        sprites over
    | _ ->
        triangles ();
        List.iter sprites layers);
    Picture tile.image
  end

(*****************************************************************************)
(* A frame *)
(*****************************************************************************)

(* a tile's picture, where its square is: the picture's y goes up *)
let shape ((_, column, row) : key) (image : Rgba_image.t) : shape =
  let size = float_of_int (pixels + 2) /. scale in
  bitmap size size image |> move ((float_of_int column +. 0.5) *. side) (-.(float_of_int row +. 0.5) *. side)

(* at most this many tiles kept for a map: those farthest from the
 * camera go first *)
let kept = 96

let view (map : Soldat_map.t) ~(centre : float * float) ~(half : float * float) : shape list * shape list =
  match map.pms with
  | None -> (map.back, map.front)
  | Some pms when not (settled pms) -> (map.back, map.front)
  | Some pms ->
      let s = scene map in
      (* the texture, once: at half its size, 4 of its pixels being a
       * unit and 2 of a tile's *)
      (if s.texture = None then
         match Soldat_assets.picture ~keyed:false "textures" pms.texture with Here t -> s.texture <- Some (Soldat_raster.halved t) | _ -> ());
      let (cx, cy) = centre and (hx, hy) = half in
      let tile_of v = int_of_float (Float.floor (v /. side)) in
      let keys ~(beyond : float) : key list =
        let columns = List.init (tile_of (cx +. hx +. beyond) - tile_of (cx -. hx -. beyond) + 1) (fun i -> tile_of (cx -. hx -. beyond) + i) in
        let rows = List.init (tile_of (cy +. hy +. beyond) - tile_of (cy -. hy -. beyond) + 1) (fun i -> tile_of (cy -. hy -. beyond) + i) in
        List.concat_map (fun column -> List.concat_map (fun row -> [ (false, column, row); (true, column, row) ]) rows) columns
      in
      (* how far a tile's middle is from the camera's *)
      let far ((_, column, row) : key) = Float.hypot (((float_of_int column +. 0.5) *. side) -. cx) (((float_of_int row +. 0.5) *. side) -. cy) in
      let nearest keys = List.sort (fun a b -> compare (far a) (far b)) keys in
      let missing keys = List.filter (fun k -> not (Hashtbl.mem s.tiles k)) keys in
      (* two of those on the screen, the nearest first; else one of
       * those just beyond it, ahead of need *)
      (match nearest (missing (keys ~beyond:0.)) with
      | [] -> ( match nearest (missing (keys ~beyond:side)) with k :: _ -> Hashtbl.replace s.tiles k (draw s pms k) | [] -> ())
      | on_screen -> List.iteri (fun i k -> if i < 2 then Hashtbl.replace s.tiles k (draw s pms k)) on_screen);
      (* too many kept: the farthest thrown away *)
      if Hashtbl.length s.tiles > kept then begin
        let by_distance = List.sort (fun a b -> compare (far b) (far a)) (List.of_seq (Hashtbl.to_seq_keys s.tiles)) in
        List.iteri (fun i k -> if i < Hashtbl.length s.tiles - kept then Hashtbl.remove s.tiles k) by_distance
      end;
      let on_screen = keys ~beyond:0. in
      let tiles (front : bool) : shape list =
        List.filter_map (fun ((f, _, _) as k) -> if f = front then match Hashtbl.find_opt s.tiles k with Some (Picture image) -> Some (shape k image) | _ -> None else None) on_screen
      in
      (* a tile of the screen not drawn yet: the flat map under the
       * others, for this frame *)
      if missing on_screen = [] then (tiles false, tiles true) else (map.back @ tiles false, map.front @ tiles true)

(*****************************************************************************)
(* The minimap *)
(*****************************************************************************)

(* MINIMAP (MapGraphics.pas:774): its width and its height make 260 of
 * a screen 640 wide: 406 of the 1000 units here, a pixel a unit *)
let mini_size = 260. *. 1000. /. 640.

let minimap (map : Soldat_map.t) : (Rgba_image.t * float * float * float) option =
  let s = scene map in
  match (s.mini, map.pms) with
  | (Some mini, _) -> Some mini
  | (None, None) -> None
  | (None, Some pms) when Array.length pms.polygons = 0 -> None
  | (None, Some pms) ->
      (* the map's bounds: its polygons' *)
      let corners = Array.to_list pms.polygons |> List.concat_map (fun (p : Pms.polygon) -> [ p.a; p.b; p.c ]) in
      let least f = List.fold_left (fun m (v : Pms.vertex) -> Float.min m (f v)) infinity corners and most f = List.fold_left (fun m (v : Pms.vertex) -> Float.max m (f v)) neg_infinity corners in
      let (left, top) = (least (fun v -> v.x), least (fun v -> v.y)) in
      let (width, height) = (most (fun v -> v.x) -. left, most (fun v -> v.y) -. top) in
      let scale = mini_size /. Float.max 1. (width +. height) in
      (* every polygon in its corners' colours, no texture, the ones
       * behind first; as dark as Soldat's, a little see-through *)
      let tile = Soldat_raster.tile ~left ~top ~scale ~pixels:(1 + int_of_float (scale *. Float.max width height)) in
      let draw (front : bool) =
        Array.iter (fun (p : Pms.polygon) -> if is_back p.kind <> front then Soldat_raster.triangle tile None (corner p.a) (corner p.b) (corner p.c)) pms.polygons
      in
      draw false;
      draw true;
      let mini = (tile.image, left, top, scale) in
      s.mini <- Some mini;
      Some mini
