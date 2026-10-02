(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Bmp.mli *)

let decode (bytes : string) : (Rgba_image.t, string) result =
  let n = String.length bytes in
  let u8 at = Char.code bytes.[at] in
  let i32 at = Int32.to_int (String.get_int32_le bytes at) in
  if n < 54 || String.sub bytes 0 2 <> "BM" then Error "not a BMP file"
  else begin
    let offset = i32 10 and header = i32 14 and width = i32 18 and height = i32 22 in
    let bits = String.get_uint16_le bytes 28 and compression = i32 30 in
    let top_first = height < 0 in
    let height = abs height in
    if header < 40 then Error "a BMP header older than Windows 3.0's"
    else if compression <> 0 then Error "a compressed BMP"
    else if bits <> 24 && bits <> 8 then Error (Printf.sprintf "a BMP of %d bits a pixel" bits)
    else if width <= 0 || height <= 0 || width > 8192 || height > 8192 then Error "a BMP of no size, or too big"
    else begin
      (* a row's bytes, padded to a multiple of 4 *)
      let row = (((width * bits) + 31) / 32) * 4 in
      let palette = 14 + header in
      if offset < palette || offset + (row * height) > n then Error "a BMP cut short"
      else begin
        let image = Rgba_image.create ~width ~height in
        for y = 0 to height - 1 do
          let from = offset + (row * if top_first then y else height - 1 - y) in
          for x = 0 to width - 1 do
            (* blue, green, red: in the pixel itself, or in the palette
             * (4 bytes an entry) *)
            let at = if bits = 24 then from + (x * 3) else palette + (u8 (from + x) * 4) in
            let (b, g, r) = if at + 2 < n then (u8 at, u8 (at + 1), u8 (at + 2)) else (0, 0, 0) in
            let to_ = ((y * width) + x) * 4 in
            Bigarray.Array1.set image.rgba to_ r;
            Bigarray.Array1.set image.rgba (to_ + 1) g;
            Bigarray.Array1.set image.rgba (to_ + 2) b;
            Bigarray.Array1.set image.rgba (to_ + 3) 255
          done
        done;
        Ok image
      end
    end
  end
