(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_poa.mli *)

let read (file : string) : string =
  let chan = open_in_bin file in
  Fun.protect ~finally:(fun () -> close_in chan) (fun () -> really_input_string chan (in_channel_length chan))

(* the files, from where dune runs the tests (see dune's deps) *)
let data (file : string) : string = read (Filename.concat "../../data" file)

let pair = Alcotest.(pair (float 0.001) (float 0.001))

let tests =
  Testo.categorize "Poa"
    [
      Testo.create "the worked example: stoi.poa" (fun () ->
          match Poa.animation (data "anims/stoi.poa") with
          | Error why -> Alcotest.fail why
          | Ok frames ->
              Alcotest.(check int) "17 frames" 17 (Array.length frames);
              Alcotest.(check int) "of 20 points" 20 (Array.length frames.(0));
              (* x = 1.51294851303101, z = -0.018487149849534 *)
              Alcotest.check pair "the first point: x := -3 x / 1.1, y := -3 z" (-4.126, 0.055) frames.(0).(0));
      Testo.create "a file written here" (fun () ->
          match Poa.animation "1\n1.1\n9\n2\n20\n-2.2\n9\n1E0\nNEXTFRAME\n1\n0\n0\n0\nENDFILE\n" with
          | Error why -> Alcotest.fail why
          | Ok frames ->
              Alcotest.(check int) "two frames" 2 (Array.length frames);
              Alcotest.check pair "point 1: (1.1, 2) read as (-3, -6)" (-3., -6.) frames.(0).(0);
              Alcotest.check pair "point 20, with an exponent" (6., -3.) frames.(0).(19);
              Alcotest.check pair "a point not named: at (0, 0)" (0., 0.) frames.(0).(5);
              Alcotest.(check bool) "lines ending as on Windows read the same" true
                (Poa.animation "1\r\n1.1\r\n9\r\n2\r\nENDFILE\r\n" = Ok [| Array.init 20 (fun i -> if i = 0 then (-3., -6.) else (0., 0.)) |]));
      Testo.create "the worked example: gostek.po" (fun () ->
          match Poa.skeleton ~scale:3. (data "objects/gostek.po") with
          | Error why -> Alcotest.fail why
          | Ok s ->
              Alcotest.(check int) "24 points" 24 (Array.length s.points);
              Alcotest.(check int) "30 sticks" 30 (Array.length s.sticks);
              let (a, b, length) = s.sticks.(0) in
              Alcotest.(check (pair int int)) "the first from point 2 to point 3" (2, 3) (a, b);
              let (ax, ay) = s.points.(a - 1) and (bx, by) = s.points.(b - 1) in
              Alcotest.(check (float 0.0001)) "as long as they are apart" (Float.hypot (ax -. bx) (ay -. by)) length;
              (* P1 is at x = 1: -1 * 3 / 1.2 *)
              Alcotest.check pair "point 1: x := -x scale / 1.2" (-2.5, 0.) s.points.(0);
              let ys = Array.map snd s.points in
              Alcotest.(check bool) "a soldier is about 20 tall" true (Array.fold_left Float.min 0. ys < -18. && Array.fold_left Float.min 0. ys > -22.));
      Testo.create "what is refused" (fun () ->
          let refused name text = Alcotest.(check bool) name true (Result.is_error (Poa.animation text)) in
          refused "nothing" "";
          refused "no ENDFILE" "1\n0\n0\n0\n";
          refused "a point's number that is not one" "21\n0\n0\n0\nENDFILE\n";
          refused "a number that is not one" "1\nabc\n0\n0\nENDFILE\n";
          refused "41 frames" (String.concat "" (List.init 40 (fun _ -> "NEXTFRAME\n")) ^ "ENDFILE\n");
          Alcotest.(check bool) "a skeleton without CONSTRAINTS" true (Result.is_error (Poa.skeleton ~scale:1. "P1\n0\n0\n0\nENDFILE\n"));
          Alcotest.(check bool) "a stick to a point that is not there" true (Result.is_error (Poa.skeleton ~scale:1. "P1\n0\n0\n0\nCONSTRAINTS\nP1\nP7\nENDFILE\n")));
    ]
