(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_gui.mli *)
open Playground

let lobby (computer : computer) ~(rooms : (string * int) list) ~(modes : string list) (mode : int) : int * string option =
  let mode = Gui.menu computer ~at:(0., -60.) modes mode in
  let clicked = ref None in
  List.iteri
    (fun i (room, players) ->
      let label = Printf.sprintf "%s    %s" room (match players with 0 -> "nobody yet" | 1 -> "1 player" | n -> Printf.sprintf "%d players" n) in
      (* Limit 2 (Soldat_gui.mli): not through the menu's items, while they show *)
      if Gui.button computer ~at:(0., 180. -. (50. *. float_of_int i)) label && not (Gui.modal ()) then clicked := Some room)
    rooms;
  (mode, !clicked)
