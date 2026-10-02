(* Soldat_gostek: the soldier as Soldat draws it, a picture on each
   limb.

   A soldier's body is 20 points (Soldat_soldier). Its look is a
   table: for each part a picture, the two points of the skeleton it
   hangs between, and where in the picture the first point is.

     part            picture    from  to    what tints it
     Left_Thigh      udo          6    3    the trousers
     Left_Foot       stopa        2   18
     Left_Lowerleg   noga         3    2    the trousers
     Left_Arm        ramie       11   14    the shirt
     Left_Forearm    reka        14   15    the shirt
     Left_Hand       dlon        15   19    the skin
     Right_Thigh     udo          5    4    the trousers
     Right_Foot      stopa        1   17
     Right_Lowerleg  noga         4    1    the trousers
     Chest           klata       10   11    the shirt
     Hip             biodro       5    6    the shirt
     Head            morda        9   12    the skin
     Helmet          helm         9   12    the shirt
     the gun in the hands        16   15
     Right_Arm       ramie       10   13    the shirt
     Right_Forearm   reka        13   16    the shirt
     Right_Hand      dlon        16   20    the skin

   drawn in that order, the left side first: it is the far one, and
   the right arm comes last, over the gun it holds. The names are
   Polish: udo the thigh, noga the leg, stopa the foot, ramie the arm,
   reka the hand (here the forearm), dlon the palm, klata the chest,
   biodro the hip, morda the mug.

   **Placing a part.** With (x1, y1) and (x2, y2) its two points, the
   picture is turned to lie along the line from the first to the
   second, and put so that its *pivot*, a place in the picture given
   as fractions of its width and height (cx, cy), is on the first
   point (one unit lower: Soldat's "y1 + 1"). A thigh and a forearm
   stretch with the distance between their points, up to half as long
   again (their "flex").

   **Facing left** the skeleton is mirrored, and so must each picture
   be, across its own length. Most parts have a second picture drawn
   for that (udo2, morda2...), used with its pivot's cy turned to 1 -
   cy; the forearms have none and are turned over.

   **The size.** The pictures are 4.5 times bigger than they are
   drawn (mod.ini's DefaultScale): a head of 27 pixels is 6 units.

   **The colours.** A picture is grey, and multiplied by a colour: the
   shirt's, the trousers', the skin's. The Playground draws a picture
   as it is, and neither tints nor turns one over: so each picture
   that is needed is made once, tinted, turned over if need be, and
   kept ([picture]), the same one given back each time, which is what
   lets a backend keep what it made of it.

   Not yet: the hair, the vest, the chain, the blood on a wounded
   soldier's limbs, the second team's pictures, the grenades on the
   belt, the other weapons, a clip, a muzzle's fire.

   In Soldat: client/GostekGraphics.pas (RenderGostek, DrawGostekSprite)
   and its table, client/GostekGraphics.inc.
*)
open Playground

(* a soldier's three colours, each red, green and blue from 0 to 255 *)
type colors = { shirt : int * int * int; trousers : int * int * int; skin : int * int * int }

(* what tints a part *)
type tint = Plain | Shirt | Trousers | Skin

type part = {
  name : string;
  image : string; (* its picture: a file of data/, without ".png" *)
  from_ : int; (* the two points of the skeleton, by Soldat's numbers *)
  to_ : int;
  cx : float; (* the pivot, in the picture's width and height *)
  cy : float;
  left : string option; (* the picture it has for facing left; none: its own, turned over *)
  flex : float; (* it stretches: the distance at which it is its own length; 0: it does not *)
  tint : tint;
}

(* the parts of a living soldier standing on its feet, in the order
 * they are drawn *)
val parts : part list

(* where a part's picture goes: its middle, in the game's coordinates
 * (y downwards), its width and height in units, the angle it is
 * turned by (radians, clockwise on the screen), which picture, and
 * whether that picture is turned over *)
type placed = { x : float; y : float; width : float; height : float; angle : float; picture : string; turned_over : bool }

(* [place part p1 p2 direction]: the part between its two points, for
 * a soldier facing right (1) or left (-1) *)
val place : part -> float * float -> float * float -> int -> placed

(* the soldier: [point n] is where point [n] of its skeleton is (1 to
 * 20), in the game's coordinates. [jets]: its feet are its jets';
 * [dead]: its head hangs. The shapes are the picture's: y upwards *)
val view : colors -> point:(int -> float * float) -> direction:int -> jets:bool -> dead:bool -> shape list

(* a picture's size, in units: its pixels over 4.5 *)
val size : string -> float * float

(* [picture name colour turned_over]: the picture of that name (a file
 * of data/, without ".png"), each pixel multiplied by the colour, its
 * rows from the bottom if turned over. Made once: asked again, the
 * very same one *)
val picture : string -> int * int * int -> bool -> Rgba_image.t
