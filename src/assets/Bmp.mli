(* Bmp: a Windows bitmap read.

   Soldat's first pictures were .bmp files, as a Windows program's of
   2002 would be: no compression, no transparency (a colour, pure
   green, stood for it). Its content has since been redrawn as PNG, but
   not all of it: 58 pieces of scenery and the 31 edges of the
   textures are still .bmp, and elm-playground reads PNG, GIF and JPEG.

   The format (Microsoft's, from Windows 3.0's, 1990): a file header
   of 14 bytes ("BM", the file's size, where the pixels start), an
   information header (BITMAPINFOHEADER, 40 bytes: width, height, bits
   a pixel, compression), a palette when a pixel is 8 bits or less,
   then the pixels, little-endian throughout. Two things surprise:

   - the rows come bottom first (a height below zero says top first);
   - a row is padded to a multiple of 4 bytes, and a pixel of 24 bits
     is blue, green, red.

   Read here: 24 bits a pixel and 8 bits with a palette, not
   compressed, which is all of Soldat's. Every pixel comes out opaque:
   the green that stands for nothing is Soldat's convention, not the
   format's (Soldat_assets.keyed).

   The worked example, checked by the tests: a picture 2 wide and 2
   high, its bottom row red then green, its top row blue then white,
   is 70 bytes -- 54 of headers, then FF 00 00 (blue first: red is 00
   00 FF) ... each row of 6 bytes padded to 8.
*)

(* the picture these bytes (a .bmp file's) are, or what was wrong with
 * them *)
val decode : string -> (Rgba_image.t, string) result
