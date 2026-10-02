(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_raster.mli. The loops below run once for each pixel of a
 * tile and each thing over it, in a browser too: they read and write
 * the pixels' bytes directly, and make no value on the way. *)

type tile = { image : Rgba_image.t; left : float; top : float; scale : float }
type corner = { x : float; y : float; u : float; v : float; r : float; g : float; b : float; a : float }

let tile ~(left : float) ~(top : float) ~(scale : float) ~(pixels : int) : tile =
  let image = Rgba_image.create ~width:pixels ~height:pixels in
  Bigarray.Array1.fill image.rgba 0;
  { image; left; top; scale }

let get = Bigarray.Array1.unsafe_get
let set = Bigarray.Array1.unsafe_set

(* a colour (0 to 255 each, as floats) over the pixel at [at] *)
let over (px : (int, Bigarray.int8_unsigned_elt, Bigarray.c_layout) Bigarray.Array1.t) (at : int) (r : float) (g : float) (b : float) (a : float) : unit =
  if a >= 254.5 then begin
    set px at (int_of_float r);
    set px (at + 1) (int_of_float g);
    set px (at + 2) (int_of_float b);
    set px (at + 3) 255
  end
  else if a > 0.5 then begin
    let sa = a /. 255. in
    let da = float_of_int (get px (at + 3)) /. 255. in
    let out = sa +. (da *. (1. -. sa)) in
    let mix s d = int_of_float (((s *. sa) +. (float_of_int d *. da *. (1. -. sa))) /. out) in
    set px at (mix r (get px at));
    set px (at + 1) (mix g (get px (at + 1)));
    set px (at + 2) (mix b (get px (at + 2)));
    set px (at + 3) (int_of_float (out *. 255.))
  end

(* x mod n, never negative *)
let wrap (x : int) (n : int) : int =
  let m = x mod n in
  if m < 0 then m + n else m

let triangle (t : tile) (texture : Rgba_image.t option) (a : corner) (b : corner) (c : corner) : unit =
  let size = t.image.width in
  let px = t.image.rgba in
  (* the corners, in the tile's pixels *)
  let ax = (a.x -. t.left) *. t.scale and ay = (a.y -. t.top) *. t.scale in
  let bx = (b.x -. t.left) *. t.scale and by = (b.y -. t.top) *. t.scale in
  let cx = (c.x -. t.left) *. t.scale and cy = (c.y -. t.top) *. t.scale in
  let area = ((bx -. ax) *. (cy -. ay)) -. ((by -. ay) *. (cx -. ax)) in
  if Float.abs area > 1e-6 then begin
    let lo v = max 0 (int_of_float (Float.floor v)) and hi v = min (size - 1) (int_of_float (Float.ceil v)) in
    let x0 = lo (Float.min ax (Float.min bx cx)) and x1 = hi (Float.max ax (Float.max bx cx)) in
    let y0 = lo (Float.min ay (Float.min by cy)) and y1 = hi (Float.max ay (Float.max by cy)) in
    let (tw, th, tpx) = match texture with Some i -> (i.width, i.height, i.rgba) | None -> (1, 1, px) in
    let textured = texture <> None in
    let ftw = float_of_int tw and fth = float_of_int th in
    for y = y0 to y1 do
      let py = float_of_int y +. 0.5 in
      for x = x0 to x1 do
        let ppx = float_of_int x +. 0.5 in
        (* the weights of a, b and c: the three small triangles' areas
         * over the whole one's *)
        let wa = (((bx -. ppx) *. (cy -. py)) -. ((by -. py) *. (cx -. ppx))) /. area in
        let wb = (((cx -. ppx) *. (ay -. py)) -. ((cy -. py) *. (ax -. ppx))) /. area in
        let wc = 1. -. wa -. wb in
        if wa >= 0. && wb >= 0. && wc >= 0. then begin
          let r = (wa *. a.r) +. (wb *. b.r) +. (wc *. c.r) in
          let g = (wa *. a.g) +. (wb *. b.g) +. (wc *. c.g) in
          let bl = (wa *. a.b) +. (wb *. b.b) +. (wc *. c.b) in
          let al = (wa *. a.a) +. (wb *. b.a) +. (wc *. c.a) in
          let at = ((y * size) + x) * 4 in
          if textured then begin
            let u = (wa *. a.u) +. (wb *. b.u) +. (wc *. c.u) and v = (wa *. a.v) +. (wb *. b.v) +. (wc *. c.v) in
            let tx = wrap (int_of_float (Float.floor (u *. ftw))) tw and ty = wrap (int_of_float (Float.floor (v *. fth))) th in
            let from = ((ty * tw) + tx) * 4 in
            over px at
              (float_of_int (get tpx from) *. r /. 255.)
              (float_of_int (get tpx (from + 1)) *. g /. 255.)
              (float_of_int (get tpx (from + 2)) *. bl /. 255.)
              (float_of_int (get tpx (from + 3)) *. al /. 255.)
          end
          else over px at r g bl al
        end
      done
    done
  end

(* GfxMat3Transform with a centre of (0, 1) and the angle -rotation
 * (client/MapGraphics.pas): a point (lx, ly) of the rectangle goes to
 *   (x, y + 1) + turned by -rotation (sx lx, sy ly - 1) *)
let sprite_point ~x ~y ~sx ~sy ~rotation (lx : float) (ly : float) : float * float =
  let c = cos (-.rotation) and s = sin (-.rotation) in
  let qx = sx *. lx and qy = (sy *. ly) -. 1. in
  (x +. (c *. qx) -. (s *. qy), y +. 1. +. (s *. qx) +. (c *. qy))

let sprite_corners ~x ~y ~w ~h ~sx ~sy ~rotation : (float * float) list =
  let p = sprite_point ~x ~y ~sx ~sy ~rotation in
  [ p 0. 0.; p w 0.; p w h; p 0. h ]

let sprite (t : tile) (picture : Rgba_image.t) ~x ~y ~w ~h ~sx ~sy ~rotation ~(color : int * int * int * int) : unit =
  if w > 0. && h > 0. && Float.abs sx > 1e-6 && Float.abs sy > 1e-6 then begin
    let size = t.image.width in
    let px = t.image.rgba and from = picture.rgba in
    let pw = picture.width and ph = picture.height in
    let (cr, cg, cb, ca) = color in
    let cr = float_of_int cr /. 255. and cg = float_of_int cg /. 255. and cb = float_of_int cb /. 255. and ca = float_of_int ca /. 255. in
    (* what it covers of the tile *)
    let corners = List.map (fun (cx, cy) -> ((cx -. t.left) *. t.scale, (cy -. t.top) *. t.scale)) (sprite_corners ~x ~y ~w ~h ~sx ~sy ~rotation) in
    let least f = List.fold_left (fun m p -> Float.min m (f p)) infinity corners and most f = List.fold_left (fun m p -> Float.max m (f p)) neg_infinity corners in
    let x0 = max 0 (int_of_float (Float.floor (least fst))) and x1 = min (size - 1) (int_of_float (Float.ceil (most fst))) in
    let y0 = max 0 (int_of_float (Float.floor (least snd))) and y1 = min (size - 1) (int_of_float (Float.ceil (most snd))) in
    (* back from the map to the rectangle: turned the other way *)
    let c = cos rotation and s = sin rotation in
    for py = y0 to y1 do
      let wy = t.top +. ((float_of_int py +. 0.5) /. t.scale) -. y -. 1. in
      for ppx = x0 to x1 do
        let wx = t.left +. ((float_of_int ppx +. 0.5) /. t.scale) -. x in
        let lx = ((c *. wx) -. (s *. wy)) /. sx and ly = (((s *. wx) +. (c *. wy)) +. 1.) /. sy in
        if lx >= 0. && lx < w && ly >= 0. && ly < h then begin
          let fx = min (pw - 1) (int_of_float (lx /. w *. float_of_int pw)) and fy = min (ph - 1) (int_of_float (ly /. h *. float_of_int ph)) in
          let at = ((fy * pw) + fx) * 4 in
          let a = float_of_int (get from (at + 3)) *. ca in
          if a > 0.5 then
            over px (((py * size) + ppx) * 4) (float_of_int (get from at) *. cr) (float_of_int (get from (at + 1)) *. cg) (float_of_int (get from (at + 2)) *. cb) a
        end
      done
    done
  end

let halved (picture : Rgba_image.t) : Rgba_image.t =
  let width = max 1 (picture.width / 2) and height = max 1 (picture.height / 2) in
  let out = Rgba_image.create ~width ~height in
  let at x y k = get picture.rgba ((((min (picture.height - 1) y * picture.width) + min (picture.width - 1) x) * 4) + k) in
  for y = 0 to height - 1 do
    for x = 0 to width - 1 do
      for k = 0 to 3 do
        let sum = at (2 * x) (2 * y) k + at ((2 * x) + 1) (2 * y) k + at (2 * x) ((2 * y) + 1) k + at ((2 * x) + 1) ((2 * y) + 1) k in
        set out.rgba ((((y * width) + x) * 4) + k) (sum / 4)
      done
    done
  done;
  out
