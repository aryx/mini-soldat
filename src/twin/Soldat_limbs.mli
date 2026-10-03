(* Soldat_limbs: the dead body's twin, on the Playground's Physics.

   Soldat's dead soldier is its skeleton let loose: twenty points,
   each falling by itself, and the sticks between them pulling the
   shape back (src/orig/Soldat_tumble, on Particles). This is the same
   body as elm-playground's Physics layer would have one make it
   first (docs/twins.md): *ten rigid limbs held by joints*.

                  (head)
                    |  9          a limb is a box between two of the
        13--10--(torso)--11--14   skeleton's points; a joint, a pin
        |           |        |    where two limbs meet: they stay
        16        5   6      15   together there, free to turn
                  |   |
                  4   3           Physics.body (rectangle ...)
                  |   |           Physics.pin a b ~at
                  1   2           Physics.rope ~length a b ...

   Nine pins: the neck, two shoulders, two elbows, two hips, two
   knees.

   A tick is four small steps of Physics.simulate among the walls
   around the body. As the things' twin, it keeps nothing of its own:
   the limbs are made each tick from the skeleton's points, going as
   the points went, and the points put back where their limb took
   them.

   **The engine's limits met here, and what is done about each**
   (Soldat_bodies.mli has those of any body: the one step a tick, a
   speed that is no speed, the grip, the rest; these are a jointed
   body's. The code says "Limit" where it works around one).

   6. *No way to say "these two do not collide".* A body seen from
      the side has its arms over its chest and one leg over the
      other: its limbs overlap all the time, and the engine makes any
      two bodies that overlap push each other apart, unless a joint
      holds them together (a seesaw sits on its pivot).
      Done about it: every two limbs that no pin joins are given a
      rope 10,000 units long, which is never taut, pulls nothing, and
      only makes them "joined": 36 ropes for ten limbs.
      Better: a group, or a mask, on a body.

   7. *A joint is made from where the bodies are now, and gives a
      little.* A pin is solved with the contacts, a few times a step,
      and what is left of its error is taken back a part each step:
      between two steps the two limbs are a little apart at their
      joint. Rebuilt each tick from the points, that gap became the
      limb's new length: an arm of 2.29 units was 3.88 long after 400
      ticks.
      Done about it: a limb is not put back where its body went, but
      turned as its body turned *about the joint it hangs from*,
      where its parent took that joint (the torso first, then
      outwards). So a limb keeps its length to the last digit, and
      no joint can come apart: the engine says how each limb turns,
      the skeleton says where it is.

   Not here: a limb cut off (the head of who dies of a headshot stays
   on); the sounds of the fall.
*)

(* a dead body a tick later *)
val tumble : Soldat_map.t -> Soldat_ragdoll.t -> Soldat_ragdoll.t
