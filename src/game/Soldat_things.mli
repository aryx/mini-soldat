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

   Left out: the flags, the bow, the bonus kits (flamer, predator,
   vest, berserker, cluster), the parachute, the knife, the stationary
   gun; a thing hit by a bullet or thrown by an explosion.

   In Soldat: shared/mechanics/Things.pas (CreateThing, TThing.Update,
   CheckMapCollision, CheckSpriteCollision, Respawn, SpawnBoxes) and
   TSprite.DropWeapon (Sprites.pas).
*)

type kind = Weapon of Soldat_soldier.gun | Medikit | Grenade_kit

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
}

(* GUNRESISTTIME: a weapon's 20 seconds; it may be picked up once 30
 * ticks of them are gone *)
val gun_time : int

(* sv_maxgrenades: what a grenade kit fills up to *)
val max_grenades : int

(* the weapon a soldier let go of: [alive], thrown; else dropped dying *)
val weapon : Soldat_soldier.t -> alive:bool -> Soldat_soldier.gun -> t

(* the map's kits at a round's start (SpawnThings): as many as the map
 * says, each at one of its places for that kind, moved by chance up
 * to 25 units; none of a kind the map has no place for. [random]: the
 * game's next number from 0 to 1 *)
val kits : Soldat_map.t -> random:(unit -> float) -> t list

(* a kit taken, or fallen out of the map: at another place (Respawn) *)
val again : Soldat_map.t -> random:(unit -> float) -> t -> t

(* a tick later; [heard] is added what was heard of it (its fall on
 * the ground); None: gone (a weapon whose time is over, or out of
 * the map). A kit out of the map is given back as it is: [lost] says
 * so, and the game puts it [again] *)
val tick : ?heard:Soldat_event.t list ref -> Soldat_map.t -> t -> t option
val lost : Soldat_map.t -> t -> bool

(* how far a point (a soldier's particle) is from the thing, if within
 * its radius *)
val reach : t -> float * float -> float option

(* the middle of its first two points: where one walks to, and looks *)
val middle : t -> float * float
