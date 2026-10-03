(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_state.mli *)

type mind = ..
type mind += Nobody
type fx = ..
type fx += Nothing

let most = ref (if Soldat_assets.in_browser then 150 else 558)
