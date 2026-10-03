(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

let () = Testo.interpret_argv ~project_name:"game" (fun _env -> Unit_soldier.tests @ Unit_weapons.tests @ Unit_things.tests @ Unit_bots.tests @ Unit_sparks.tests @ Unit_teams.tests @ Unit_rambo.tests @ Unit_soldat.tests)
