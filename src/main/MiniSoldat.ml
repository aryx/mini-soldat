(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* A clone of Soldat (Michal Marcinkowski, "MM", 2002, Delphi,
 * freeware; open-sourced in 2020, now OpenSoldat, MIT:
 * https://github.com/opensoldat/opensoldat, "influenced by the best of
 * games such as Liero, Worms, Quake, Counter-Strike"): a side-view
 * deathmatch, soldiers running, jumping and flying on jet boots over a
 * map of polygons, shooting and throwing grenades, and falling as
 * ragdolls.
 *
 * For now what elm-playground's TinySoldat was, a toy of 600 lines on
 * the Playground's physics, you against two bots, the first to 5 kills
 * wins -- but on one of Soldat's own maps: Arena2, carried in the
 * program, or any .pms file named with the flag map (Pms.mli).
 *
 *   a/d    run           w  jump; hold it in the air: the jets (fuel)
 *   mouse  aim           click (or space): shoot    q: a grenade
 *
 * This is the main: the game is src/game's (Soldat_model,
 * Soldat_update), on src/map's arena, drawn by src/render's
 * Soldat_view; the Playground runs the three as a Model-View-Update
 * program. See README.md for the layout and docs/opensoldat.md for
 * what each part is in Soldat's own sources.
 *)

let help =
  {|mini-soldat
  keys:  a/d    run              w      jump; held in the air: jets
         space  shoot            q      a grenade
  mouse: aim; click to shoot
  flags: map=FILE  one of Soldat's maps, a .pms file (Arena2 without it)
         map=toy   TinySoldat's one screen
         hitboxes  draw what the physics sees
         ai=engine the bots on Sense and Bot instead of by hand
  e.g.   ./bin/mini-soldat map=~/opensoldat-base/shared/maps/ctf_Ash.pms
|}

(* a file's bytes; "~/" is the home directory (a shell leaves the ~ of
 * map=~/... alone) *)
let read_file (caps : < Cap.open_in ; .. >) (file : string) : string =
  let file =
    match Sys.getenv_opt "HOME" with
    | Some home when String.length file >= 2 && String.sub file 0 2 = "~/" -> home ^ String.sub file 1 (String.length file - 1)
    | _ -> file
  in
  let chan = CapStdlib.open_in caps file in
  Fun.protect ~finally:(fun () -> close_in chan) (fun () ->
      set_binary_mode_in chan true;
      really_input_string chan (in_channel_length chan))

(* the map the flags ask for: the one carried, the toy, or a file's (in
 * a browser there is no file to open: the map carried, then) *)
let map_of_flags (caps : < Cap.open_in ; .. >) (flags : (string * string) list) : Soldat_map.t =
  match List.assoc_opt "map" flags with
  | None | Some "" | Some "arena2" -> Lazy.force Soldat_map.arena2
  | Some "toy" -> Soldat_map.toy
  | Some file -> (
      match Pms.parse (read_file caps file) with
      | Ok pms -> Soldat_map.of_pms pms
      | Error why -> prerr_endline (file ^ ": " ^ why); exit 1
      | exception Sys_error why -> prerr_endline why; exit 1)

let main = Program.main __MODULE__ (fun () -> Cap.main (fun caps ->
  print_string help;
  let flags = Playground_platform.flags () in
  let map = map_of_flags caps flags in
  let app = Playground.game Soldat_view.view Soldat_update.update (Soldat_model.initial_model map) in
  Playground_platform.run_app ~flags app))
