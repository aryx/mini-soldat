(* Soldat_things: what lies on the map and can be picked up.

   Three kinds here, of Soldat's 27: a weapon let go of (thrown away,
   or by the dead), a medikit, a kit of grenades.

   A thing is a few particles joined by sticks, as a dead soldier is
   (Jakobsen's: elm-playground's Particles), falling and coming to
   rest on the map:

       a weapon   o             a kit    4 o-----o 3     10.75 wide,
                  |  2                     | \ / |       8.6 high: 4
                  |                        | / \ |       sides and 2
                  o  1                   1 o-----o 2     diagonals

   a weapon one stick, as long as the weapon is heavy (the USSOCOM 4
   units, the Ak-74 14.8, the minigun 22), each with its own drag and
   weight (Things.pas's VDamping and GravityMultiplier). A tick, in
   Soldat's order (TThing.Update): each point in a wall is put back
   where it was, less its depth along the wall's perp; then the Verlet
   step and the sticks, once. When two of its points have touched the
   map and it moves less than 0.63 a tick, it is *still*, and no longer
   stepped at all.

   **Thrown.** A weapon appears at the hand that held it (point 16),
   its first point given the soldier's speed and its second that plus
   3 units towards the cursor (0.64 if its owner just died): it leaves
   spinning, the way one aims.

   **Picked up** (the server's CheckSpriteCollision): by the nearest
   living soldier within its radius (10 a weapon, 12 a kit) of its
   middle or of either of its first two points:

     a weapon     by empty hands only, half a second after it was let
                  go; it keeps the rounds it had. Gone after 20 seconds
     a medikit    by who is hurt: all its health back
     a grenade kit by who has fewer than 2: 2

   and a kit taken appears again at once at another of the map's
   places for it (its spawn points of "team" 8 for medikits, 7 for
   grenades), not the one it was at.

   **A flag** is four points: a pole of 24 units, its foot first, and
   a cloth at its top.

                 2 o-----o 3
                   |     |       Bravo's; Alpha's cloth is on the
                   |     o 4     other side, so that the two face
                   |    /        each other
                 1 o---

   Standing, its foot stops on the ground and a force upwards on its
   top (16 times gravity) keeps the pole up, as a float keeps a line:
   leaning, for its cloth has no stiffness and its lower corner falls
   to the ground, 15.6 from the foot, pulling the top its way.
   Carried, its foot is at its carrier's waist (the skeleton's point
   8) and the same force, 14 times gravity, holds it over the
   shoulder; the cloth trails behind by its sticks alone. It is *at
   home* within 75 units of the place the map gives it; left on the
   ground elsewhere for 25 seconds, it goes back there by itself. Who
   takes it and what a capture is are the round's rules
   (Soldat_update): this module only makes it fall and follow.

   **Rambo's bow** is a weapon on the ground as the others, with two
   differences: it is reached from 20 units and not 10, and it may be
   taken only 100 ticks after it appeared. Whoever lets it go, with
   whichever arrows on it, lets go of the bow.

   **A bonus kit** (the flamer's, the predator's, the vest's, the
   berserker's, the cluster grenades') is a box as the two others,
   appearing now and then at the map's places for it (the round's
   rule, Soldat_update) and gone after 25 seconds if nobody took it.

   Left out: the parachute, the stationary gun; a thing hit by a
   bullet or thrown by an explosion.

   In Soldat: shared/mechanics/Things.pas (CreateThing, TThing.Update,
   CheckMapCollision, CheckSpriteCollision, Respawn, SpawnBoxes) and
   TSprite.DropWeapon (Sprites.pas).
*)

(* [Flag team]: Alpha's (1) or Bravo's (2) *)
(* the five bonus kits (OBJECT_FLAMER_KIT to OBJECT_CLUSTER_KIT) *)
type bonus = Flamer_kit | Predator_kit | Vest_kit | Berserker_kit | Cluster_kit
type kind = Weapon of Soldat_soldier.gun | Medikit | Grenade_kit | Flag of int | Bonus of bonus

type t = {
  kind : kind;
  (* 2 for a weapon, 4 for a kit *)
  points : Particles.particle array;
  (* ticks left: a weapon is gone at 0; a kit's is not used *)
  ttl : int;
  (* ticks a bot may still walk to it (Interest): each look takes one *)
  interest : int;
  (* at rest *)
  still : bool;
  (* which way its owner faced: which of its two pictures *)
  facing : int;
  (* a kit: the place it is at, among the map's for its kind; else -1 *)
  place : int;
  (* times its points have met the map *)
  hits : int;
  (* a flag: the soldier that carries it (none: -1), and whether it is
   * within 75 units of where it stands *)
  holder : int;
  in_base : bool;
}

(* GUNRESISTTIME: a weapon's 20 seconds; it may be picked up once 30
 * ticks of them are gone *)
val gun_time : int

(* sv_maxgrenades: what a grenade kit fills up to *)
val max_grenades : int

(* the weapon a soldier let go of: [alive], thrown; else dropped dying *)
val weapon : Soldat_soldier.t -> alive:bool -> Soldat_soldier.gun -> t

(* Rambo's bow lying at a place (OBJECT_RAMBO_BOW): a weapon as any
 * other on the ground, but wider to reach (20) and one the bots walk
 * to; and whether a thing is it *)
val bow : float * float -> t

(* any weapon lying at a place, as a knife thrown is where it fell *)
val lying : Soldat_weapons.id -> float * float -> t
val is_bow : t -> bool

(* a bonus kit appearing at one of the map's places for it (a
 * soldier's, on a map that has none); gone 25 seconds later *)
val bonus : Soldat_map.t -> random:(unit -> float) -> bonus -> t option

(* the map's kits at a round's start (SpawnThings): as many as the map
 * says, each at one of its places for that kind, moved by chance up
 * to 25 units; none of a kind the map has no place for. [random]: the
 * game's next number from 0 to 1 *)
val kits : Soldat_map.t -> random:(unit -> float) -> t list

(* a kit taken, or fallen out of the map: at another place (Respawn);
 * a flag: back at home, standing, carried by nobody *)
val again : Soldat_map.t -> random:(unit -> float) -> t -> t

(* a tick later; [heard] is added what was heard of it (its fall on
 * the ground). [carried]: a flag's carrier's waist, where its foot
 * then is. A flag whose [ttl] is 0 has been on the ground too long:
 * the game puts it [again] at home. None: gone (a weapon whose time is over, or out of
 * the map). A kit out of the map is given back as it is: [lost] says
 * so, and the game puts it [again] *)
val tick :
  ?heard:Soldat_event.t list ref -> ?carried:float * float -> ?move:(?heard:Soldat_event.t list ref -> Soldat_map.t -> t -> t) -> Soldat_map.t -> t -> t option

(* what the parts that move a thing need of it (src/orig/Soldat_fall,
 * src/twin/Soldat_bodies): a point of it out of the walls it is in,
 * if it is in one; its sticks; its drag and weight; how little it
 * must move to be at rest *)
val out_of_walls : Soldat_map.t -> Particles.particle -> Particles.particle option
val sticks : t -> Particles.stick list
val physics : kind -> float * float
val min_move_delta : float

(* a team's flag standing at home, and both: none on a map that has no
 * place for them *)
val flag : Soldat_map.t -> int -> t option
val flags : Soldat_map.t -> t list

(* the yellow flag ([Flag 0]) of a Pointmatch and of Hold the Flag:
 * anybody's, at home nowhere, at one of the map's places for it *)
val yellow : Soldat_map.t -> random:(unit -> float) -> t

(* TOUCHDOWN_RADIUS: a flag carried within this of the other at home
 * is a capture *)
val touchdown_radius : float
val lost : Soldat_map.t -> t -> bool

(* the kinds of wall a thing lies on (TThing.CheckMapCollision) *)
val holds : Pms.kind -> bool

(* how far a point (a soldier's particle) is from the thing, if within
 * its radius *)
val reach : t -> float * float -> float option

(* the middle of its first two points: where one walks to, and looks *)
val middle : t -> float * float
