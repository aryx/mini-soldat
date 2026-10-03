(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* What happened in a tick that is to be heard or seen and changes
 * nothing of the game: a shot, a step, a bullet in a wall.
 *
 * Soldat's code plays a sound or makes a spark right where the thing
 * happens, between two lines of the game's rules, in the client's
 * branches ({$IFNDEF SERVER}: PlaySound, CreateSpark, 300 of them).
 * Here the rules only say what happened, as a value; the sparks are
 * made of it after (Soldat_sparks.of_event), with a chance of their
 * own, and the sounds are played by the Playground's side
 * (Soldat_sound). So a tick stays a function, a server can drop the
 * list, and a test can ask what was heard.
 *
 * A place is a point of the map; a speed, units a tick.
 *)

type point = float * float

type t =
  (* a sound, from a place *)
  | Sound of Soldat_sfx.t * point
  (* a weapon fired: the hand that holds it (the skeleton's point 15),
   * the bullet's speed, where it was aimed (of length 1), the
   * soldier's speed and which way it faces: a shell, and smoke *)
  | Shot of { weapon : Soldat_weapons.id; hand : point; bullet : point; aim : point; speed : point; facing : int }
  (* the shotgun pumped (the 24th frame of its animation): its shell *)
  | Pumped of { hand : point; along : point; speed : point; facing : int }
  (* a reload's clip let go; the M79's empty shell *)
  | Clip of { weapon : Soldat_weapons.id; hand : point; speed : point }
  (* the jets pushing: the two feet (points 1 and 2), the two legs'
   * ways (of length 1), the soldier's speed *)
  | Jets of { feet : point * point; legs : point * point; speed : point }
  (* a foot on the ground, running: dust *)
  | Dust of { at : point; speed : point; up : float }
  (* a bullet's end: in a wall, off a wall, in a body, through one *)
  | Wall of point * point
  | Ricochet of point * point
  | Blood of point * point
  | Flesh of point * point
  (* an explosion, a hand grenade's or the M79's *)
  | Blast of Soldat_weapons.id * point

(* what an event gives to hear, whatever is made of it to see: a sound
 * says itself; a bullet's end in a wall, its ricochet and an explosion
 * have theirs (the PlaySound beside each CreateSpark, in the Pascal) *)
let sounds (e : t) : (Soldat_sfx.t * (float * float)) list =
  match e with
  | Sound (sfx, at) -> [ (sfx, at) ]
  | Wall (at, _) -> [ (Ric, at) ]
  | Ricochet (at, _) -> [ (Ricochet, at) ]
  | Blast (weapon, at) -> [ ((match weapon with M79 | Law -> M79_explosion | Cluster -> Cluster_explosion | _ -> Grenade_explosion), at) ]
  | _ -> []
