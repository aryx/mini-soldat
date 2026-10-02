(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_sfx.mli *)

type t =
  | Fire of Soldat_weapons.id
  | Reload of Soldat_weapons.id
  | Change_weapon
  | Change_spin
  | Throw_gun
  | Take_gun
  | Take_medikit
  | Pickup
  | Grenade_pullout
  | Grenade_throw
  | Grenade_bounce
  | Grenade_explosion
  | M79_explosion
  | Explosion_erg
  | Ric
  | Ricochet
  | Hit_arg
  | Dead_hit
  | Death
  | Headchop
  | Bryzg
  | Bodyfall
  | Bonecrack
  | Step
  | Jump
  | Fall
  | Fall_hard
  | Crouch
  | Crouch_move
  | Prone_move
  | Go_prone
  | Stand_up
  | Roll
  | Stop
  | Rocketz
  | Spawn
  | Weapon_hit
  | Kit_fall
  | Shell
  | Gauge_shell
  | Clip_fall
  | Dist_gun
  | Dist_grenade
  | Dist_m79
  | Flag_fall
  | Capture
  | Ctf_score

(* a weapon's name in its files *)
let weapon (id : Soldat_weapons.id) : string =
  match id with
  | Eagles -> "deserteagle"
  | Mp5 -> "mp5"
  | Ak74 -> "ak74"
  | Steyr -> "steyraug"
  | Spas -> "spas12"
  | Ruger -> "ruger77"
  | M79 -> "m79"
  | Barrett -> "barretm82"
  | Minimi -> "m249"
  | Minigun -> "minigun"
  | Socom | Grenade | Hands -> "colt1911"

(* its recordings: one, or several to take one of *)
let names (s : t) : string list =
  match s with
  | Fire id -> [ weapon id ^ "-fire" ]
  | Reload id -> [ weapon id ^ "-reload" ]
  | Change_weapon -> [ "changeweapon" ]
  | Change_spin -> [ "changespin" ]
  | Throw_gun -> [ "throwgun" ]
  | Take_gun -> [ "takegun" ]
  | Take_medikit -> [ "takemedikit" ]
  | Pickup -> [ "pickupgun" ]
  | Grenade_pullout -> [ "grenade-pullout" ]
  | Grenade_throw -> [ "grenade-throw" ]
  | Grenade_bounce -> [ "grenade-bounce" ]
  | Grenade_explosion -> [ "grenade-explosion" ]
  | M79_explosion -> [ "m79-explosion" ]
  | Explosion_erg -> [ "explosion-erg" ]
  | Ric -> [ "ric"; "ric2"; "ric3"; "ric4" ]
  | Ricochet -> [ "ric5"; "ric6"; "ric7" ]
  | Hit_arg -> [ "hit-arg"; "hit-arg2"; "hit-arg3" ]
  | Dead_hit -> [ "dead-hit" ]
  | Death -> [ "death"; "death2"; "death3" ]
  | Headchop -> [ "headchop" ]
  | Bryzg -> [ "bryzg" ]
  | Bodyfall -> [ "bodyfall" ]
  | Bonecrack -> [ "bonecrack" ]
  | Step -> [ "step"; "step2"; "step3"; "step4" ]
  | Jump -> [ "jump" ]
  | Fall -> [ "fall" ]
  | Fall_hard -> [ "fall-hard" ]
  | Crouch -> [ "crouch" ]
  | Crouch_move -> [ "crouch-move"; "crouch-movel" ]
  | Prone_move -> [ "prone-move" ]
  | Go_prone -> [ "goprone" ]
  | Stand_up -> [ "standup" ]
  | Roll -> [ "roll" ]
  | Stop -> [ "stop" ]
  | Rocketz -> [ "rocketz" ]
  | Spawn -> [ "spawn" ]
  | Weapon_hit -> [ "weaponhit" ]
  | Kit_fall -> [ "kit-fall"; "kit-fall2" ]
  | Shell -> [ "shell"; "shell2" ]
  | Gauge_shell -> [ "gaugeshell" ]
  | Clip_fall -> [ "clipfall" ]
  | Dist_gun -> [ "dist-gun1"; "dist-gun2"; "dist-gun3"; "dist-gun4" ]
  | Dist_grenade -> [ "dist-grenade" ]
  | Dist_m79 -> [ "dist-m79" ]
  | Flag_fall -> [ "flag"; "flag2" ]
  | Capture -> [ "capture" ]
  | Ctf_score -> [ "ctf" ]

let variants (s : t) : int = List.length (names s)

let file (s : t) (n : int) : string =
  let all = names s in
  List.nth all (((n mod List.length all) + List.length all) mod List.length all)

let files : string list =
  let weapons : Soldat_weapons.id list = Socom :: Soldat_weapons.primaries in
  List.concat_map names
    (List.map (fun id -> Fire id) weapons
    @ List.map (fun id -> Reload id) weapons
    @ [ Change_weapon; Change_spin; Throw_gun; Take_gun; Take_medikit; Pickup; Grenade_pullout; Grenade_throw; Grenade_bounce; Grenade_explosion; M79_explosion;
        Explosion_erg; Ric; Ricochet; Hit_arg; Dead_hit; Death; Headchop; Bryzg; Bodyfall; Bonecrack; Step; Jump; Fall; Fall_hard; Crouch; Crouch_move; Prone_move;
        Go_prone; Stand_up; Roll; Stop; Rocketz; Spawn; Weapon_hit; Kit_fall; Shell; Gauge_shell; Clip_fall; Dist_gun; Dist_grenade; Dist_m79; Flag_fall; Capture; Ctf_score ])
