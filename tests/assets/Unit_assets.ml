(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_assets.mli *)

(* 3 by 2, every byte its own *)
let picture () : Rgba_image.t =
  let image = Rgba_image.create ~width:3 ~height:2 in
  for i = 0 to 23 do
    Bigarray.Array1.set image.rgba i (i * 10)
  done;
  image

let bytes_of (image : Rgba_image.t) : int list = List.init (image.width * image.height * 4) (Bigarray.Array1.get image.rgba)

let tests =
  Testo.categorize "Assets"
    [
      Testo.create "a picture as pixels, and back" (fun () ->
          let pixels = Soldat_assets.to_pixels (picture ()) in
          Alcotest.(check int) "8 bytes of size, 4 a pixel" (8 + 24) (String.length pixels);
          Alcotest.(check string) "its width, its height" "\x03\x00\x00\x00\x02\x00\x00\x00" (String.sub pixels 0 8);
          match Soldat_assets.decode "any.rgba" pixels with
          | None -> Alcotest.fail "not read back"
          | Some back ->
              Alcotest.(check (pair int int)) "3 by 2" (3, 2) (back.width, back.height);
              Alcotest.(check (list int)) "the same bytes" (bytes_of (picture ())) (bytes_of back));
      Testo.create "a file read by its ending" (fun () ->
          let pixels = Soldat_assets.to_pixels (picture ()) in
          Alcotest.(check bool) "pixels cut short: nothing" true (Soldat_assets.decode "a.rgba" (String.sub pixels 0 20) = None);
          Alcotest.(check bool) "pixels whose size lies: nothing" true (Soldat_assets.decode "a.rgba" ("\x09" ^ String.sub pixels 1 31) = None);
          Alcotest.(check bool) "a .png that is none: nothing" true (Soldat_assets.decode "a.png" "not a png" = None);
          Alcotest.(check bool) "a .bmp that is none: nothing" true (Soldat_assets.decode "a.BMP" "not a bmp" = None);
          Alcotest.(check bool) "an ending it does not know: nothing" true (Soldat_assets.decode "a.gif" pixels = None));
      Testo.create "a file that is not there" (fun () ->
          Soldat_assets.reset ();
          Soldat_assets.set_base "no/such/folder";
          Alcotest.(check bool) "not in a browser" false Soldat_assets.in_browser;
          Alcotest.(check bool) "missing, at once" true (Soldat_assets.bytes "maps/Arena2.pms" = Missing);
          Alcotest.(check bool) "and so is a picture, its .png and its .bmp" true (Soldat_assets.picture ~keyed:true "scenery-gfx" "barrel.bmp" = Missing);
          Alcotest.(check int) "nothing left waiting" 0 (Soldat_assets.pending ()));
    ]
