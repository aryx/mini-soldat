(* Soldat_bodies: the things' twin, on the Playground's Physics.

   In Soldat a kit is four points held by six sticks, a weapon two
   held by one (Soldat_things, on Particles): each point falls and
   meets the map by itself, and the sticks pull the shape back. This is
   the same job as elm-playground's Physics layer would have one do it
   first (docs/twins.md): a thing is *one rigid body*, a box that has
   a place, an angle, a speed and a spin, and the map's walls are
   bodies that nothing moves.

       a kit      a box 10.75 by 8.6          Physics.body (rectangle ...)
       a weapon   a box as long as it, 2 high
       a wall     its triangle                 ... |> Physics.immovable

   A step is [Physics.simulate ~gravity (Physics.world (thing :: walls))]:
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

   **The engine's limits met here, and what is done about each.**
   Found by running it, each with the numbers that showed it; the
   code says the same where it works around one (look for "Limit").

   1. *One step a tick* ([small_steps]). Physics.simulate is one step
      of a sixtieth of a second, with no test along the way. A weapon
      2 units thick, on its end, falls 3.3 a tick when it reaches the
      floor: after the step it is 3.2 deep in it, deeper than it is
      wide. The collision's test takes the axis along which the two
      overlap least, which is then across the weapon, not up: it is
      pushed out sideways, each tick harder, and leaves at 10,000
      units a second (the same with the Physics layer alone, on a
      rectangle as on a triangle; a box 4 thick is not thrown).
      Done about it: four small steps a tick. A step four times
      shorter is the same step on speeds four times smaller, under a
      gravity sixteen times smaller: that is what is asked, four
      times, and the speeds are put back. A free fall is then
      0.06 / 16 x (1 + 2 + 3 + 4) = 0.0375 in its first tick, where
      one step gives 0.06 (the tests say so).
      Better: a [?steps] in Physics.simulate.

   2. *What the solver moves a body out of a wall by is no speed.*
      A body has a speed and a spin, a thing only its points, each
      with where it was a tick ago; the first version read the body's
      speed back from how far its points had moved. But a step also
      moves a body out of what it is in, and that move, read as a
      speed, came back the next tick as a real one: a weapon that
      had landed went on sliding along the floor and never stopped.
      Done about it: a point's "a tick ago" is written from the
      body's own speed and spin after the step, not from where the
      point was.

   3. *Grip is the two bodies' together.* The engine's friction for
      a contact is the square root of the product of the two
      roughnesses (as Box2D's), and a body's is 0 unless said: a wall
      left at 0 makes everything on it slide without end (a dead body
      went 840 units on a flat floor).
      Done about it: the walls are given a roughness too (0.8).

   4. *A polygon's corners go counterclockwise.* A map's triangles go
      either way, and turning y over turns them the other: each is
      put counterclockwise before it is given. (Not checked whether
      the engine minds; it costs a line.)

   5. *At rest.* The engine has no sleep: a thing would be stepped for
      ever. It is called still when it is slow (under 12 units a
      second, 20 degrees a second) and *held*: a body falling free
      gains a tick's gravity each tick, one that lies on something
      does not. Slow alone is not enough: a thing just let go is slow.

   Not here: the flags (a pole held up by a force, a cloth: Particles'
   job), a thing thrown by an explosion.
*)

(* a kit or a weapon a tick later, moved as one rigid body among the
 * map's walls; a flag is given back as it is *)
val move : Soldat_map.t -> Soldat_things.t -> Soldat_things.t

(* a tick of a world in [n] steps: the wall of a map as a body nothing
 * moves, for the other twin that needs them (Soldat_limbs) *)
val small_steps : int -> gravity:float -> Physics.world -> Physics.world
val wall : Soldat_map.wall -> Physics.body
