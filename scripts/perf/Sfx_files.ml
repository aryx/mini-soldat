(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* The sounds' files the game may ask for (Soldat_sfx.files), one a
 * line, without ".wav": see the dune file beside. *)
let () = List.iter print_endline (List.sort_uniq compare Soldat_sfx.files)
