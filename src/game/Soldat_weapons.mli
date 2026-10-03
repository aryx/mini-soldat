(* Soldat's weapons: the table of their numbers.

   Soldat has ten *primary* weapons, one of which a soldier chooses
   when it appears, and a *secondary* one it always has besides; and
   grenades, thrown by hand. What tells them apart is a line of numbers
   each, kept in a file a server's owner may change, weapons.ini: this
   module reads Soldat's own (data/weapons.ini, carried in the
   program), section by section:

       [Desert Eagles]
       Damage=1.81           what a hit takes, times the bullet's speed
       FireInterval=24       ticks from a shot to the next
       Ammo=7                shots in a clip
       ReloadTime=87         ticks to change the clip
       Speed=19              the bullet's, units a tick
       BulletStyle=1         1 plain, 2 hand grenade, 3 pellets, 4 M79's
       StartUpTime=0         ticks the trigger is held before it fires
       Bink=0                (not used here: the aim shaken)
       MovementAcc=0.009     how much moving spoils the aim
       BulletSpread=0.15     how much it scatters, standing still
       Recoil=0              (not used here)
       Push=0.0176           of the bullet's speed given to who is hit
       InheritedVelocity=0.5 of the shooter's speed given to the bullet
       ModifierHead=1.1      what a hit is worth, by where
       ModifierChest=0.95
       ModifierLegs=0.85

   **Worked example.** An Eagle's bullet leaves at 19 units a tick. In
   a standing soldier's chest it takes 19 x 1.81 x 0.95 = 32.7 of its
   150 health: five to kill; in the head 19 x 1.81 x 1.1 = 37.8: four.
   The Barrett's leaves at 55 and takes 55 x 4.45 = 245, the same
   anywhere (its three modifiers are 1): one.

   Three things of a weapon are not in the file but in Soldat's code
   (shared/Weapons.pas), and so are here: whether its reload shows a
   clip changed ([clip_reload]: not the shotgun, the Ruger, the
   minigun), whether it fires once a pull of the trigger
   ([single_shot]: the Eagles, the shotgun, the Ruger, the Barrett, the
   USSOCOM), and how long its bullet lives (7 seconds; a grenade 3).

   Left out: the stationary gun, and realistic mode's own table
   (weapons_realistic.ini).

   In Soldat: shared/Weapons.pas (TGun, CreateWeapons, the defaults
   the file overrides) and shared/Game.pas (LoadWeapons).
*)

(* [Hands]: no weapon, after throwing one's own away (the file's
 * [Punch]; the punch itself is not here). [Bow] and [Bow2]: Rambo's
 * bow and its other arrows (the file's [Rambo Bow] and [Flamed
 * Arrows], whose flames are not here), which nobody chooses: the bow
 * is found on the map, in a Rambomatch. [Knife], [Chainsaw] and [Law]
 * are the three other weapons one may have as the second, in place of
 * the USSOCOM; [Flamer] is the bonus's. The last three are no weapon
 * one holds but what leaves the hands: the knife thrown, a cluster
 * grenade, and one of the five it bursts into (their numbers are the
 * knife's and the grenade's, as in CreateWeapons) *)
type id = Eagles | Mp5 | Ak74 | Steyr | Spas | Ruger | M79 | Barrett | Minimi | Minigun | Socom | Grenade | Hands | Bow | Bow2
  | Knife | Chainsaw | Law | Flamer | Thrown_knife | Cluster_grenade | Cluster

(* what its bullet is: BulletStyle 1, 3, 4 and 2 *)
(* [Arrow]: 7, the bow's, and 8, its flaming one; [Melee]: 6 and 11,
 * a fist's, a knife's and the chainsaw's, a "bullet" that lives a
 * tick at the hand; [Flame]: 5; [Explosive] is 12 too, the LAW's
 * rocket; [Flying_knife]: 13, the knife thrown *)
type style = Plain | Pellets | Explosive | Thrown | Arrow | Melee | Flame | Flying_knife

type t = {
  id : id;
  name : string;
  damage : float;
  fire_interval : int;
  ammo : int;
  reload_time : int;
  speed : float;
  style : style;
  startup : int;
  movement_acc : float;
  spread : float;
  push : float;
  inherited : float;
  head : float;
  chest : float;
  legs : float;
  clip_reload : bool;
  single_shot : bool;
  (* the reload's count at which the clip comes out and at which the
   * new one is in: 0.8 and 0.3 of its time; 0 without a clip *)
  clip_out : int;
  clip_in : int;
  (* ticks its bullet lives *)
  timeout : int;
}

(* Soldat's weapons.ini, as the program carries it *)
val get : id -> t

(* the ten a soldier chooses from, in the order of Soldat's menu: the
 * keys 1 to 9, then 0 *)
val primaries : id list

(* the four to have as the second weapon: the USSOCOM first *)
val secondaries : id list

(* what a hit at this point of the skeleton is worth: the legs (1 to
 * 4), the chest (to 11), the head *)
val modifier : t -> int -> float

(* the bow, with either of its arrows: who holds it is Rambo *)
val is_bow : id -> bool

(* a weapons.ini read: each section's name and its numbers; a line
 * that is not one is passed over *)
val parse : string -> (string * (string * float) list) list

(* the table from a file's sections; a weapon the file has not, or a
 * number of it, is an error saying which *)
val of_ini : (string * (string * float) list) list -> (id -> t, string) result
