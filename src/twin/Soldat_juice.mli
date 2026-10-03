(* Soldat_juice: the sparks' twin, on the Playground's Juice.

   Soldat's sparks (Soldat_sparks, from Sparks.pas) are sixteen kinds
   of small things, each with its own rule: a shell that bounces and
   clinks, a drop of blood that falls, a smoke that rises and fades.
   This is the same job as elm-playground's juice library would have
   one do it first (docs/twins.md): no kinds, but a *recipe* for each
   thing that happens,

       a hit        20 red dots, thrown all around, falling
       a wall hit   6 grey chips, falling
       a shot       2 puffs of smoke, rising
       an explosion 40 dots of fire and 12 of smoke; and the screen shakes

   and three of its modules:

     Emitter   [burst recipe x y] makes the dots, [step] moves them
               and ends them when their life is over
     Trauma    [add] at an explosion, [decay] each tick, [offset] what
               the camera is moved by: a number that says how shaken
               the screen is, as Squirrel Eiserloh's talk has it
     Follow    [smooth], the camera going after its soldier a part of
               the way each tick (Soldat_update)

   Its dots are the emitter's: they live in the Playground's own
   coordinates, y upwards, in pixels and seconds, so a place of the
   map is turned over as it goes in, and the view draws them as they
   are. A tick is a sixtieth of a second.

   **Limits met here, and what is done about each.**

   1. *The emitter's world is the Playground's*: y upwards, pixels,
      seconds, degrees. The map's is y downwards, units, ticks. A
      place is turned over as it goes in ([of_event]) and the dots
      are drawn as they are, inside the camera, which turns the map
      over the same way; a tick is a step of a sixtieth of a second.

   2. *Its chance is its own.* An emitter draws from the seed it was
      made with, not from the round's: the dots are the same from a
      run to the next, but are no part of what a round replays, and
      two programs in lockstep may show different ones.

   3. *At most 400 dots* (the cap given to Emitter.empty): a long
      fight drops the oldest.

   Not here: what Soldat's sparks do that a recipe does not say (a
   shell on the ground, the blood left on a wall, an explosion's 16
   pictures): the effects' level 2 is for that.
*)

(* what a dot is, for its colour *)
type kind = Blood | Chip | Smoke | Fire

type t

val none : t

(* what a thing that happened adds *)
val of_event : t -> Soldat_event.t -> t

(* a tick later *)
val step : t -> t

(* the dots: where each is (y upwards), how big, what it is, and how
 * much of its life is left, from 1 to 0 *)
val dots : t -> (float * float * float * kind * float) list

(* what the camera is moved by, in the map's units *)
val shake : t -> float * float

(* a round's dots (Soldat_state) *)
type Soldat_state.fx += Juice of t
val of_fx : Soldat_state.fx -> t

(* the twin as the game's effects, with its camera (Follow): what
 * Soldat_twin registers *)
val part : Soldat_parts.effects
