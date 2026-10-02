(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_assets.mli *)

type 'a asked = Loading | Missing | Here of 'a

(* where the content is unless told: natively the folder data/, from
 * where the program is run; in a browser the folder assets/ beside the
 * page *)
let the_base = ref (match Sys.backend_type with Other _ -> "assets" | Native | Bytecode -> "data")
let set_base (b : string) : unit = the_base := b
let base () : string = !the_base

(* each file asked for, by its path under the base *)
let files : (string, string asked) Hashtbl.t = Hashtbl.create 64

(* each picture decoded, by its folder, its name and whether keyed *)
let pictures : (string * string * bool, Rgba_image.t asked) Hashtbl.t = Hashtbl.create 64

let reset () : unit =
  Hashtbl.reset files;
  Hashtbl.reset pictures

let pending () : int = Hashtbl.fold (fun _ a n -> if a = Loading then n + 1 else n) files 0

(* in a browser: the program compiled by js_of_ocaml *)
let in_browser : bool = match Sys.backend_type with Other _ -> true | Native | Bytecode -> false

(* natively, under a folder, a file that is not there is not asked for:
 * most pictures are tried as .png then as .bmp, and each miss would be
 * a warning on the terminal *)
let surely_missing (path : string) : bool =
  let url = String.length !the_base >= 4 && String.sub !the_base 0 4 = "http" in
  (not in_browser) && (not url) && not (Sys.file_exists (!the_base ^ "/" ^ path))

let bytes (path : string) : string asked =
  match Hashtbl.find_opt files path with
  | Some a -> a
  | None when surely_missing path ->
      Hashtbl.replace files path Missing;
      Missing
  | None ->
      Hashtbl.replace files path Loading;
      (* natively the answer comes before fetch returns; in a browser,
       * some frames later *)
      Audio.fetch (!the_base ^ "/" ^ path) (fun got -> Hashtbl.replace files path (match got with Some b -> Here b | None -> Missing));
      Hashtbl.find files path

(* "barrel.bmp": barrel *)
let stem (name : string) : string = match String.rindex_opt name '.' with Some i -> String.sub name 0 i | None -> name

(* pure green, to nothing *)
let key (image : Rgba_image.t) : unit =
  let px = image.rgba in
  for i = 0 to (image.width * image.height) - 1 do
    let at = i * 4 in
    if Bigarray.Array1.get px at = 0 && Bigarray.Array1.get px (at + 1) = 255 && Bigarray.Array1.get px (at + 2) = 0 then Bigarray.Array1.set px (at + 3) 0
  done

(* a picture as plain pixels (the website's: see the .mli): its width
 * and its height, 4 bytes each, then 4 bytes a pixel *)
let pixels_ending = ".rgba"

let to_pixels (image : Rgba_image.t) : string =
  let b = Bytes.create (8 + (image.width * image.height * 4)) in
  Bytes.set_int32_le b 0 (Int32.of_int image.width);
  Bytes.set_int32_le b 4 (Int32.of_int image.height);
  for i = 0 to (image.width * image.height * 4) - 1 do
    Bytes.unsafe_set b (8 + i) (Char.unsafe_chr (Bigarray.Array1.unsafe_get image.rgba i))
  done;
  Bytes.to_string b

let of_pixels (bytes : string) : Rgba_image.t option =
  if String.length bytes < 8 then None
  else
    let width = Int32.to_int (String.get_int32_le bytes 0) and height = Int32.to_int (String.get_int32_le bytes 4) in
    if width <= 0 || height <= 0 || width > 8192 || height > 8192 || String.length bytes <> 8 + (width * height * 4) then None
    else begin
      let image = Rgba_image.create ~width ~height in
      for i = 0 to (width * height * 4) - 1 do
        Bigarray.Array1.unsafe_set image.rgba i (Char.code (String.unsafe_get bytes (8 + i)))
      done;
      Some image
    end

let png (b : string) : Rgba_image.t option = match Png.decode b with image -> Some image | exception _ -> None
let bmp (b : string) : Rgba_image.t option = Result.to_option (Bmp.decode b)

(* a picture's file read, whatever it is: by its ending *)
let decode (file : string) (b : string) : Rgba_image.t option =
  match String.lowercase_ascii (Filename.extension file) with ".png" -> png b | ".bmp" -> bmp b | ".rgba" -> of_pixels b | _ -> None

let picture ~(keyed : bool) (folder : string) (name : string) : Rgba_image.t asked =
  match Hashtbl.find_opt pictures (folder, name, keyed) with
  | Some (Here _ as a) | Some (Missing as a) -> a
  | Some Loading | None ->
      let path ending = folder ^ "/" ^ stem name ^ ending in
      let decoded (decode : string -> Rgba_image.t option) (b : string) : Rgba_image.t asked =
        match decode b with
        | Some image ->
            if keyed then key image;
            Here image
        | None -> Missing
      in
      let got =
        if in_browser then match bytes (path pixels_ending) with Here b -> decoded of_pixels b | Loading -> Loading | Missing -> Missing
        else
          match bytes (path ".png") with
          | Here b -> decoded png b
          | Loading -> Loading
          | Missing -> ( match bytes (path ".bmp") with Here b -> decoded bmp b | Loading -> Loading | Missing -> Missing)
      in
      Hashtbl.replace pictures (folder, name, keyed) got;
      got
