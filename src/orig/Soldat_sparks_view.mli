(* Soldat_sparks_view: the sparks, drawn (TSpark.Render).

   Each kind of spark is a picture of Soldat's (sparks-gfx/, and the
   weapons' shells and clips of weapons-gfx/), shown at the spark's
   place more or less faded by the life it has left, some turning,
   some growing as they fade:

     a chip, a spark   a dot of 1 unit; a spark yellow or grey
     blood             a drop, bigger as it ends; a splat where it fell
     a shell, a clip   its weapon's, turning 4 degrees a tick of life
     smoke             a puff, fading with its life
     an explosion      16 pictures of 71 by 100 units shown in turn, 3
                       or 4 ticks each (the frame is 16 - life / 4),
                       the one before under it
     its ring          10 pictures of smoke, the same way, over its
                       last 40 ticks
     its big smoke     two pictures growing from 0.56 to 0.82 of their
                       size over 3 seconds, hardly there at first

   The pictures are files of the content, asked through Soldat_assets:
   a spark whose picture has not come is not drawn. The Playground
   tints no picture: the two colours of a spark are two pictures made
   once ([warm] asks for them all, so that the first explosion of a
   round does not wait for its 16).

   In Soldat: TSpark.Render (shared/mechanics/Sparks.pas).
*)
open Playground

(* the sparks, as shapes of the picture (y upwards) *)
val view : Soldat_sparks.t list -> shape list

(* ask for every picture a spark may need: how many have not come yet *)
val warm : unit -> int
