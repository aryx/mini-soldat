(* Soldat_raster: Soldat's triangles and sprites, drawn into pixels.

   Soldat draws its map with a graphics card: each polygon a triangle
   whose three corners have a place in the map's texture (u, v) and a
   colour, the card filling the triangle with the texture, each pixel
   multiplied by the colour blended from the three corners. The
   Playground draws flat polygons and whole pictures, nothing between.
   So the map is drawn here, by hand, once, into pictures (*tiles*)
   that the Playground then shows (Soldat_scene).

   **A triangle** is filled pixel by pixel, the way a card does it. For
   a pixel's middle p, three weights say how near it is to each corner
   (its *barycentric coordinates*: the areas of the three triangles p
   makes with the edges, over the whole triangle's area). All three
   positive: p is inside. And the same weights blend whatever the
   corners carry: their u and v, giving the texture's pixel to take,
   and their colours (Gouraud's shading, 1971), which multiplies it.

         a                 p = wa a + wb b + wc c,  wa + wb + wc = 1
        / \                u(p) = wa ua + wb ub + wc uc
       /  p\               colour(p) = texture (u(p), v(p)) x (wa ca + wb cb + wc cc)
      b-----c

   The texture repeats: a u of 3.2 is its 0.2 (Soldat's GFX_REPEAT),
   which is how one small picture of rock covers a map.

   **A sprite** (a piece of scenery) is a picture stretched over a
   rectangle, turned, scaled each way, tinted. It is drawn backwards:
   for each pixel of the tile, where in the picture does it come from?
   (the inverse of the transform), which leaves no hole whatever the
   stretch.

   **Blending.** What is drawn goes *over* what is there, by its
   alpha (Porter and Duff's "over", 1984): a tile starts transparent,
   and ends with the map's polygons opaque where they are.

   References: Henri Gouraud, "Continuous Shading of Curved Surfaces"
   (1971); Juan Pineda, "A Parallel Algorithm for Polygon
   Rasterization" (SIGGRAPH 1988), the edge functions used here;
   Thomas Porter and Tom Duff, "Compositing Digital Images" (SIGGRAPH
   1984).

   In Soldat: OpenGL, through client/Gfx.pas (GfxDraw, a vertex being
   x, y, u, v and a colour).
*)

(* a square of the map as pixels: its top left corner in the map
 * (Soldat's coordinates, y downwards, as a picture's rows), and how
 * many pixels a unit is *)
type tile = { image : Rgba_image.t; left : float; top : float; scale : float }

(* a transparent tile of [pixels] by [pixels] *)
val tile : left:float -> top:float -> scale:float -> pixels:int -> tile

(* a triangle's corner: where in the map, where in the texture, and
 * its colour (red, green, blue, alpha, each 0 to 255) *)
type corner = { x : float; y : float; u : float; v : float; r : float; g : float; b : float; a : float }

(* the triangle, filled with the texture times the corners' colours;
 * without a texture, with the colours alone *)
val triangle : tile -> Rgba_image.t option -> corner -> corner -> corner -> unit

(* a picture as Soldat places a prop: stretched over [w] by [h] units,
 * scaled [sx] by [sy], turned by [rotation] about the point one unit
 * under its corner, that corner then at (x, y); each pixel multiplied
 * by the colour (red, green, blue, alpha, 0 to 255) *)
val sprite :
  tile -> Rgba_image.t -> x:float -> y:float -> w:float -> h:float -> sx:float -> sy:float -> rotation:float -> color:int * int * int * int -> unit

(* the corners of that rectangle in the map, in turn: what it covers *)
val sprite_corners : x:float -> y:float -> w:float -> h:float -> sx:float -> sy:float -> rotation:float -> (float * float) list

(* the picture at half its size, each pixel the mean of four: for a
 * texture finer than the tile it is drawn into *)
val halved : Rgba_image.t -> Rgba_image.t
