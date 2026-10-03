(* Soldat_sfx: the names of Soldat's sounds.

   Soldat has 163 recordings, each a .wav file of its sfx/ folder, and
   a number for each (SFX_AK74_FIRE = 1 ...). Here those the game
   plays are a type's cases, 47 of them, and [file] gives each one's
   file.

   Some sounds are one of several recordings taken by chance, so that
   a run is not the same footstep over and over: four steps, four
   bullets off a wall, three cries. Such a sound is one case here
   ([Step]), and [file] is given a number to choose with: [variants]
   says among how many.

   Worked example: [file Step 6] is "step3" (6 mod 4 = 2: the third of
   step, step2, step3, step4); [file (Fire Ak74) 6] is "ak74-fire",
   whatever the number.

   In Soldat: the constants SFX_* (shared/Constants.pas) and the list
   of files of LoadSounds (client/Sound.pas).
*)

type t =
  (* a weapon's shot, and its reload (the shotgun's: a shell pushed in) *)
  | Fire of Soldat_weapons.id
  | Reload of Soldat_weapons.id
  | Change_weapon
  | Change_spin (* to the pistol, spun *)
  | Throw_gun
  | Take_gun
  | Take_medikit
  | Take_bow
  (* a bonus kit taken: Flame god, Predator, Berserker, the vest; a vest hit *)
  | God_flame
  | Predator
  | Berserker
  | Vest_take
  | Vest_hit
  | Cluster_grenade
  | Cluster_explosion
  | Pickup (* a kit of grenades *)
  (* grenades and explosions *)
  | Grenade_pullout
  | Grenade_throw
  | Grenade_bounce
  | Grenade_explosion
  | M79_explosion
  | Explosion_erg (* who is caught in one *)
  (* a bullet's end *)
  | Ric (* in a wall: 4 *)
  | Ricochet (* off a wall: 3 *)
  | Hit_arg (* in a body: 3 *)
  | Dead_hit (* in a dead one *)
  | Death (* 3 *)
  | Headchop
  | Bryzg (* a body torn apart *)
  | Bodyfall
  | Bonecrack
  (* a soldier moving *)
  | Step (* 4 *)
  | Jump
  | Fall
  | Fall_hard
  | Crouch
  | Crouch_move (* 2 *)
  | Prone_move
  | Go_prone
  | Stand_up
  | Roll
  | Stop
  | Rocketz (* the jets, as long as they push *)
  | Spawn
  (* what falls on the ground *)
  | Weapon_hit
  | Kit_fall (* 2 *)
  | Shell (* 2 *)
  | Gauge_shell (* the shotgun's *)
  | Clip_fall
  (* heard from far, in place of the sound itself *)
  | Dist_gun (* 4 *)
  | Dist_grenade
  | Dist_m79
  (* the flags *)
  | Flag_fall (* 2 *)
  | Capture (* a flag taken *)
  | Ctf_score (* a flag brought home *)

(* among how many recordings it is taken *)
val variants : t -> int

(* [file sound n]: its file's name in sfx/, without ".wav"; [n], any
 * number, chooses among its variants *)
val file : t -> int -> string

(* every file the game may ask for *)
val files : string list
