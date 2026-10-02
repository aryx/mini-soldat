(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_soldat.mli. From elm-playground's tests/games/Unit_games.ml:
 * each test plays the game without drawing it, and checks its model. *)

(* the computer at frame [i] (1/60 s each): no key held, the mouse
 * still *)
let computer (i : int) : Playground.computer =
  { Playground.initial_computer with time = Time (float_of_int i /. 60.); screen = Playground.to_screen 1000. 1000. }

(* its bots, both ways (the flag ai=engine): 900 frames of a
 * three-way fight with the player (soldier 0) standing still. Either
 * way the two bots leave their corners and someone dies; the
 * difference is what they know -- by hand, each one has its enemies'
 * positions through the walls from the first frame; on ai/, it has to
 * see them, and patrols until it does *)
let fight ?(ai_engine = false) () =
  let scenes = Scene2d.start (Soldat_model.Title Soldat_map.toy) in
  let p = ref (Soldat_model.start ~ai_engine Soldat_map.toy) in
  let spawn_of i = let b = Soldat_model.body_of !p i in (b.x, b.y) in
  let blue_spawn = spawn_of 1 and green_spawn = spawn_of 2 in
  (* how far each one ever gets from where it started: a patrolling bot
   * turns every two seconds, so where it *ends* says nothing *)
  let roamed = [| 0.; 0.; 0. |] in
  for i = 1 to 900 do
    p := Soldat_update.update_play (computer i) scenes !p;
    List.iter
      (fun (j, (x0, y0)) ->
        let (x, y) = spawn_of j in
        roamed.(j) <- Float.max roamed.(j) (Float.hypot (x -. x0) (y -. y0)))
      [ (1, blue_spawn); (2, green_spawn) ]
  done;
  Alcotest.(check bool) "BLUE left its corner" true (roamed.(1) > 100.);
  Alcotest.(check bool) "GREEN left its corner" true (roamed.(2) > 100.);
  let kills = Array.fold_left (fun n (s : Soldat_model.soldier) -> n + s.kills) 0 !p.soldiers in
  Alcotest.(check bool) "somebody was killed" true (kills > 0)

(* what the ai/ layer takes away: a bot that has seen nobody
 * knows nothing, where the hand-written one knows where everyone is.
 * One frame in, the ai=engine bots' senses hold no enemy position (the
 * three spawn apart, with the map between them) *)
let senses () =
  let scenes = Scene2d.start (Soldat_model.Title Soldat_map.toy) in
  let p = ref (Soldat_model.start ~ai_engine:true Soldat_map.toy) in
  for i = 1 to 3 do
    p := Soldat_update.update_play (computer i) scenes !p
  done;
  let knows i = match Bot.last_senses !p.minds.(i) with Some (s : Soldat_model.senses) -> s.enemy.position <> None | None -> false in
  Alcotest.(check bool) "BLUE has seen nobody yet" false (knows 1);
  Alcotest.(check bool) "GREEN neither" false (knows 2)

let tests =
  Testo.categorize "Soldat"
    [
      Testo.create "the bots fight" fight;
      Testo.create "ai=engine, the bots fight" (fight ~ai_engine:true);
      Testo.create "ai=engine, a bot knows only what it has seen" senses;
    ]
