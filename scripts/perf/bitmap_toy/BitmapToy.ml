(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* A toy to see what a picture costs a backend (docs/architecture.md,
 * "A picture's way to the screen"): n small pictures, each its own,
 * going round in a circle. Nothing changes from a frame to the next
 * but where they are: the same n pictures, the very same values.
 *
 *   dune exec scripts/perf/bitmap_toy/BitmapToy.exe -- n=64
 *   http://localhost:8001/index.html?n=64     (see its dune)
 *
 * A backend has to turn each picture into something it can draw (a
 * Cairo surface, a PNG for SVG), which costs far more than drawing it,
 * and so keeps what it made. While it keeps them all, n can grow and a
 * frame stays cheap. A backend that keeps the last 32 does n = 32 at
 * full speed, and at n = 33 makes pictures again every frame: this is
 * what mini-soldat ran into in a browser (docs/plan.md).
 *)
open Playground

(* a picture of 32 by 32 pixels, of a colour of its own, darker towards
 * its edges *)
let picture (i : int) (n : int) : Rgba_image.t =
  let image = Rgba_image.create ~width:32 ~height:32 in
  let hue = float_of_int i /. float_of_int n *. 6.283 in
  let channel shift = int_of_float (127. +. (127. *. cos (hue +. shift))) in
  let (r, g, b) = (channel 0., channel 2.094, channel 4.188) in
  for y = 0 to 31 do
    for x = 0 to 31 do
      let d = Float.hypot (float_of_int x -. 15.5) (float_of_int y -. 15.5) /. 22. in
      let at = ((y * 32) + x) * 4 in
      let shade v = int_of_float (float_of_int v *. (1. -. (d *. 0.6))) in
      Bigarray.Array1.set image.rgba at (shade r);
      Bigarray.Array1.set image.rgba (at + 1) (shade g);
      Bigarray.Array1.set image.rgba (at + 2) (shade b);
      Bigarray.Array1.set image.rgba (at + 3) 255
    done
  done;
  image

(* the model: the pictures, made once *)
let pictures (flags : (string * string) list) : Rgba_image.t array =
  let n = match Option.bind (List.assoc_opt "n" flags) int_of_string_opt with Some n when n > 0 -> n | _ -> 64 in
  Array.init n (fun i -> picture i n)

let view (computer : computer) (pictures : Rgba_image.t array) : shape list =
  let n = Array.length pictures in
  let t = match computer.time with Time t -> t in
  rectangle (rgb 30 30 40) computer.screen.width computer.screen.height
  :: words white (Printf.sprintf "%d pictures" n)
  :: Array.to_list
       (Array.mapi
          (fun i image ->
            let a = (float_of_int i /. float_of_int n *. 6.283) +. (t *. 0.5) in
            let r = 150. +. (float_of_int (i mod 4) *. 80.) in
            bitmap 40. 40. image |> move (r *. cos a) (r *. sin a))
          pictures)

let main =
  Program.main __MODULE__ (fun () ->
      let flags = Playground_platform.flags () in
      Playground_platform.run_app ~flags (game view (fun _ model -> model) (pictures flags)))
