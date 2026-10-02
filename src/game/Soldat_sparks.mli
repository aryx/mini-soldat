(* Soldat_sparks: what is only for the eye. Blood, shells and clips
   falling, smoke, the fire of an explosion and of the jets, the chips
   a bullet takes off a wall.

   A spark is a particle with a kind and a life in ticks: it moves as
   a soldier's particle does, lighter (gravity 0.06 / 1.4 a tick, 0.998
   of its speed kept), and is gone when its life is over. Some do not
   move at all (an explosion's fire is 16 pictures shown in turn where
   it happened); some meet the map: a shell bounces (0.7 of its speed
   kept, less what went into the wall), clinks at its first, third and
   fifth bounce, and is gone at the sixth; a drop of blood leaves a
   splat where it lands.

   Nothing of the game reads a spark: no rule depends on one. They are
   in the round's state all the same, so that a frame is a function of
   it and a round replays with the same sparks; their chance (how far
   a chip flies, which way a shell goes) is a seed of their own, apart
   from the game's, so that drawing them or not changes no shot.

   **From events.** The game says what happened (Soldat_event: a shot,
   a bullet in a wall), and [of_event] makes of it the sparks Soldat's
   client makes at that place in its code, and the sounds:

     a shot            its shell, thrown across the way one aims, and a
                       puff at the muzzle; two for the Eagles; none for
                       the shotgun, whose shell leaves when it is pumped
     a clip let go     the weapon's clip, falling from the hand
     a bullet in a     three chips and a little smoke, thrown back from
     wall              the wall; one of four sounds
     a ricochet        six sparks; one of three sounds
     a bullet in a     drops of blood along its way, 4 to 6, and by
     body              chance up to 7 all around
     an explosion      its fire (48 ticks), a ring of smoke, a big smoke
                       that lasts 3 or 4 seconds; its sound
     the jets          one tick in 7, a flame from each foot; one in 8,
                       smoke
     a foot, running   dust

   Left out: the weather, clothes shredded by a bullet, a helmet shot
   off, the cigar, the fire of a burning soldier, the smoke a hot shell
   trails, the spark a soldier appears in.

   In Soldat: shared/mechanics/Sparks.pas (TSpark, CreateSpark, 73
   styles by number), and every CreateSpark of the client's branches
   in Sprites.pas, Control.pas and Bullets.pas (TBullet.Hit).
*)

(* Soldat's styles, those made here, by what they are (their numbers
 * there in Soldat_sparks.ml) *)
type kind =
  | Smoke
  | Chip
  | Lil_blood
  | Blood
  | Splat
  | Clip of Soldat_weapons.id
  | Shell of Soldat_weapons.id
  | Explosion (* a hand grenade's *)
  | Explosion_m79 (* smaller *)
  | Smoke_ring
  | Big_smoke
  | Mini_smoke
  | Spark
  | Spark_grey
  | Muzzle
  | Jet_fire

type t = {
  kind : kind;
  x : float;
  y : float;
  vx : float;
  vy : float;
  (* ticks left *)
  life : int;
  (* the soldier it is of: a jet's fire has its colour *)
  owner : int;
  (* times it has met the map *)
  hits : int;
}

(* [of_event map ~random ~owner event]: the sparks an event makes, and
 * its sounds. [owner]: the soldier it is of. [random]: a number from 0
 * to 1, of the sparks' own chance *)
val of_event : Soldat_map.t -> random:(unit -> float) -> owner:int -> Soldat_event.t -> t list * (Soldat_sfx.t * (float * float)) list

(* a tick of them all: those left, the ones they made (a splat, a
 * jet's sparks off a wall), and what was heard (a shell on the ground) *)
val tick : Soldat_map.t -> random:(unit -> float) -> t list -> t list * (Soldat_sfx.t * (float * float)) list

(* at most this many are kept (Soldat's r_maxsparks, 558; 150 in a
 * browser, where each costs more to draw): [capped] drops the oldest
 * of a list, the first *)
val most : int ref
val capped : t list -> t list

(* how much an explosion shakes the picture, this tick: a move of the
 * camera, each way (the wobble of TSpark.Update) *)
val wobble : random:(unit -> float) -> t list -> float * float
