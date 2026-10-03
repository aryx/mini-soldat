(* Soldat_bodies: the things' twin, on the Playground's Physics.

   In Soldat a kit is four points held by six sticks, a weapon two
   held by one (Soldat_things, on Particles): each point falls and
   meets the map by itself, and the sticks pull the shape back. This is
   the same job as elm-playground's Physics layer would have one do it
   first (docs/twins.md): a thing is *one rigid body*, a box that has
   a place, an angle, a speed and a spin, and the map's walls are
   bodies that nothing moves.

       a kit      a box 10.75 by 8.6          Physics.body (rectangle ...)
       a weapon   a box as long as it, 4 high
       a wall     its triangle                 ... |> Physics.immovable

   A tick is [Physics.simulate ~gravity (Physics.world (thing :: walls))]:
   gravity, the contacts between the box and the triangles solved
   together (physics/2d's Collide and Solver), then the move. A box
   landing on a corner tips over, slides down a slope and comes to
   rest flat, which the four points do too, but by another road: there
   the shape is what the sticks restore, here it never changes.

   The thing keeps its points (the view draws them, a soldier reaches
   for them): the body is made from them each tick, its speed and its
   spin from where they were a tick ago, and they are put back at its
   corners after. So the twin keeps nothing of its own: it is a
   function, a thing in, the thing a tick later out.

   The Playground's bodies live in its own coordinates, y upwards, in
   pixels and seconds: a place of the map is turned over as it goes in
   and as it comes out, and a speed is times 60.

   A limit of the engine, found here: a box 2 units thick that lands
   on its end is thrown away at thousands of units a second (the same
   with the Physics layer alone, on a rectangle as on a triangle); 4
   thick, it lands and tips over. So a weapon's body is 4 thick.

   Not here: the flags (a pole held up by a force, a cloth: Particles'
   job), a thing thrown by an explosion.
*)

(* a kit or a weapon a tick later, moved as one rigid body among the
 * map's walls; a flag is given back as it is *)
val move : Soldat_map.t -> Soldat_things.t -> Soldat_things.t
