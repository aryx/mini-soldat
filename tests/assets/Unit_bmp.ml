(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_bmp.mli *)

let u16 (n : int) : string = String.init 2 (fun i -> Char.chr ((n lsr (8 * i)) land 255))
let u32 (n : int) : string = String.init 4 (fun i -> Char.chr ((n asr (8 * i)) land 255))

(* a file: its two headers (and a palette, for 8 bits), then [rows] as
 * they are *)
let bmp ?(bits = 24) ?(palette = "") ~(width : int) ~(height : int) (rows : string) : string =
  let offset = 54 + String.length palette in
  "BM" ^ u32 (offset + String.length rows) ^ u32 0 ^ u32 offset
  ^ u32 40 ^ u32 width ^ u32 height ^ u16 1 ^ u16 bits ^ u32 0 ^ u32 (String.length rows) ^ u32 2835 ^ u32 2835 ^ u32 0 ^ u32 0
  ^ palette ^ rows

(* blue first *)
let red = "\x00\x00\xff" and green = "\x00\xff\x00" and blue = "\xff\x00\x00" and white = "\xff\xff\xff"

(* the worked example: the bottom row red then green, the top row blue
 * then white; each row of 6 bytes padded to 8 *)
let two_by_two = bmp ~width:2 ~height:2 (red ^ green ^ "\x00\x00" ^ blue ^ white ^ "\x00\x00")

let pixel (image : Rgba_image.t) (x : int) (y : int) : int list = List.init 4 (fun k -> Bigarray.Array1.get image.rgba ((((y * image.width) + x) * 4) + k))

let decoded (bytes : string) : Rgba_image.t = match Bmp.decode bytes with Ok image -> image | Error why -> Alcotest.fail why

let tests =
  Testo.categorize "Bmp"
    [
      Testo.create "the worked example" (fun () ->
          Alcotest.(check int) "70 bytes" 70 (String.length two_by_two);
          let image = decoded two_by_two in
          Alcotest.(check (pair int int)) "2 by 2" (2, 2) (image.width, image.height);
          Alcotest.(check (list (list int))) "the top row is the file's last: blue, white; then red, green; all opaque"
            [ [ 0; 0; 255; 255 ]; [ 255; 255; 255; 255 ]; [ 255; 0; 0; 255 ]; [ 0; 255; 0; 255 ] ]
            [ pixel image 0 0; pixel image 1 0; pixel image 0 1; pixel image 1 1 ]);
      Testo.create "rows from the top, a row not padded, a palette" (fun () ->
          let top_first = decoded (bmp ~width:2 ~height:(-2) (red ^ green ^ "\x00\x00" ^ blue ^ white ^ "\x00\x00")) in
          Alcotest.(check (list int)) "a height below zero: the first row is the top" [ 255; 0; 0; 255 ] (pixel top_first 0 0);
          (* 4 pixels of 3 bytes: 12, a multiple of 4 already *)
          let wide = decoded (bmp ~width:4 ~height:1 (red ^ green ^ blue ^ white)) in
          Alcotest.(check (list int)) "4 wide: no padding" [ 255; 255; 255; 255 ] (pixel wide 3 0);
          (* 8 bits: an entry of the palette a pixel, 4 bytes an entry *)
          let palette = "\x00\x00\xff\x00" ^ "\x00\xff\x00\x00" in
          let indexed = decoded (bmp ~bits:8 ~palette ~width:2 ~height:1 "\x01\x00\x00\x00") in
          Alcotest.(check (list (list int))) "with a palette: green, red" [ [ 0; 255; 0; 255 ]; [ 255; 0; 0; 255 ] ] [ pixel indexed 0 0; pixel indexed 1 0 ]);
      Testo.create "what is refused" (fun () ->
          let refused name bytes = Alcotest.(check bool) name true (Result.is_error (Bmp.decode bytes)) in
          refused "nothing" "";
          refused "a PNG" ("\x89PNG\r\n\x1a\n" ^ String.make 60 '\x00');
          refused "cut short" (String.sub two_by_two 0 60);
          refused "16 bits a pixel" (bmp ~bits:16 ~width:2 ~height:2 (String.make 8 '\x00'));
          refused "no width" (bmp ~width:0 ~height:2 "");
          let compressed = Bytes.of_string two_by_two in
          Bytes.set compressed 30 '\x01';
          refused "compressed" (Bytes.to_string compressed));
    ]
