(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* A program of the website's build (the Makefile's website): the
 * pictures of a folder, .png and .bmp, each written beside the others
 * in another folder as its pixels (Soldat_assets.to_pixels: name.rgba),
 * which is how a browser is given them --
 *
 *   Gen_assets.exe data/textures docs/assets/textures
 *
 * A .png wins over a .bmp of the same name, as in the game.
 *)

let read (file : string) : string =
  let chan = open_in_bin file in
  Fun.protect ~finally:(fun () -> close_in chan) (fun () -> really_input_string chan (in_channel_length chan))

let write (file : string) (bytes : string) : unit =
  let chan = open_out_bin file in
  Fun.protect ~finally:(fun () -> close_out chan) (fun () -> output_string chan bytes)

let () =
  match Sys.argv with
  | [| _; from; into |] ->
      let files = Array.to_list (Sys.readdir from) |> List.sort compare in
      (* the .bmp first: a .png of the same name then writes over it *)
      let by_ending ending = List.filter (fun f -> String.lowercase_ascii (Filename.extension f) = ending) files in
      List.iter
        (fun file ->
          match Soldat_assets.decode file (read (Filename.concat from file)) with
          | Some image -> write (Filename.concat into (Filename.remove_extension file ^ ".rgba")) (Soldat_assets.to_pixels image)
          | None -> prerr_endline (file ^ ": not a picture this reads"))
        (by_ending ".bmp" @ by_ending ".png")
  | _ ->
      prerr_endline "usage: Gen_assets.exe FROM INTO";
      exit 2
