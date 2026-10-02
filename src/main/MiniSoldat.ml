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
 * the Playground's physics: one screen, you against two bots, the
 * first to 5 kills wins.
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
  flags: hitboxes  draw what the physics sees
         ai=engine the bots on Sense and Bot instead of by hand
  e.g.   ./bin/mini-soldat hitboxes
|}

let app = Playground.game Soldat_view.view Soldat_update.update Soldat_model.initial_model

let main = Program.main __MODULE__ (fun () ->
  print_string help;
  Playground_platform.run_app ~flags:(Playground_platform.flags ()) app)
