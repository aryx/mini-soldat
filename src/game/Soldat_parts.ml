(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_parts.mli *)
open Soldat_model

type 'a slot = { mutable orig : 'a option; mutable twin : 'a option }

let pick (slot : 'a slot) ~(twin : bool) : 'a option =
  match if twin then (slot.twin, slot.orig) else (slot.orig, slot.twin) with (Some part, _) -> Some part | (None, other) -> other

type bots = {
  owns : Soldat_state.mind -> bool;
  fresh : character -> Soldat_state.mind;
  control : play -> int -> Soldat_state.mind -> random:(unit -> float) -> intent * Soldat_state.mind * int list;
}

type effects = {
  tick : Soldat_map.t -> random:(unit -> float) -> (int * Soldat_event.t) list -> Soldat_state.fx -> Soldat_state.fx * (Soldat_sfx.t * (float * float)) list;
  shake : random:(unit -> float) -> Soldat_state.fx -> float * float;
  follow : camera:float * float -> float * float -> look:float * float -> float * float;
}

type things = ?heard:Soldat_event.t list ref -> Soldat_map.t -> Soldat_things.t -> Soldat_things.t

let lobby : (Playground.computer -> rooms:(string * int) list -> modes:string list -> int -> int * string option) option ref = ref None
let bots : bots slot = { orig = None; twin = None }
let effects : effects slot = { orig = None; twin = None }
let things : things slot = { orig = None; twin = None }
