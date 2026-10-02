(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_gostek.mli *)

let part (name : string) : Soldat_gostek.part = List.find (fun (p : Soldat_gostek.part) -> p.name = name) Soldat_gostek.parts

let near = Alcotest.float 0.001
let pi = Float.pi

let tests =
  Testo.categorize "Gostek"
    [
      Testo.create "the table" (fun () ->
          Alcotest.(check int) "the 16 parts of the body" 16 (List.length Soldat_gostek.parts);
          Alcotest.(check (list string)) "the left side first, the right arm last, over the gun"
            [ "Left_Thigh"; "Right_Arm"; "Right_Forearm"; "Right_Hand" ]
            (List.filteri (fun i _ -> i = 0 || i >= 13) (List.map (fun (p : Soldat_gostek.part) -> p.name) Soldat_gostek.parts));
          Alcotest.(check bool) "between points of the skeleton" true
            (List.for_all (fun (p : Soldat_gostek.part) -> p.from_ >= 1 && p.from_ <= 20 && p.to_ >= 1 && p.to_ <= 20) Soldat_gostek.parts);
          (* a head's picture is 27 pixels: 27 / 4.5 *)
          Alcotest.(check (pair near near)) "a head is 6 units" (6., 6.) (Soldat_gostek.size "morda"));
      Testo.create "a part lying along its two points" (fun () ->
          (* the chest, from (10, 20) to (20, 20): not turned. Its
           * picture is 32 by 29 pixels, 7.11 by 6.44 units; its pivot
           * at 0.1 and 0.3 of them is put on (10, 21). So its middle
           * is 0.4 of its width to the right and 0.2 of its height
           * below: (10 + 2.844, 21 + 1.289) *)
          let at = Soldat_gostek.place (part "Chest") (10., 20.) (20., 20.) 1 in
          Alcotest.(check string) "its picture" "klata" at.picture;
          Alcotest.check near "not turned" 0. at.angle;
          Alcotest.(check (pair near near)) "its middle" (12.844, 22.289) (at.x, at.y);
          Alcotest.(check (pair near near)) "its size" (7.111, 6.444) (at.width, at.height);
          Alcotest.(check bool) "as it is" false at.turned_over);
      Testo.create "a part turned" (fun () ->
          (* the head, from the neck (10, 20) up to (10, 10): a quarter
           * turn. Its pivot is its left side's middle (0, 0.5), on
           * (10, 21): its middle is half its width, 3, along the way
           * up *)
          let at = Soldat_gostek.place (part "Head") (10., 20.) (10., 10.) 1 in
          Alcotest.check near "a quarter turn, upwards: y goes down" (-.pi /. 2.) at.angle;
          Alcotest.(check (pair near near)) "its middle 3 above its pivot" (10., 18.) (at.x, at.y));
      Testo.create "facing left" (fun () ->
          let chest = Soldat_gostek.place (part "Chest") (20., 20.) (10., 20.) (-1) in
          Alcotest.(check string) "a part with a second picture uses it" "klata2" chest.picture;
          Alcotest.(check bool) "as it is" false chest.turned_over;
          (* turned half a turn, its pivot's cy now 0.7: the middle is
           * 0.4 of the width to the left, and 0.2 of the height (the
           * other way up, turned) below *)
          Alcotest.check near "half a turn" pi chest.angle;
          Alcotest.(check (pair near near)) "its middle" (20. -. 2.844, 21. +. 1.289) (chest.x, chest.y);
          let forearm = Soldat_gostek.place (part "Left_Forearm") (20., 20.) (15., 20.) (-1) in
          Alcotest.(check string) "a forearm has none" "reka" forearm.picture;
          Alcotest.(check bool) "and is turned over" true forearm.turned_over);
      Testo.create "a part that stretches" (fun () ->
          let thigh = part "Left_Thigh" in
          let (w, _) = Soldat_gostek.size "udo" in
          let wide d = (Soldat_gostek.place thigh (0., 0.) (d, 0.) 1).width in
          Alcotest.check near "its own length when its points are 5 apart" w (wide 5.);
          Alcotest.check near "shorter when they are nearer" (w *. 0.6) (wide 3.);
          Alcotest.check near "half as long again at most" (w *. 1.5) (wide 20.);
          Alcotest.check near "a head does not stretch" 6. (Soldat_gostek.place (part "Head") (0., 0.) (50., 0.) 1).width);
      Testo.create "every picture of the table is there" (fun () ->
          let colors : Soldat_gostek.colors = { shirt = (220, 60, 50); trousers = (110, 30, 25); skin = (230, 180, 120) } in
          let point n = (float_of_int n, float_of_int (n * 2)) in
          List.iter
            (fun (direction, jets, dead) ->
              Alcotest.(check int) "16 shapes" 16 (List.length (Soldat_gostek.view colors ~point ~direction ~jets ~dead)))
            [ (1, false, false); (-1, false, false); (1, true, false); (-1, true, false); (1, false, true); (-1, false, true) ]);
      Testo.create "the weapons' parts" (fun () ->
          let names parts = List.map (fun (p : Soldat_gostek.part) -> p.image) parts in
          Alcotest.(check (list string)) "a rifle, its clip, its fire" [ "ak74"; "ak74-clip"; "ak74-fire" ] (names (Soldat_gostek.in_hands Ak74 ~clip:true ~fire:true));
          Alcotest.(check (list string)) "the clip out, between two shots" [ "ak74" ] (names (Soldat_gostek.in_hands Ak74 ~clip:false ~fire:false));
          Alcotest.(check (list string)) "the shotgun has no clip" [ "spas12" ] (names (Soldat_gostek.in_hands Spas ~clip:true ~fire:false));
          Alcotest.(check (list string)) "the minigun's belt goes under it" [ "minigun-clip"; "minigun" ] (names (Soldat_gostek.in_hands Minigun ~clip:true ~fire:false));
          Alcotest.(check (list string)) "a rifle on the back" [ "ak74" ] (names (Soldat_gostek.on_back Ak74));
          Alcotest.(check (list string)) "a pistol is not shown there" [] (names (Soldat_gostek.on_back Socom));
          let gun = List.hd (Soldat_gostek.in_hands Ak74 ~clip:false ~fire:false) in
          Alcotest.(check (option string)) "its mirror" (Some "ak74-2") gun.left;
          Alcotest.(check (pair int int)) "from the hand to the arm's end" (16, 15) (gun.from_, gun.to_);
          (* the pistol's picture is the program's; with it in the hands, a shape more *)
          let colors : Soldat_gostek.colors = { shirt = (220, 60, 50); trousers = (110, 30, 25); skin = (230, 180, 120) } in
          let point n = (float_of_int n, float_of_int (n * 2)) in
          let shapes = Soldat_gostek.view ~weapon:(Soldat_gostek.in_hands Socom ~clip:false ~fire:false) colors ~point ~direction:1 ~jets:false ~dead:false in
          Alcotest.(check int) "17 shapes with the pistol" 17 (List.length shapes));
      Testo.create "a picture, tinted and turned over, made once" (fun () ->
          let plain = Soldat_gostek.picture "klata" (255, 255, 255) false in
          let red = Soldat_gostek.picture "klata" (255, 0, 0) false in
          let over = Soldat_gostek.picture "klata" (255, 255, 255) true in
          Alcotest.(check (pair int int)) "32 by 29 pixels" (32, 29) (plain.width, plain.height);
          let pixel (image : Rgba_image.t) x y k = Bigarray.Array1.get image.rgba ((((y * image.width) + x) * 4) + k) in
          (* a pixel of the chest that is not transparent *)
          let (x, y) = (16, 14) in
          Alcotest.(check bool) "the chest's middle is there" true (pixel plain x y 3 > 0 && pixel plain x y 0 > 0);
          Alcotest.(check (list int)) "tinted red: its red kept, its green and blue gone, its alpha kept"
            [ pixel plain x y 0; 0; 0; pixel plain x y 3 ] [ pixel red x y 0; pixel red x y 1; pixel red x y 2; pixel red x y 3 ];
          Alcotest.(check (list int)) "turned over: the row from the bottom"
            (List.init 4 (pixel plain x y)) (List.init 4 (pixel over x (28 - y)));
          Alcotest.(check bool) "asked again: the very same picture" true (Soldat_gostek.picture "klata" (255, 0, 0) false == red));
    ]
