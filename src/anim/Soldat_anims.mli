(* Soldat_anims: the soldier's 44 animations, and its skeleton.

   A soldier's body is 20 points, and an animation says where each is,
   frame after frame, from the soldier's feet. A soldier plays two at
   once: one for its legs (points 1 to 6, 17 and 18) and one for the
   rest (Soldat_soldier). Which one, and at which frame, is most of
   what a soldier is doing: Soldat's code asks all along "is the legs'
   animation Jump, between its frames 9 and 14?", and so does this
   one. So the frames are numbered from 1, as there, and the points
   too.

   An animation has a speed, the ticks a frame lasts (Stand: 3; Run:
   1), and loops or stops on its last frame. Neither is in its file:
   they are Soldat's code's, and here in [all].

     Stand    stoi.poa        17 frames, 3 ticks each, loops
     Run      biega.poa       38 frames, 1 tick each, loops
     Jump     skok.poa        37 frames, stops: a jump's force is given
                              from its frame 9 to its frame 14
     Prone    lezy.poa        27 frames, stops: lying, at frame 26

   The files' names are Polish, the language of Soldat's author:
   stoi (stands), biega (runs), biegatyl (runs backwards), skok (a
   jump), skokwbok (a jump sideways), spada (falls), kuca (crouches),
   kucaidzie (crouches and walks), lezy (lies), lezyidzie (lies and
   walks), wstaje (gets up), rzuca (throws), celuje (aims), laduje
   (loads), bije (hits), odrzut (recoil), bezbroni (unarmed).

   The frames are carried in the program (Anims_data, made by the
   build from data/anims/), as the singles Soldat keeps them in.

   In Soldat: shared/Anims.pas, LoadAnimObjects (the list, the speeds,
   the loops) and TAnimation.DoAnimation; the 44 global variables are
   shared/Game.pas's.
*)

(* in Soldat's order: Stand is its 0, Own its 43 *)
type id =
  | Stand | Run | Run_back | Jump | Jump_side | Fall | Crouch | Crouch_run | Reload | Throw | Recoil
  | Small_recoil | Shotgun | Clip_out | Clip_in | Slide_back | Change | Throw_weapon | Weapon_none
  | Punch | Reload_bow | Barret | Roll | Roll_back | Crouch_run_back | Cigar | Match | Smoke | Wipe
  | Groin | Piss | Mercy | Mercy2 | Take_off | Prone | Victory | Aim | Hands_up_aim | Prone_move
  | Get_up | Aim_recoil | Hands_up_recoil | Melee | Own

(* each animation: its file's name, the ticks a frame lasts, whether it
 * loops *)
val all : (id * string * int * bool) list

(* how many frames it has *)
val frames : id -> int

(* [point id frame p]: where point [p] (1 to 20) is at [frame] (1 to
 * [frames id]), from the soldier's feet, y downwards, facing right *)
val point : id -> int -> int -> float * float

(* an animation being played: which, the frame it is at, and the ticks
 * that frame has lasted *)
type playing = { id : id; frame : int; count : int }

(* [start id frame]: the animation, at that frame *)
val start : id -> int -> playing

(* a tick later: the next frame once this one has lasted the
 * animation's speed; after the last, the first if it loops, else the
 * last still (DoAnimation) *)
val advance : playing -> playing

(* at its last frame *)
val ended : playing -> bool

(* the soldier's skeleton: 24 points (the 20, and 4 for a chain and
 * hair that dangle) and 30 sticks, at Soldat's size *)
val gostek : Poa.skeleton
