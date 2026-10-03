(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_twin.mli *)
open Playground

let register () : unit =
  Soldat_parts.bots.twin <- Some Soldat_engine_bot.part;
  Soldat_parts.effects.twin <- Some Soldat_juice.part;
  Soldat_parts.things.twin <- Some (fun ?heard:_ map thing -> Soldat_bodies.move map thing);
  Soldat_parts.dead.twin <- Some (fun ?heard:_ map ragdoll -> Soldat_limbs.tumble map ragdoll);
  Soldat_parts.lobby := Some Soldat_gui.lobby;
  Soldat_sound.twin := Some (fun ~listener at -> Some (Soldat_space.heard ~listener at));
  (* the dots: each a disc of its kind's colour, fading as its life goes *)
  let dots (fx : Soldat_state.fx) : shape list option =
    match fx with
    | Soldat_juice.Juice j ->
        Some
          (List.map
             (fun (x, y, size, (kind : Soldat_juice.kind), left) ->
               let color = match kind with Blood -> rgb 190 20 20 | Chip -> rgb 150 150 150 | Smoke -> rgb 200 200 200 | Fire -> rgb 255 170 40 in
               circle color (size /. 2.) |> fade left |> move x y)
             (Soldat_juice.dots j))
    | _ -> None
  in
  Soldat_view.effects := dots :: !Soldat_view.effects
