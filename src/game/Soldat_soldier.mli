(* Soldat_soldier: a soldier that moves as Soldat's does.

   A soldier is two things, of which one moves:

   - a **particle** near its feet, with a position and a speed. The
     keys push it, gravity pulls it, the map stops it;
   - a **skeleton** of 20 points, its body, which while it lives is
     not simulated at all: each tick it is put where two animations
     say, one for the legs and one for the rest, from the particle,
     mirrored to the side the cursor is on.

            12          head              the body's points, by Soldat's
          11 9 10       shoulders, neck   numbers; the legs' animation
        14       13     elbows            places 1 to 6, 17 and 18, the
       15 19   16 20    hands             body's the others, hung from
           8   7        the waist         the hip
           6   5        hips
           3   4        knees
        18 2   1 17     ankles, toes
             o          the particle

   **A tick**, in Soldat's order:

     the particle's step     speed += forces (gravity, 0.06, among them);
                             place += speed; speed *= 0.99; forces := 0
     the keys                forces for the next step, and which
                             animations; the trigger: a shot
     the skeleton placed     from the animations' frames, as they are
     the animations advance
     the map                 the particle pushed out of the walls
     the weapon's counters   the wait for the next shot, the reload

   so what a key does is felt a tick later, as there.

   **The keys are forces and animations**, the first of these that
   holds: in a roll; down and a side (a roll if running, else a
   crouched walk); lying (a crawl); up and a side (a jump sideways);
   up (a jump); down (a crouch); a side (a run, backwards if away from
   the cursor); nothing (standing, or falling). A force is small and
   given every tick a key is held (a run: 0.118), which with the
   damping makes a top speed and the time to reach it. A jump is not a
   push at once: its animation starts, and the force (0.66 upwards) is
   given while it goes through its frames 9 to 14, a wind-up one feels.
   The jets push up 0.10 a tick while there is fuel, which comes back
   when they rest.

   **The map** is tested by points, where the particle will be next:
   two above the head, two under the feet (one of them in a wall is
   "on the ground"), a circle of radius 3 against the walls' edges,
   and the walls' corners. A foot in a wall pushes the particle out
   along the edge's perp and then decides the friction by what the
   legs do: standing on a floor is a full stop (no sliding down a
   slope), running keeps 0.97 of the speed a tick, a crouched walk
   0.85; ice is a floor without the stop.

   **Aiming.** Once placed, the skeleton's head and hands are turned
   to the cursor: the head's point is put beside the neck, across the
   line to the cursor, and the arms' ends 7 and 8 from the hand the
   animation holds, towards it. A bullet leaves from there (point 15).

   What a wall's kind does to who touches it (deadly, hurting,
   healing) is the game's to do (Soldat_update), a soldier's health
   being its: a tick says which kinds were touched.

   **The weapons.** A soldier holds one weapon and carries another on
   its back (the USSOCOM, unless it chose it), and grenades. A weapon
   in the hands has four counters ([gun]):

     ammo            shots left in the clip
     fire_count      ticks before the next shot (FireInterval, counted
                     down while there is ammo)
     reload_count    ticks left of a reload (ReloadTime, counted down
                     while the clip is empty: it reloads by itself)
     startup_count   ticks the trigger must still be held (the Barrett
                     19, the minigun 25); let go, it starts again

   *A shot* (TSprite.Fire) leaves from 4 behind the hand (point 15), 2
   above, towards the cursor, turned by chance by at most

       0.5 sin (pi/2 x min 0.5 (0.25 (moving + scatter)) / 0.5)

   on each axis before the direction is made of length 1 again: moving
   is the weapon's MovementAcc, 7 times when running, jumping, rolling
   or flying, 3 times in the air or getting up, nothing when still;
   scatter is its BulletSpread, less crouched (/ 1.3) or lying
   (/ 1.625). Then its speed, plus half the soldier's. The chance is
   not Random's but the game's own numbers ([random]), so that a game
   replays the same.

   Worked example: an FN Minimi (MovementAcc 0.013, BulletSpread
   0.064) standing still may be off by 0.5 sin (pi/2 x 0.016 / 0.5) =
   0.0251 on each axis, a degree and a half; running, 0.25 x (7 x 0.013
   + 0.064) = 0.03875 and 0.5 sin (pi/2 x 0.03875 / 0.5) = 0.0607, three
   and a half degrees.

   The Eagles fire two bullets, each moved by its own BulletSpread,
   the second 3 beside the first. The shotgun fires six pellets the
   same way, and kicks its soldier back by 0.041 of the pellets' speed
   (0.58 a tick): in the air, aimed down, that is a second jump; a
   soldier standing on the ground is held by it. The minigun pushes
   back a little at every bullet.

   *The trigger*: held, a weapon fires each time fire_count is 0; one
   that fires once a pull (the Eagles, the shotgun, the Ruger, the
   Barrett, the USSOCOM) has its fire_count kept at 1 while the trigger
   stays held after a shot.

   *A reload* starts by itself on an empty clip, or with its key (the
   clip is then let go, whatever was in it). The body plays Clip_out,
   then Clip_in when the count is at 0.8 of its time and Slide_back at
   0.3; at 0 the clip is full. The shotgun has no clip: its body plays
   Reload, and each time that reaches its 14th frame a shell is in,
   until it is full or the trigger is pulled.

   *Changing weapon* is the animation Change, the two weapons swapped
   at its 25th frame. *Throwing it away* is Throw_weapon: at its 19th
   frame the weapon leaves the hands ([dropped]: the game puts it on
   the ground, Soldat_things), which are then empty ([Hands]) and can
   pick another up. *A grenade*: its key held plays Throw; let go
   between frames 15 and 36 (or at 36) the grenade leaves the hand
   towards the cursor at frame / 5 units a tick (0.65 of that before
   frame 24): 3 to 7.2, plus all of the soldier's speed.

   What left a soldier in a tick is in [shots]: the game makes bullets
   of them (Soldat_bullets).

   Not here, of the Pascal: the knife, the fist and the rifle's butt,
   a weapon thrown away, the aim shaken by a hit (bink), the idle
   animations, the parachute, the chain and the hair that dangle, the
   background polygons.

   In Soldat: ParticleSystem.Euler (shared/Parts.pas), TSprite.Update,
   CheckMapCollision, CheckRadiusMapCollision, CheckMapVerticesCollision
   TSprite.Fire, TSprite.ThrowGrenade (shared/mechanics/Sprites.pas),
   and ControlSprite (shared/mechanics/Control.pas), a procedure of
   2,090 lines.
*)

(* standing, crouching, lying: Soldat's Position *)
type stance = Standing | Crouching | Lying

(* what a soldier is asked to do this tick: Soldat's TControl. Held
 * keys; [prone] held while standing lies down, held again gets up.
 * [aim] is where the cursor is, in the map *)
type control = {
  left : bool;
  right : bool;
  up : bool; (* jump *)
  down : bool; (* crouch *)
  jetpack : bool;
  prone : bool;
  fire : bool; (* the trigger *)
  reload : bool;
  change : bool; (* to the weapon on its back *)
  grenade : bool; (* held to wind up, let go to throw *)
  drop : bool; (* throw the weapon in the hands away *)
  aim : float * float;
}

val no_control : control

(* a weapon and its counters: TGun *)
type gun = { kind : Soldat_weapons.t; ammo : int; fire_count : int; reload_count : int; startup_count : int }

(* a weapon as it is picked: full, ready *)
val gun : Soldat_weapons.id -> gun

(* what left a soldier: a bullet its weapon, or a grenade its hand *)
type shot = { from : float * float; velocity : float * float; weapon : Soldat_weapons.id }

(* the fields are a tick's to write, nobody else's *)
type t = {
  mutable x : float;
  mutable y : float;
  mutable vx : float;
  mutable vy : float;
  mutable fx : float;
  mutable fy : float;
  mutable old_x : float;
  mutable old_y : float;
  mutable direction : int; (* 1 facing right, -1 left *)
  mutable old_direction : int; (* the one it lay down facing *)
  mutable stance : stance;
  mutable legs : Soldat_anims.playing;
  mutable body : Soldat_anims.playing;
  mutable on_ground : bool;
  mutable on_ground_last : bool;
  mutable on_ground_permanent : bool;
  mutable jets : int; (* the fuel, in ticks *)
  mutable jetting : bool; (* the jets pushed, this tick *)
  mutable touched : Pms.kind list; (* the kinds of the walls it touched, this tick *)
  mutable aim_x : float;
  mutable aim_y : float;
  mutable skeleton : (float * float) array; (* its 20 points, the first at 0 *)
  mutable old_skeleton : (float * float) array; (* and a tick before: how fast each goes *)
  mutable was_running_left : bool;
  mutable was_jumping : bool;
  mutable weapon : gun; (* in its hands *)
  mutable secondary : gun; (* on its back *)
  mutable grenades : int;
  (* they are cluster grenades (the bonus kit's three) *)
  mutable cluster : bool;
  mutable ceasefire : int; (* ticks before it may fire and be hit: 90 when it appears *)
  mutable burst : int; (* shots since the trigger was pulled *)
  mutable fired : bool; (* it fired, this tick *)
  mutable can_throw : bool;
  mutable trigger_released : bool;
  mutable reload_wanted : bool;
  mutable shots : shot list; (* what left it this tick, the first first *)
  mutable dropped : gun option; (* the weapon it let go of this tick *)
  mutable events : Soldat_event.t list; (* what of this tick is to be heard and seen, the last first *)
  human : bool; (* a player's: a weapon firing once a pull does so only for it *)
  team : int; (* 1 Alpha, 2 Bravo; none: 0. A team's walls stop its own only *)
}

(* a soldier standing at a place, with that much fuel, [primary] in
 * its hands (the USSOCOM if none is said), [secondary] on its back
 * (the USSOCOM, or the knife, the chainsaw, the LAW), one grenade; a
 * player's unless [human] is false.
 *
 * Empty hands and the knife strike (the fire key: a blow at the 11th
 * frame of the punch, a "bullet" that lives a tick along the hand);
 * the knife is thrown by the key that drops the others, harder the
 * longer it is held; the LAW fires from the ground only, crouched or
 * lying, after 13 ticks of that *)
val create : ?primary:Soldat_weapons.id -> ?secondary:Soldat_weapons.id -> ?human:bool -> ?team:int -> float * float -> int -> t

(* with a weapon picked up from the ground in its hands, and with its
 * weapon let go (it died): [dropped] says which *)
val take : t -> gun -> t
val let_go : t -> t

(* a tick later, on this map, asked this. [ticks] is how many the game
 * has had (the jets fill every other tick in the air); [random] gives
 * the game's next number from 0 to 1, asked only when a shot leaves
 * (2 times, 6 for the Eagles, 14 for the shotgun). The soldier given
 * is not changed *)
val tick : Soldat_map.t -> ticks:int -> random:(unit -> float) -> t -> control -> t

(* where point [p] of its skeleton is, by Soldat's number, 1 to 20 *)
val point : t -> int -> float * float

(* beyond the map's edge: Soldat puts it back at a spawn point *)
val out_of_map : Soldat_map.t -> t -> bool

(* Soldat's numbers, for who needs them *)
val grav : float
val max_velocity : float
