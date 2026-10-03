(* Soldat_orig: Soldat's own parts, put in the game's slots.

   [register ()] gives the game Soldat's bots, its sparks and its
   camera, its way for a thing to fall, and their pictures
   (Soldat_parts.mli, Soldat_view): called once, when a program
   starts, by the programs linked with this folder.
*)
val register : unit -> unit
