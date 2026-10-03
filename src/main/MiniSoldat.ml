(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* mini-soldat: the whole game, Soldat's parts and their twins both
 * (src/orig and src/twin: docs/twins.md), a key from one to the other
 * while it runs. Soldat_main is the program; this says what it is
 * linked with. *)
let main =
  Program.main __MODULE__ (fun () ->
      Cap.main (fun caps ->
          Soldat_main.run caps
            ~register:(fun () -> Soldat_orig.register (); Soldat_twin.register ())
            ~server:(Some (Soldat_online.connect caps))
            ~peer:(Some (fun ~rollback role -> Soldat_lockstep.connect ~rollback caps role))
            ~update:(fun ~peer -> if peer then Soldat_lockstep.update else Soldat_online.update)))
