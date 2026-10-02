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
 * It started as elm-playground's TinySoldat, and is on its way
 * (docs/plan.md): the maps are Soldat's (Arena2, carried in the
 * program, or any .pms file named with the flag map), the soldier
 * moves and looks as Soldat's does, and fires Soldat's weapons, by its
 * rules and its numbers, against Soldat's own bots, in a deathmatch
 * as Soldat's: the first to 10 kills. The keys are Soldat's:
 *
 *   a/d    run           w  jump       s  crouch      x  lie down
 *   mouse  aim           left button: shoot     right button: the jets
 *   r      reload        q  the other weapon    e  a grenade
 *   f      throw the weapon away
 *   1-9, 0 the weapon to appear with
 *
 * This is the main: the game is src/game's (Soldat_model,
 * Soldat_update), on src/map's arena, drawn by src/render's
 * Soldat_view; the Playground runs the three as a Model-View-Update
 * program. See README.md for the layout and docs/opensoldat.md for
 * what each part is in Soldat's own sources.
 *)

let help =
  {|mini-soldat
  keys:  a/d    run              w      jump
         s      crouch           x      lie down, get up
         r      reload           q      the other weapon
         e      a grenade: held longer, thrown harder
         f      throw the weapon away: empty hands pick another up
         1-9, 0 the weapon to appear with (weapon=N)
         g      the graphics: as each step of the game's making drew it
         down and a side, running: a roll; up and a side: a jump sideways
  mouse: aim; left button: shoot; right button (or shift): the jets
  flags: map=FILE  one of Soldat's maps, a .pms file (Arena2 without it)
         map=NAME  or by its name, under the base: map=ctf_Ash
         base=DIR  where the maps, textures and scenery are (data), e.g.
                   a checkout of opensoldat-base: base=~/opensoldat-base/shared
         graphics=N  how much of Soldat's look: 1 skeletons and flat
                   colours, 2 the soldiers' pictures, 3 the map's
                   texture and scenery (the key g goes round them)
         weapon=N  the weapon to appear with, by its key: 1 Desert Eagles,
                   2 HK MP5, 3 Ak-74, 4 Steyr AUG, 5 Spas-12, 6 Ruger 77,
                   7 M79, 8 Barrett, 9 FN Minimi, 0 Minigun
         bots=N    how many bots to play against (3)
         ai=engine the last of them not Soldat's but one on
                   elm-playground's Sense and Bot: it knows only what
                   it has seen, and reacts as late as a hand does
         mute      no sound
         sparks=N  at most N sparks at a time (558; 0: none)
         hitboxes  draw the points the game tests
         sticks    draw the soldiers' skeletons over them
         waypoints draw the map's waypoints, the bots' paths
  e.g.   ./bin/mini-soldat base=~/opensoldat-base/shared map=ctf_Ash
|}

(* "~/" is the home directory (a shell leaves the ~ of map=~/... alone) *)
let home (file : string) : string =
  match Sys.getenv_opt "HOME" with
  | Some home when String.length file >= 2 && String.sub file 0 2 = "~/" -> home ^ String.sub file 1 (String.length file - 1)
  | _ -> file

(* a file's bytes *)
let read_file (caps : < Cap.open_in ; .. >) (file : string) : string =
  let file = home file in
  let chan = CapStdlib.open_in caps file in
  Fun.protect ~finally:(fun () -> close_in chan) (fun () ->
      set_binary_mode_in chan true;
      really_input_string chan (in_channel_length chan))

(* the map the flags ask for: the one carried; a file's, read now
 * (map=some/where/ctf_Ash.pms); or one of the content's, by its name
 * (map=ctf_Ash: maps/ctf_Ash.pms under the base), which comes when it
 * comes *)
type asked = Map of Soldat_map.t | Named of string

let map_of_flags (caps : < Cap.open_in ; .. >) (flags : (string * string) list) : asked =
  match List.assoc_opt "map" flags with
  | None | Some "" | Some "arena2" -> Map (Lazy.force Soldat_map.arena2)
  | Some file when Filename.check_suffix file ".pms" || Filename.check_suffix file ".PMS" -> (
      match Pms.parse (read_file caps file) with
      | Ok pms -> Map (Soldat_map.of_pms pms)
      | Error why -> prerr_endline (file ^ ": " ^ why); exit 1
      | exception Sys_error why -> prerr_endline why; exit 1)
  | Some name -> Named name

let main = Program.main __MODULE__ (fun () -> Cap.main (fun caps ->
  print_string help;
  let flags = Playground_platform.flags () in
  (* where the textures and the scenery are: a folder, or a URL's start *)
  Option.iter (fun base -> Soldat_assets.set_base (home base)) (List.assoc_opt "base" flags);
  let map = map_of_flags caps flags in
  (* how much of Soldat's look is drawn: all of it, unless the flag says
   * (the key g goes round the ways) *)
  let graphics = Option.value (Option.bind (List.assoc_opt "graphics" flags) int_of_string_opt) ~default:Soldat_model.graphics_levels in
  let first = match map with Map map -> Soldat_model.initial_model ~graphics map | Named name -> Soldat_model.loading_model ~graphics name in
  (* the weapon to appear with, by its key in Soldat's menu *)
  let primary =
    match Option.bind (List.assoc_opt "weapon" flags) int_of_string_opt with
    | Some n when n >= 0 && n <= 9 -> List.nth Soldat_weapons.primaries ((n + 9) mod 10)
    | _ -> first.primary
  in
  (* mute: nothing is played *)
  if List.mem_assoc "mute" flags then Soldat_sound.mute := true;
  (* sparks=N: at most that many are kept (Soldat's r_maxsparks) *)
  Option.iter (fun n -> Soldat_sparks.most := max 0 n) (Option.bind (List.assoc_opt "sparks" flags) int_of_string_opt);
  let bots = match Option.bind (List.assoc_opt "bots" flags) int_of_string_opt with Some n when n >= 0 && n <= 15 -> n | _ -> first.bots in
  let first = { first with primary; bots } in
  let app = Playground.game Soldat_view.view Soldat_update.update first in
  Playground_platform.run_app ~flags app))
