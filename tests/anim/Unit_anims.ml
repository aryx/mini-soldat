(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_anims.mli *)

let rec times (n : int) (p : Soldat_anims.playing) : Soldat_anims.playing = if n = 0 then p else times (n - 1) (Soldat_anims.advance p)

let tests =
  Testo.categorize "Anims"
    [
      Testo.create "the 44, as Soldat counts their frames" (fun () ->
          Alcotest.(check int) "44 of them" 44 (List.length Soldat_anims.all);
          let frames = Soldat_anims.frames in
          Alcotest.(check (list int)) "Stand, Run, Run_back, Jump, Jump_side, Fall, Crouch, Prone, Get_up, Roll, Roll_back"
            [ 17; 38; 33; 37; 34; 7; 15; 27; 25; 34; 32 ]
            [ frames Stand; frames Run; frames Run_back; frames Jump; frames Jump_side; frames Fall; frames Crouch; frames Prone; frames Get_up; frames Roll; frames Roll_back ];
          Alcotest.(check bool) "none longer than 40" true (List.for_all (fun (id, _, _, _) -> frames id >= 1 && frames id <= 40) Soldat_anims.all);
          Alcotest.(check int) "1137 frames in all" 1137 (List.fold_left (fun n (id, _, _, _) -> n + frames id) 0 Soldat_anims.all));
      Testo.create "a point, as its file has it" (fun () ->
          (* stoi.poa's first point: Unit_poa's worked example *)
          Alcotest.(check (pair (float 0.001) (float 0.001))) "Stand, frame 1, point 1" (-4.126, 0.055) (Soldat_anims.point Stand 1 1);
          let (_, head) = Soldat_anims.point Stand 1 12 in
          Alcotest.(check bool) "its head 18 or so above its feet" true (head < -15. && head > -25.);
          Alcotest.(check bool) "the last animation's last frame is there" true (Soldat_anims.point Own (Soldat_anims.frames Own) 20 <> (0., 0.));
          Alcotest.check_raises "a frame beyond the last" (Invalid_argument "Soldat_anims.point") (fun () -> ignore (Soldat_anims.point Stand 18 1));
          Alcotest.check_raises "frames are numbered from 1" (Invalid_argument "Soldat_anims.point") (fun () -> ignore (Soldat_anims.point Stand 0 1)));
      Testo.create "advancing" (fun () ->
          let run = Soldat_anims.start Run 1 in
          Alcotest.(check int) "Run: a frame a tick" 2 (Soldat_anims.advance run).frame;
          Alcotest.(check int) "it loops: after its 38 frames, the first" 1 (times 38 run).frame;
          let stand = Soldat_anims.start Stand 1 in
          Alcotest.(check (list int)) "Stand: a frame every 3 ticks" [ 1; 1; 2; 2; 2; 3 ] (List.map (fun n -> (times n stand).frame) [ 1; 2; 3; 4; 5; 6 ]);
          let jump = Soldat_anims.start Jump 1 in
          Alcotest.(check int) "Jump stops on its last frame" 37 (times 100 jump).frame;
          Alcotest.(check bool) "which is its end" true (Soldat_anims.ended (times 100 jump) && not (Soldat_anims.ended jump)));
      Testo.create "the skeleton" (fun () ->
          Alcotest.(check int) "24 points" 24 (Array.length Soldat_anims.gostek.points);
          Alcotest.(check int) "30 sticks" 30 (Array.length Soldat_anims.gostek.sticks);
          Alcotest.(check int) "28 of them between the 20 points the animations place" 28
            (Array.fold_left (fun n (a, b, _) -> if a <= 20 && b <= 20 then n + 1 else n) 0 Soldat_anims.gostek.sticks));
    ]
