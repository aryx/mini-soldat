(* Soldat_twin: the twins, put in the game's slots.

   [register ()] gives the game the Playground's bots, its dots, its
   shake and its camera, a thing as a rigid body, the sound's place by
   Space, and the lobby's widgets (Soldat_parts.mli, Soldat_view,
   Soldat_sound): called once, when a program starts, by the programs
   linked with this folder.
*)
val register : unit -> unit
