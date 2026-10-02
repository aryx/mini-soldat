(* Soldat_engine_bot: one bot that is not Soldat's, on elm-playground's
   ai library. The flag ai=engine puts it in a round, in place of the
   last of Soldat's bots.

   It is here as an example of that library (tiny_libs.ai: Sense and
   Bot), next to a bot written the old way (Soldat_bots, a port of
   Soldat's ControlBot): the two fight in the same round, by the same
   keys, and one can read how each is made.

   **What differs.** Soldat's bot is given the whole round each tick,
   and reads in it what it wants: where everyone is, at once. This one
   is made of three parts the library keeps apart (Bot.mli):

     sense    what it may know of the round, as a value of its own
              ([Soldat_model.senses]): where it is, its speed, its
              fuel, and its nearest enemy as a Sense.target -- seen now
              if nothing of the map is between them, remembered where
              it was last seen for 90 ticks after, then forgotten.
              Nothing else of the round reaches its mind
     decide   its mind: from those senses alone to the keys. Nearer
              than 60 units it backs off, farther than 130 it comes, in
              between it strafes; it jumps and flies when the enemy is
              above; it fires at what it sees, with an error that
              settles the longer the enemy stays in sight
              (Bot.aim_error). Knowing nobody, it patrols
     the loop it acts on senses 12 ticks old (a hand's reaction, a
              fifth of a second) and changes its mind every 4 (no hand
              decides sixty times a second): Bot.make ~delay ~rate

   So it can be surprised, it loses who goes behind a wall and goes to
   where it last saw them, and it never knows what it has not seen: a
   test says so.

   Worked example: an enemy steps out 200 units to its right. For 12
   ticks it does nothing about it: what it acts on is older. Then it
   runs right (200 is farther than 130) and fires, its aim off by up
   to 12 degrees, 6 after 25 ticks in sight, 3 after 50. The enemy
   steps behind a wall: for 90 ticks the bot still goes to where it
   saw it last, without firing; then it patrols again.

   It knows nothing of the map's waypoints, of kits, of grenades, of
   reloading (an empty clip reloads by itself): a small mind, to be
   read.

   In Soldat: nothing; its bots are shared/AI.pas (Soldat_bots).
*)
open Soldat_model

(* its looks, and the weapon it appears with *)
val character : character

(* what soldier [i] may know of a round, from what it knew a tick ago *)
val sense : senses option -> play * int -> senses

(* the keys, from the senses alone *)
val decide : senses -> intent

(* the two, 12 ticks late and every 4 ticks *)
val mind : (play * int, senses, intent) Bot.t
