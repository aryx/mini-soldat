(* Soldat_tumble: how a dead body falls, Soldat's way.

   A dead soldier is its skeleton let loose (Soldat_ragdoll): twenty
   points and the sticks between them. Each tick, a point that is in
   a wall is put back out of it (its fall is heard, and a bone's
   crack when it lands hard), then all take a Verlet step and the
   sticks that still hold pull the shape back, once (elm-playground's
   Particles: step, relax).

   Its twin is src/twin/Soldat_limbs: the same body as ten rigid limbs
   held by joints.

   In Soldat: TSprite.Update's dead branch and CheckSkeletonMapCollision
   (shared/mechanics/Sprites.pas).
*)

(* a dead body a tick later; [heard]: its fall, its bones *)
val tick : ?heard:Soldat_event.t list ref -> Soldat_map.t -> Soldat_ragdoll.t -> Soldat_ragdoll.t
