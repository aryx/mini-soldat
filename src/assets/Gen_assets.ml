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
 * With a third word, half, each at half its size: an explosion's
 * pictures are 320 by 450 for 71 units by 100.
 *
 * A .png wins over a .bmp of the same name, as in the game.
 *)

let read (file : string) : string =
  let chan = open_in_bin file in
  Fun.protect ~finally:(fun () -> close_in chan) (fun () -> really_input_string chan (in_channel_length chan))

let write (file : string) (bytes : string) : unit =
  let chan = open_out_bin file in
  Fun.protect ~finally:(fun () -> close_out chan) (fun () -> output_string chan bytes)

(* a picture at half its size, each pixel the mean of four *)
let halved (image : Rgba_image.t) : Rgba_image.t =
  let (w, h) = (max 1 (image.width / 2), max 1 (image.height / 2)) in
  let out = Rgba_image.create ~width:w ~height:h in
  for y = 0 to h - 1 do
    for x = 0 to w - 1 do
      for k = 0 to 3 do
        let at dx dy =
          let (sx, sy) = (min (image.width - 1) ((2 * x) + dx), min (image.height - 1) ((2 * y) + dy)) in
          Bigarray.Array1.get image.rgba ((((sy * image.width) + sx) * 4) + k)
        in
        Bigarray.Array1.set out.rgba ((((y * w) + x) * 4) + k) ((at 0 0 + at 1 0 + at 0 1 + at 1 1) / 4)
      done
    done
  done;
  out

let () =
  let convert (from : string) (into : string) ~(half : bool) : unit =
    let files = Array.to_list (Sys.readdir from) |> List.sort compare in
    (* the .bmp first: a .png of the same name then writes over it *)
    let by_ending ending = List.filter (fun f -> String.lowercase_ascii (Filename.extension f) = ending) files in
    List.iter
      (fun file ->
        match Soldat_assets.decode file (read (Filename.concat from file)) with
        | Some image -> write (Filename.concat into (Filename.remove_extension file ^ ".rgba")) (Soldat_assets.to_pixels (if half then halved image else image))
        | None -> prerr_endline (file ^ ": not a picture this reads"))
      (by_ending ".bmp" @ by_ending ".png")
  in
  match Sys.argv with
  | [| _; from; into |] -> convert from into ~half:false
  (* big pictures drawn small (an explosion's 16): half their pixels *)
  | [| _; from; into; "half" |] -> convert from into ~half:true
  | _ ->
      prerr_endline "usage: Gen_assets.exe FROM INTO [half]";
      exit 2
