(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* mini-soldat-twin: the game with the twins only (src/twin), nothing
 * of Soldat's own bots, sparks, falling things or network: the shared
 * code on elm-playground's libraries alone. Its layers' levels that
 * are Soldat's are the twin's instead. *)
let main =
  Program.main __MODULE__ (fun () ->
      Cap.main (fun caps ->
          Soldat_main.run caps ~register:Soldat_twin.register ~server:None
            ~peer:(Some (fun ~rollback role -> Soldat_lockstep.connect ~rollback caps role))
            ~update:(fun ~peer:_ -> Soldat_lockstep.update)))
