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
                             animations
     the skeleton placed     from the animations' frames, as they are
     the animations advance
     the map                 the particle pushed out of the walls

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

   Not here yet, of the Pascal: firing and the weapons, the head and
   the arms turned to the cursor, the idle animations, the parachute,
   the chain and the hair that dangle, what deadly and hurting
   polygons do, the background polygons.

   In Soldat: ParticleSystem.Euler (shared/Parts.pas), TSprite.Update,
   CheckMapCollision, CheckRadiusMapCollision, CheckMapVerticesCollision
   (shared/mechanics/Sprites.pas), and ControlSprite
   (shared/mechanics/Control.pas), a procedure of 2,090 lines.
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
  aim : float * float;
}

val no_control : control

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
  mutable aim_x : float;
  mutable aim_y : float;
  mutable skeleton : (float * float) array; (* its 20 points, the first at 0 *)
  mutable old_skeleton : (float * float) array; (* and a tick before: how fast each goes *)
  mutable was_running_left : bool;
  mutable was_jumping : bool;
}

(* a soldier standing at a place, with that much fuel *)
val create : float * float -> int -> t

(* a tick later, on this map, asked this. [ticks] is how many the game
 * has had (the jets fill every other tick in the air). The soldier
 * given is not changed *)
val tick : Soldat_map.t -> ticks:int -> t -> control -> t

(* where point [p] of its skeleton is, by Soldat's number, 1 to 20 *)
val point : t -> int -> float * float

(* beyond the map's edge: Soldat puts it back at a spawn point *)
val out_of_map : Soldat_map.t -> t -> bool

(* Soldat's numbers, for who needs them *)
val grav : float
val max_velocity : float
