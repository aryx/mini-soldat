(* Soldat_fall: how a thing falls and lands, Soldat's way.

   A kit is four points held by six sticks, a weapon two held by one
   (Soldat_things.mli): each point that is in a wall is put back out
   of it, then all take a Verlet step and the sticks pull the shape
   back, once (elm-playground's Particles: step, relax). When two of
   its points have met the map and it moves less than 0.63 a tick, it
   is at rest.

   Its twin is src/twin/Soldat_bodies: the same thing as one rigid body.

   In Soldat: TThing.Update (shared/mechanics/Things.pas).
*)

(* a thing that is not at rest, a tick later; [heard]: its fall on the ground *)
val move : ?heard:Soldat_event.t list ref -> Soldat_map.t -> Soldat_things.t -> Soldat_things.t
