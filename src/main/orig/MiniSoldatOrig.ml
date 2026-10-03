(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* mini-soldat-orig: the game with Soldat's own parts only (src/orig),
 * nothing of the twins: what is adapted from the Pascal, and no more.
 * Its layers' levels that are a twin's are Soldat's instead. *)
let main =
  Program.main __MODULE__ (fun () ->
      Cap.main (fun caps ->
          Soldat_main.run caps ~register:Soldat_orig.register ~server:(Some (Soldat_online.connect caps)) ~peer:None ~update:(fun ~peer:_ -> Soldat_online.update)))
