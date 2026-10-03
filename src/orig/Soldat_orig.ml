(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_orig.mli *)

let register () : unit =
  Soldat_parts.bots.orig <- Some Soldat_bots.part;
  Soldat_parts.effects.orig <- Some Soldat_sparks.part;
  Soldat_parts.things.orig <- Some Soldat_fall.move;
  (* the sparks' pictures: drawn, and asked for ahead on the title *)
  Soldat_view.effects := (fun fx -> match fx with Soldat_sparks.Sparks l -> Some (Soldat_sparks_view.view l) | _ -> None) :: !Soldat_view.effects;
  Soldat_view.warm := (fun () -> ignore (Soldat_sparks_view.warm ())) :: !Soldat_view.warm
