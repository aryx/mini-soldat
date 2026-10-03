(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* The game's state: the soldiers, what each bot has in mind, the
 * bullets in flight, the explosions still seen, the things lying
 * about, the map, where the camera is, the time left, and the seed of
 * the game's chance.
 *
 * Everything is in Soldat's own units and coordinates (y downwards, a
 * soldier about 20 tall, speeds a tick), as the map is; only the
 * picture turns y over (Soldat_view).
 *
 * In Soldat: a soldier is shared/mechanics/Sprites.pas's TSprite and
 * what it wants to do its TControl (set from the keys or by a bot,
 * turned into moves by Control.pas), a bot's mind its Brain, a bullet
 * Bullets.pas's TBullet, a thing Things.pas's TThing, and the round
 * shared/Game.pas.
 *)
open Playground


(* what a bonus kit gives for a time (BONUS_FLAMEGOD, PREDATOR,
 * BERSERKER): the flamer and no harm; not seen; four times the harm *)
type bonus = Flame_god | Predator | Berserker

type soldier = {
  name : string;
  color : color;
  (* its shirt's (the same), its trousers' and its skin's colours, as
   * red, green and blue *)
  shirt : int * int * int;
  trousers : int * int * int;
  skin : int * int * int;
  human : bool;
  (* its particle and its skeleton, moved by Soldat's rules *)
  body : Soldat_soldier.t;
  (* 150 at most; dead, it goes on down as the body is hit, to -400 *)
  health : float;
  (* None while alive; Some (ticks since, its ragdoll) when dead *)
  dead : (int * Soldat_ragdoll.t) option;
  kills : int;
  (* the weapon it will appear with next *)
  primary : Soldat_weapons.id;
  (* who hit it last, for a bot to turn on (Brain.PissedOff is set by
   * the bullet); nobody: -1 *)
  hit_by : int;
  (* the weapon it will have as its second *)
  secondary : Soldat_weapons.id;
  (* its bonus, and the ticks left of it *)
  bonus : (bonus * int) option;
  (* what is left of its vest, of 100 (DEFAULTVEST) *)
  vest : float;
}

(* DEFAULTVEST, CLUSTER_GRENADES, and the bonuses' times *)
let default_vest = 100.
let cluster_grenades = 3
let flamer_time = 600
let predator_time = 1500
let berserker_time = 900

let has (s : soldier) (b : bonus) : bool = match s.bonus with Some (b', _) -> b' = b | None -> false

(* what a soldier wants to do this tick: the player's keys and mouse,
 * or a bot's mind *)
type intent = Soldat_soldier.control

let still : intent = Soldat_soldier.no_control

(* a bot's character, one of Soldat's .bot files: its looks, the weapon
 * it likes, and how it fights *)
type character = {
  bot : string;
  bot_shirt : int * int * int;
  bot_trousers : int * int * int;
  bot_skin : int * int * int;
  favourite : Soldat_weapons.id;
  (* how far off it may aim, in units: 0 never misses *)
  accuracy : int;
  (* it goes on shooting who it killed, for 3 seconds *)
  shoot_dead : bool;
  (* one tick in that many, seeing an enemy near, it throws a grenade *)
  grenade_freq : int;
  (* over 0 it holds its ground and crouches; over 127 at mid range too *)
  camper : int;
}

(* what a bot has in mind from a tick to the next: Soldat's Brain. A
 * waypoint is its number in the map's file, from 1; none: 0. A
 * soldier is its place among the round's, none: -1 *)
type brain = {
  character : character;
  target : int;
  (* who shot it: seen, it becomes the target *)
  pissed_off : int;
  (* the waypoint it is at, the one it goes to, and the one before *)
  current : int;
  next : int;
  old : int;
  (* ticks at the same waypoint, and what is left before it gives up
   * and goes back *)
  last : int;
  waypoint_time : int;
  timeout : int;
  (* ticks it has not moved, or has waited where a waypoint says to *)
  one_place : int;
  (* it is walking to a kit *)
  go_thing : bool;
  (* it is falling fast: the jets *)
  fall_save : bool;
  (* its keys last tick: a grenade's is held from a tick to the next *)
  keys : Soldat_soldier.control;
}

(* what the bot of ai=engine may know (Sense.mli, Soldat_engine_bot):
 * where it is and how it is, and its nearest enemy -- seen now, or
 * remembered where it was last seen, or not known at all. Not the
 * round: it cannot read through a wall what it has not got *)
type senses = {
  me : float * float;
  my_vx : float;
  my_fuel : int;
  seed : int; (* which soldier: its aim wobbles its own way *)
  frame : int; (* to patrol by, when it has nobody to chase *)
  enemy : (float * float) Sense.target;
}

(* a bullet, a pellet, a grenade: Soldat's TBullet *)
type bullet = {
  x : float;
  y : float;
  vx : float;
  vy : float;
  (* where it was a tick before *)
  old : float * float;
  owner : int;
  weapon : Soldat_weapons.id;
  (* what a hit takes, times its speed: the weapon's Damage, halved
   * beyond 500 units and again beyond 900 (HitMultiply) *)
  damage : float;
  ttl : int;
  (* where it left from, and how many times it was halved *)
  start : float * float;
  halved : int;
  (* where it last bounced off a wall: not again within 50 of there *)
  bounced_at : float * float;
  (* the last soldier it went through, not hit twice; none: -1 *)
  through : int;
}

(* an explosion, where it was and how far it reached *)
type explosion = { at : float * float; radius : float; age : int }

(* what a round is played for: everyone for itself; two teams, a kill
 * a point; two teams, each flag brought home a point *)
type mode = Deathmatch | Team_match | Capture_the_flag | Rambomatch

type play = {
  map : Soldat_map.t;
  mode : mode;
  (* flags brought home by Alpha and by Bravo *)
  captures : int * int;
  (* what just happened to a flag, said for 3 seconds: its words and
   * the ticks left *)
  news : (string * int) option;
  (* the point of the map at the screen's middle *)
  camera : float * float;
  soldiers : soldier array;
  (* one per soldier: a bot's mind, none for the player *)
  brains : brain option array;
  (* and, for the one bot of ai=engine, which has no brain: the senses
   * it has seen but not yet acted on, its memory of its enemy among
   * them (Bot.mli) *)
  minds : (senses, intent) Bot.running option array;
  bullets : bullet list;
  things : Soldat_things.t list;
  (* what is only seen (Soldat_sparks), with the seed of its own chance *)
  sparks : Soldat_sparks.t list;
  spark_seed : Lehmer.t;
  (* what was heard this tick, and where: for who plays the sounds *)
  sounds : (Soldat_sfx.t * (float * float)) list;
  (* what happened this tick to be heard and seen, each with the
   * soldier it is of (nobody's: -1): what a server sends its players,
   * who make their own sparks and sounds of it *)
  events : (int * Soldat_event.t) list;
  (* ticks before the round ends by itself (TimeLimitCounter) *)
  time_left : int;
  (* the game's chance: the next number comes from it (Lehmer) *)
  seed : Lehmer.t;
  frame : int;
  (* how often bonus kits appear, 1 to 5; never: 0 *)
  bonuses : int;
}

(* the map goes from a round to the next: the title's, the round's,
 * and after the round the winner's name over it *)
type scene =
  | Loading of string (* a map asked by its name, its file not there yet *)
  | Title of Soldat_map.t
  | Playing of play
  | Over of string * Soldat_map.t
  (* a round a server plays, as its last word and this program's own
   * guesses show it (Soldat_online), and which of its soldiers is
   * this program's; or the wait for it, and why *)
  | Online of play * int
  (* a server's lobby: the rooms one may enter, each with how many
   * players are in it, the one the cursor is on, and who waits here *)
  | Lobby of { rooms : (string * int) list; chosen : int; here : string list }
  | Connecting of string

(* how much of Soldat's look is drawn, the steps this game was made
 * in (docs/plan.md), each one a key away (g) to see what it added:
 *   1  the soldiers as their skeletons' sticks, the map in flat colours
 *   2  the soldiers' pictures
 *   3  the map's texture and scenery *)
let graphics_levels = 3

let graphics_name (level : int) : string =
  match level with 1 -> "1: skeletons, flat colours" | 2 -> "2: the soldiers' pictures" | _ -> "3: the map's texture and scenery"

type model = {
  scenes : scene Scene2d.t;
  graphics : int;
  (* frames its name still shows for, after a change *)
  graphics_shown : int;
  (* the weapon the player appears with: the keys 1 to 9 and 0 *)
  primary : Soldat_weapons.id;
  (* and as its second (the key c goes round them) *)
  secondary : Soldat_weapons.id;
  (* how often bonus kits appear, 1 to 5 (sv_bonus_frequency); never: 0 *)
  bonuses : int;
  (* the rounds started: a round's number is its chance's seed *)
  rounds : int;
  (* how many bots the player is against (the flag bots) *)
  bots : int;
  (* the mode asked for (the flag mode); none: the map's own *)
  mode : mode option;
  (* which of [maps] the key m asks for next *)
  next_map : int;
  (* online: the last lines said and told, the newest last; and the
   * line being typed, if one is *)
  lines : string list;
  typing : string option;
}

(* the maps whose content this game has (data/maps): the key m goes
 * round them *)
let maps : string list = [ "Arena2"; "ctf_Ash" ]

(* Soldat's DEFAULT_HEALTH *)
let full_health = 150.

(* the [i]th place to appear at, going round when the map has fewer
 * than there are soldiers *)
let spawn (map : Soldat_map.t) (i : int) : float * float = List.nth map.spawns (i mod List.length map.spawns)

(* of the map's places to appear at, the one farthest from [others] *)
let farthest (map : Soldat_map.t) (others : (float * float) list) : float * float =
  let room (x, y) = List.fold_left (fun m (ox, oy) -> Float.min m (Float.hypot (ox -. x) (oy -. y))) infinity others in
  List.fold_left (fun best sp -> if room sp > room best then sp else best) (List.hd map.spawns) map.spawns

(* sv_killlimit and sv_timelimit: a round is the first to 10 kills,
 * or who has most after 10 minutes *)
let kill_limit = 10
let time_limit = 36000

(* and sv_tm_limit, sv_ctf_limit: a team's kills, a team's flags *)
let team_limit = 60
let capture_limit = 10

(* the mode a map is for: capture the flag where it has a place for
 * each flag *)
let mode_of (map : Soldat_map.t) : mode = if map.alpha_flag <> None && map.bravo_flag <> None then Capture_the_flag else Deathmatch

let team (s : soldier) : int = s.body.team
let team_name (t : int) : string = match t with 1 -> "Alpha" | 2 -> "Bravo" | _ -> "nobody"

(* a team's points: its flags brought home, or its soldiers' kills *)
let score (p : play) (t : int) : int =
  match p.mode with
  | Capture_the_flag -> if t = 1 then fst p.captures else snd p.captures
  | Team_match | Deathmatch | Rambomatch -> Array.fold_left (fun n (s : soldier) -> if team s = t then n + s.kills else n) 0 p.soldiers

(* the points a round is played to *)
(* sv_rm_limit *)
let rambo_limit = 30
let limit (p : play) : int = match p.mode with Deathmatch -> kill_limit | Team_match -> team_limit | Capture_the_flag -> capture_limit | Rambomatch -> rambo_limit

(* Rambo: who is alive with the bow in its hands *)
let rambo (s : soldier) : bool = s.dead = None && Soldat_weapons.is_bow s.body.weapon.kind.id

(* a team's shirt: Soldat's red and blue *)
let team_shirt (t : int) : int * int * int = if t = 1 then (210, 15, 5) else (21, 31, 217)

let model_at ?(graphics = graphics_levels) (first : scene) : model =
  { scenes = Scene2d.start first; graphics = max 1 (min graphics_levels graphics); graphics_shown = 0; primary = Ak74; secondary = Socom; bonuses = 0; rounds = 0; bots = 3; mode = None; next_map = 1; lines = []; typing = None }

let initial_model ?graphics (map : Soldat_map.t) : model = model_at ?graphics (Title map)

(* starting on a map asked by its name (maps/NAME.pms of the content) *)
let loading_model ?graphics (name : string) : model = model_at ?graphics (Loading name)

(* Soldat shows 640 units across (DEFAULT_WIDTH): how many of the
 * screen's a unit is *)
let zoom (screen : screen) : float = screen.width /. 640.
