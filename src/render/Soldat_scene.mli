(* Soldat_scene: a map as Soldat draws it, in tiles.

   A map's picture is its texture on its polygons, shaded by their
   corners, and its scenery: nothing the Playground can draw as such
   (Soldat_raster says why). So the map is cut in squares of 256 units,
   and each square is drawn once, by Soldat_raster, into a picture of
   512 pixels: a *tile*. A frame then shows the few tiles under the
   camera, as it would any picture.

       the map              the tiles under the camera
     +----+----+----+----+
     |    | ## | ###|    |      each made when the camera comes near,
     +----+--+=======+---+      kept, and thrown away when it is far:
     | ###|##| ##|## |   |      a big map is never drawn whole
     +----+--+=======+---+
     |####|####|####|#   |
     +----+----+----+----+

   Two layers, since soldiers are drawn between them: *behind*, the
   background polygons and the scenery of layer 0; *in front*, the
   scenery of layer 1, the other polygons, the scenery of layer 2
   (Soldat's order: client/GameRendering.pas). The sky is neither: it
   stays the Playground's rectangles.

   **Nothing waits.** The texture and the scenery's pictures are files
   that come when they come (Soldat_assets), and a tile takes a few
   milliseconds to draw. Until what a tile needs has come, and until
   it is drawn, the map is shown as before, its polygons in flat
   colours (Soldat_map.t's back and front), and the tiles are drawn
   over it as they get ready: a tile or two a frame, the nearest the
   camera first, and those just beyond the screen ahead of need. With
   no file at all (no data/ folder), the flat map is what one gets.

   A tile is drawn a pixel wider than its square on each side, and
   shown so: two neighbours overlap, and no seam shows between them
   when the camera scales them.

   In Soldat: client/MapGraphics.pas (the map as vertices: the
   polygons, the props) and client/GameRendering.pas (their order).
   There nothing is drawn ahead: the graphics card fills every
   triangle anew each frame.
*)
open Playground

(* [view map ~centre ~half]: the map's picture for a camera looking at
 * [centre] and seeing [half] units each way from it, in the game's
 * coordinates: what goes behind the soldiers (without the sky), and
 * what goes over them. Shapes of the picture, y upwards. Each call
 * may draw a tile or two more *)
val view : Soldat_map.t -> centre:float * float -> half:float * float -> shape list * shape list

(* a tile's side, in units, and in pixels (without its margin) *)
val side : float
val pixels : int

(* the tiles drawn so far and kept, for this map: for the tests and
 * the curious *)
val drawn : Soldat_map.t -> int
