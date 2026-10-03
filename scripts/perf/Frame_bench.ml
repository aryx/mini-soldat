(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* How long a tick of the game takes, without drawing it: a minute of
 * the bots' fight on Arena2, in milliseconds a tick. A tick has 16.7
 * ms, drawing included.
 *
 *   dune exec scripts/perf/Frame_bench.exe
 *
 * With .pms files named, those maps instead, 300 frames each: every
 * map of Soldat's read, made into the game's and played, the slowest
 * easy to see --
 *
 *   dune exec scripts/perf/Frame_bench.exe -- ~/opensoldat-base/shared/maps/*.pms
 *)

let bench (name : string) (frames : int) (map : Soldat_map.t) : unit =
  let p = ref (Soldat_update.start ~bots:(Soldat_cast.cast 3 1) map) in
  let t0 = Unix.gettimeofday () in
  for _ = 1 to frames do
    p := Soldat_update.tick !p Soldat_model.still ~look:(0., 0.)
  done;
  let ms = (Unix.gettimeofday () -. t0) *. 1000. /. float_of_int frames in
  let kills = Array.fold_left (fun n (s : Soldat_model.soldier) -> n + s.kills) 0 !p.soldiers in
  Printf.printf "%-22s %4d walls %3d spawns  %6.3f ms a tick  %d kills\n%!" name (Array.length map.walls) (List.length map.spawns) ms kills

let read (file : string) : string =
  let chan = open_in_bin file in
  Fun.protect ~finally:(fun () -> close_in chan) (fun () -> really_input_string chan (in_channel_length chan))

let () =
  Soldat_orig.register ();
  match List.tl (Array.to_list Sys.argv) with
  | [] -> bench "Arena2" 3600 (Lazy.force Soldat_map.arena2)
  | files ->
      List.iter
        (fun file ->
          match Pms.parse (read file) with
          | Ok pms -> bench (Filename.basename file) 300 (Soldat_map.of_pms pms)
          | Error why -> Printf.printf "%-22s %s\n%!" (Filename.basename file) why)
        files
