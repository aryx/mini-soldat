(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_raster.mli *)

(* a tile of 8 by 8 pixels over the square from (0, 0) to (8, 8): a
 * pixel a unit *)
let tile () : Soldat_raster.tile = Soldat_raster.tile ~left:0. ~top:0. ~scale:1. ~pixels:8

let pixel (t : Soldat_raster.tile) (x : int) (y : int) : int list = List.init 4 (fun k -> Bigarray.Array1.get t.image.rgba ((((y * t.image.width) + x) * 4) + k))

let corner ?(u = 0.) ?(v = 0.) (x : float) (y : float) ((r, g, b, a) : float * float * float * float) : Soldat_raster.corner = { x; y; u; v; r; g; b; a }

let red = (255., 0., 0., 255.) and green = (0., 255., 0., 255.) and blue = (0., 0., 255., 255.) and white = (255., 255., 255., 255.)

(* a picture of these pixels, each red, green, blue, alpha *)
let picture (width : int) (height : int) (pixels : int list list) : Rgba_image.t =
  let image = Rgba_image.create ~width ~height in
  List.iteri (fun i p -> List.iteri (fun k v -> Bigarray.Array1.set image.rgba ((i * 4) + k) v) p) pixels;
  image

let tests =
  Testo.categorize "Raster"
    [
      Testo.create "a triangle: its inside, not its outside" (fun () ->
          let t = tile () in
          (* the half of the tile under its diagonal *)
          Soldat_raster.triangle t None (corner 0. 0. red) (corner 0. 8. red) (corner 8. 8. red);
          Alcotest.(check (list int)) "under the diagonal: red" [ 255; 0; 0; 255 ] (pixel t 1 6);
          Alcotest.(check (list int)) "over it: nothing" [ 0; 0; 0; 0 ] (pixel t 6 1);
          let other = tile () in
          Soldat_raster.triangle other None (corner 8. 8. red) (corner 0. 8. red) (corner 0. 0. red);
          Alcotest.(check bool) "its corners the other way round: the same" true (pixel other 1 6 = pixel t 1 6 && pixel other 6 1 = pixel t 6 1));
      Testo.create "the corners' colours, blended" (fun () ->
          let t = tile () in
          Soldat_raster.triangle t None (corner 0. 0. red) (corner 16. 0. green) (corner 0. 16. blue);
          (* the pixel (0, 0)'s middle is (0.5, 0.5): 1/32 of the way to
           * each other corner *)
          Alcotest.(check (list int)) "at the red corner: nearly all red" [ 239; 7; 7; 255 ] (pixel t 0 0);
          let (r, g, b) = match pixel t 4 4 with [ r; g; b; _ ] -> (r, g, b) | _ -> (0, 0, 0) in
          Alcotest.(check bool) "in the middle: some of each, and their sum the same" true (r > 100 && g > 50 && b > 50 && abs (r + g + b - 255) <= 2));
      Testo.create "a texture, repeated, times the colour" (fun () ->
          (* two pixels: white then black; u goes from 0 to 2 across the
           * tile: the texture twice *)
          let texture = picture 2 1 [ [ 255; 255; 255; 255 ]; [ 0; 0; 0; 255 ] ] in
          let t = tile () in
          let at x y u v = corner ~u ~v x y red in
          Soldat_raster.triangle t (Some texture) (at 0. 0. 0. 0.) (at 8. 0. 2. 0.) (at 0. 8. 0. 1.);
          Alcotest.(check (list (list int))) "white times red, black, and again"
            [ [ 255; 0; 0; 255 ]; [ 0; 0; 0; 255 ]; [ 255; 0; 0; 255 ]; [ 0; 0; 0; 255 ] ]
            [ pixel t 0 0; pixel t 2 0; pixel t 4 0; pixel t 6 0 ]);
      Testo.create "one colour over another" (fun () ->
          let t = tile () in
          let all color = Soldat_raster.triangle t None (corner 0. 0. color) (corner 0. 20. color) (corner 20. 0. color) in
          all red;
          all (0., 0., 255., 127.5);
          Alcotest.(check (list int)) "half of blue over red: half of each, opaque" [ 127; 0; 127; 255 ] (pixel t 2 2);
          let clear = tile () in
          Soldat_raster.triangle clear None (corner 0. 0. (0., 0., 255., 0.)) (corner 0. 20. (0., 0., 255., 0.)) (corner 20. 0. (0., 0., 255., 0.));
          Alcotest.(check (list int)) "nothing of a colour: nothing" [ 0; 0; 0; 0 ] (pixel clear 2 2));
      Testo.create "a sprite where Soldat puts a prop" (fun () ->
          let quad = picture 2 2 [ [ 255; 0; 0; 255 ]; [ 0; 255; 0; 255 ]; [ 0; 0; 255; 255 ]; [ 255; 255; 255; 0 ] ] in
          let t = tile () in
          (* 4 by 4 units at (2, 2), not turned: each of its pixels 2 by 2 *)
          Soldat_raster.sprite t quad ~x:2. ~y:2. ~w:4. ~h:4. ~sx:1. ~sy:1. ~rotation:0. ~color:(255, 255, 255, 255);
          Alcotest.(check (list (list int))) "its four quarters; the transparent one left as it was"
            [ [ 255; 0; 0; 255 ]; [ 0; 255; 0; 255 ]; [ 0; 0; 255; 255 ]; [ 0; 0; 0; 0 ] ]
            [ pixel t 2 2; pixel t 5 2; pixel t 2 5; pixel t 5 5 ];
          Alcotest.(check (list int)) "nothing beside it" [ 0; 0; 0; 0 ] (pixel t 1 2);
          let tinted = tile () in
          Soldat_raster.sprite tinted quad ~x:2. ~y:2. ~w:4. ~h:4. ~sx:1. ~sy:1. ~rotation:0. ~color:(128, 255, 255, 128);
          Alcotest.(check (list int)) "tinted, and half there" [ 128; 0; 0; 128 ] (pixel tinted 2 2);
          let scaled = tile () in
          Soldat_raster.sprite scaled quad ~x:0. ~y:0. ~w:4. ~h:4. ~sx:2. ~sy:1. ~rotation:0. ~color:(255, 255, 255, 255);
          Alcotest.(check (list (list int))) "twice as wide: red to 4, then green" [ [ 255; 0; 0; 255 ]; [ 0; 255; 0; 255 ] ] [ pixel scaled 3 0; pixel scaled 4 0 ]);
      Testo.create "a prop's corners, turned" (fun () ->
          let near = Alcotest.(list (pair (float 0.001) (float 0.001))) in
          Alcotest.check near "not turned: the rectangle at (x, y)" [ (10., 20.); (14., 20.); (14., 22.); (10., 22.) ]
            (Soldat_raster.sprite_corners ~x:10. ~y:20. ~w:4. ~h:2. ~sx:1. ~sy:1. ~rotation:0.);
          (* turned about the point one unit under its corner, (10, 21):
           * its corner, one above that point, goes one to its left *)
          let turned = Soldat_raster.sprite_corners ~x:10. ~y:20. ~w:4. ~h:2. ~sx:1. ~sy:1. ~rotation:(Float.pi /. 2.) in
          Alcotest.check near "a quarter turn about (10, 21)" [ (9., 21.); (9., 17.); (11., 17.); (11., 21.) ] turned);
      Testo.create "a picture halved" (fun () ->
          let image = picture 4 2 (List.init 8 (fun i -> if i mod 4 < 2 then [ 200; 100; 0; 255 ] else [ 0; 100; 200; 255 ])) in
          let half = Soldat_raster.halved image in
          Alcotest.(check (pair int int)) "2 by 1" (2, 1) (half.width, half.height);
          let px x = List.init 4 (fun k -> Bigarray.Array1.get half.rgba ((x * 4) + k)) in
          Alcotest.(check (list (list int))) "each pixel the mean of four" [ [ 200; 100; 0; 255 ]; [ 0; 100; 200; 255 ] ] [ px 0; px 1 ]);
    ]
