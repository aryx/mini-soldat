(* Soldat_state: what a part keeps from a tick to the next.

   The parts of the game that are made twice (docs/twins.md: Soldat's
   port in src/orig, the same job on elm-playground's libraries in
   src/twin) each keep something of their own: Soldat's bot its
   Brain, the Playground's its senses; Soldat's sparks a list, Juice
   an emitter. A round holds them without knowing what they are: these
   two types are *open* (OCaml's extensible variants), each part adds
   its own case where it is written, and the round's code, here, sees
   only that there is a mind and an effect.

       type mind += Brain of brain          in src/orig/Soldat_bots.ml
       type mind += Mind of ...             in src/twin/Soldat_engine_bot.ml

   So the shared code names no part, and a program is whole with
   either folder alone.
*)

(* what a soldier's keys come from: a player ([Nobody]'s mind), or a
 * bot's, which a part adds *)
type mind = ..
type mind += Nobody

(* what is seen of what happened, and is no rule's: nothing, or a
 * part's own *)
type fx = ..
type fx += Nothing

(* how many of them at most (the flag sparks=): 558, Soldat's
 * MAX_SPARKS, or 150 in a browser *)
val most : int ref
