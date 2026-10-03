(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_wire.mli. Each value has a [put] and a [get], its fields
 * in the same order in both, each read with a let of its own: the
 * order a tuple's or a record's parts are evaluated in is not the one
 * they are written in *)
open Soldat_model

type w = Wire.writer
type r = Wire.reader

(*****************************************************************************)
(* Numbers *)
(*****************************************************************************)

(* a single's 4 bytes, the high ones first, as Wire's numbers are *)
let put_float (w : w) (x : float) : unit =
  let bits = Int32.bits_of_float x in
  Wire.put_u16 w (Int32.to_int (Int32.logand (Int32.shift_right_logical bits 16) 0xffffl));
  Wire.put_u16 w (Int32.to_int (Int32.logand bits 0xffffl))

let get_float (r : r) : float =
  let high = Wire.get_u16 r in
  let low = Wire.get_u16 r in
  Int32.float_of_bits (Int32.logor (Int32.of_int low) (Int32.shift_left (Int32.of_int high) 16))

let put_point (w : w) ((x, y) : float * float) : unit = put_float w x; put_float w y

let get_point (r : r) : float * float =
  let x = get_float r in
  let y = get_float r in
  (x, y)

let put_bool (w : w) (b : bool) : unit = Wire.put_u8 w (if b then 1 else 0)
let get_bool (r : r) : bool = Wire.get_u8 r <> 0

(* up to 16 yes-or-no in two bytes, the first the lowest bit *)
let put_bits (w : w) (bits : bool list) : unit = Wire.put_u16 w (List.fold_left (fun (n, i) b -> ((if b then n lor (1 lsl i) else n), i + 1)) (0, 0) bits |> fst)
let bit (n : int) (i : int) : bool = n land (1 lsl i) <> 0

let put_list (w : w) (put : 'a -> unit) (xs : 'a list) : unit =
  Wire.put_varint w (List.length xs);
  List.iter put xs

(* a count that lies stops at the first item whose bytes are missing;
 * and none is over 4,096 *)
let get_list (r : r) (get : unit -> 'a) : 'a list =
  let n = Wire.get_varint r in
  if n > 4096 then Wire.fail r "a list of more than 4,096";
  List.init n (fun _ -> get ())

(* one of a list, by its place in it *)
let put_one (w : w) (all : 'a list) (x : 'a) : unit =
  let rec place i = function [] -> 0 | y :: rest -> if y = x then i else place (i + 1) rest in
  Wire.put_u8 w (place 0 all)

let get_one (r : r) (all : 'a list) (what : string) : 'a =
  match List.nth_opt all (Wire.get_u8 r) with Some x -> x | None -> Wire.fail r ("not " ^ what)

(*****************************************************************************)
(* The game's own *)
(*****************************************************************************)

let weapons : Soldat_weapons.id list = [ Eagles; Mp5; Ak74; Steyr; Spas; Ruger; M79; Barrett; Minimi; Minigun; Socom; Grenade; Hands; Bow; Bow2; Knife; Chainsaw; Law; Flamer; Thrown_knife; Cluster_grenade; Cluster ]
let animations : Soldat_anims.id list = List.map (fun (id, _, _, _) -> id) Soldat_anims.all
let stances : Soldat_soldier.stance list = [ Standing; Crouching; Lying ]
let bonuses : bonus option list = [ None; Some Flame_god; Some Predator; Some Berserker ]
let kits : Soldat_things.bonus list = [ Flamer_kit; Predator_kit; Vest_kit; Berserker_kit; Cluster_kit ]
let modes : mode list = [ Deathmatch; Team_match; Capture_the_flag; Rambomatch; Pointmatch; Hold_the_flag; Infiltration ]

(* the sounds, a weapon's by its weapon *)
let sounds : Soldat_sfx.t list =
  List.map (fun id -> Soldat_sfx.Fire id) weapons
  @ List.map (fun id -> Soldat_sfx.Reload id) weapons
  @ [ Change_weapon; Change_spin; Throw_gun; Take_gun; Take_medikit; Take_bow; God_flame; Predator; Berserker; Vest_take; Vest_hit; Cluster_grenade; Cluster_explosion; Pickup; Grenade_pullout; Grenade_throw; Grenade_bounce; Grenade_explosion; M79_explosion;
      Explosion_erg; Ric; Ricochet; Hit_arg; Dead_hit; Death; Headchop; Bryzg; Bodyfall; Bonecrack; Step; Jump; Fall; Fall_hard; Crouch; Crouch_move;
      Prone_move; Go_prone; Stand_up; Roll; Stop; Rocketz; Spawn; Weapon_hit; Kit_fall; Shell; Gauge_shell; Clip_fall; Dist_gun; Dist_grenade; Dist_m79;
      Flag_fall; Capture; Ctf_score ]

let put_weapon (w : w) (id : Soldat_weapons.id) : unit = put_one w weapons id
let get_weapon (r : r) : Soldat_weapons.id = get_one r weapons "a weapon"

(* a player's keys *)
let put_control (w : w) (c : Soldat_soldier.control) : unit =
  put_bits w [ c.left; c.right; c.up; c.down; c.jetpack; c.prone; c.fire; c.reload; c.change; c.grenade; c.drop ];
  put_point w c.aim

let get_control (r : r) : Soldat_soldier.control =
  let k = Wire.get_u16 r in
  let aim = get_point r in
  { left = bit k 0; right = bit k 1; up = bit k 2; down = bit k 3; jetpack = bit k 4; prone = bit k 5; fire = bit k 6; reload = bit k 7; change = bit k 8;
    grenade = bit k 9; drop = bit k 10; aim }

let put_playing (w : w) (p : Soldat_anims.playing) : unit =
  put_one w animations p.id;
  Wire.put_u8 w p.frame;
  Wire.put_u8 w p.count

let get_playing (r : r) : Soldat_anims.playing =
  let id = get_one r animations "an animation" in
  let frame = Wire.get_u8 r in
  let count = Wire.get_u8 r in
  { id; frame; count }

let put_gun (w : w) (g : Soldat_soldier.gun) : unit =
  put_weapon w g.kind.id;
  Wire.put_varint w g.ammo; Wire.put_varint w g.fire_count; Wire.put_varint w g.reload_count; Wire.put_varint w g.startup_count

let get_gun (r : r) : Soldat_soldier.gun =
  let id = get_weapon r in
  let ammo = Wire.get_varint r in
  let fire_count = Wire.get_varint r in
  let reload_count = Wire.get_varint r in
  let startup_count = Wire.get_varint r in
  { kind = Soldat_weapons.get id; ammo; fire_count; reload_count; startup_count }

let put_points (w : w) (points : (float * float) array) : unit = put_list w (put_point w) (Array.to_list points)
let get_points (r : r) : (float * float) array = Array.of_list (get_list r (fun () -> get_point r))

let put_body (w : w) (s : Soldat_soldier.t) : unit =
  List.iter (put_float w) [ s.x; s.y; s.vx; s.vy; s.fx; s.fy; s.old_x; s.old_y; s.aim_x; s.aim_y ];
  put_bits w
    [ s.direction = 1; s.old_direction = 1; s.on_ground; s.on_ground_last; s.on_ground_permanent; s.jetting; s.was_running_left; s.was_jumping; s.fired;
      s.can_throw; s.trigger_released; s.reload_wanted; s.human ];
  put_one w stances s.stance;
  put_playing w s.legs;
  put_playing w s.body;
  Wire.put_varint w s.jets;
  put_points w s.skeleton;
  put_points w s.old_skeleton;
  put_gun w s.weapon;
  put_gun w s.secondary;
  put_bool w s.cluster;
  Wire.put_varint w s.grenades; Wire.put_varint w s.ceasefire; Wire.put_varint w s.burst; Wire.put_u8 w s.team

let get_body (r : r) : Soldat_soldier.t =
  let x = get_float r in
  let y = get_float r in
  let vx = get_float r in
  let vy = get_float r in
  let fx = get_float r in
  let fy = get_float r in
  let old_x = get_float r in
  let old_y = get_float r in
  let aim_x = get_float r in
  let aim_y = get_float r in
  let k = Wire.get_u16 r in
  let stance = get_one r stances "a stance" in
  let legs = get_playing r in
  let body = get_playing r in
  let jets = Wire.get_varint r in
  let skeleton = get_points r in
  let old_skeleton = get_points r in
  if Array.length skeleton <> 20 || Array.length old_skeleton <> 20 then Wire.fail r "a skeleton is 20 points";
  let weapon = get_gun r in
  let secondary = get_gun r in
  let cluster = get_bool r in
  let grenades = Wire.get_varint r in
  let ceasefire = Wire.get_varint r in
  let burst = Wire.get_varint r in
  let team = Wire.get_u8 r in
  {
    x; y; vx; vy; fx; fy; old_x; old_y; aim_x; aim_y;
    direction = (if bit k 0 then 1 else -1); old_direction = (if bit k 1 then 1 else -1);
    on_ground = bit k 2; on_ground_last = bit k 3; on_ground_permanent = bit k 4; jetting = bit k 5; was_running_left = bit k 6; was_jumping = bit k 7;
    fired = bit k 8; can_throw = bit k 9; trigger_released = bit k 10; reload_wanted = bit k 11; human = bit k 12;
    stance; legs; body; jets; touched = []; skeleton; old_skeleton; weapon; secondary; grenades; cluster; ceasefire; burst; team;
    shots = []; dropped = None; events = [];
  }

let put_particles (w : w) (points : Particles.particle array) : unit =
  put_list w (fun (p : Particles.particle) -> put_point w p.pos; put_point w p.old) (Array.to_list points)

let get_particles (r : r) : Particles.particle array =
  Array.of_list
    (get_list r (fun () ->
         let pos = get_point r in
         let old = get_point r in
         { (Particles.particle pos) with old }))

let put_colour (w : w) ((r, g, b) : int * int * int) : unit = Wire.put_u8 w r; Wire.put_u8 w g; Wire.put_u8 w b

let get_colour (r : r) : int * int * int =
  let red = Wire.get_u8 r in
  let green = Wire.get_u8 r in
  let blue = Wire.get_u8 r in
  (red, green, blue)

let put_soldier (w : w) (s : soldier) : unit =
  Wire.put_string w s.name;
  put_colour w s.shirt; put_colour w s.trousers; put_colour w s.skin;
  put_bool w s.human;
  put_body w s.body;
  put_float w s.health;
  Wire.put_varint w s.kills;
  Wire.put_varint w s.deaths;
  put_weapon w s.primary;
  put_weapon w s.secondary;
  put_one w bonuses (Option.map fst s.bonus);
  Wire.put_varint w (match s.bonus with Some (_, ticks) -> ticks | None -> 0);
  put_float w s.vest;
  match s.dead with
  | None -> put_bool w false
  | Some (ticks, ragdoll) ->
      put_bool w true;
      Wire.put_varint w ticks;
      put_particles w ragdoll.points;
      put_list w (Wire.put_u8 w) ragdoll.cut;
      Wire.put_varint w ragdoll.falls

let get_soldier (r : r) : soldier =
  let name = Wire.get_string r in
  let shirt = get_colour r in
  let trousers = get_colour r in
  let skin = get_colour r in
  let human = get_bool r in
  let body = get_body r in
  let health = get_float r in
  let kills = Wire.get_varint r in
  let deaths = Wire.get_varint r in
  let primary = get_weapon r in
  let secondary = get_weapon r in
  let bonus = get_one r bonuses "a bonus" in
  let ticks = Wire.get_varint r in
  let vest = get_float r in
  let dead =
    if get_bool r then begin
      let ticks = Wire.get_varint r in
      let points = get_particles r in
      if Array.length points <> 20 then Wire.fail r "a body is 20 points";
      let cut = get_list r (fun () -> Wire.get_u8 r) in
      let falls = Wire.get_varint r in
      Some (ticks, ({ points; cut; falls } : Soldat_ragdoll.t))
    end
    else None
  in
  let (red, green, blue) = shirt in
  { name; color = Playground.rgb red green blue; shirt; trousers; skin; human; body; health; dead; kills; deaths; primary; hit_by = -1; secondary; bonus = Option.map (fun b -> (b, ticks)) bonus; vest }

let put_bullet (w : w) (b : bullet) : unit =
  List.iter (put_float w) [ b.x; b.y; b.vx; b.vy ];
  Wire.put_signed w b.owner;
  put_weapon w b.weapon;
  Wire.put_varint w b.ttl

let get_bullet (r : r) : bullet =
  let x = get_float r in
  let y = get_float r in
  let vx = get_float r in
  let vy = get_float r in
  let owner = Wire.get_signed r in
  let weapon = get_weapon r in
  let ttl = Wire.get_varint r in
  { x; y; vx; vy; old = (x, y); owner; weapon; damage = (Soldat_weapons.get weapon).damage; ttl; start = (x, y); halved = 0; bounced_at = (0., 0.); through = -1 }

let put_thing (w : w) (t : Soldat_things.t) : unit =
  (match t.kind with
  | Weapon g -> Wire.put_u8 w 0; put_gun w g
  | Medikit -> Wire.put_u8 w 1
  | Grenade_kit -> Wire.put_u8 w 2
  | Flag team -> Wire.put_u8 w 3; Wire.put_u8 w team
  | Bonus b -> Wire.put_u8 w 4; put_one w kits b);
  put_particles w t.points;
  Wire.put_varint w (max 0 t.ttl);
  Wire.put_signed w t.holder;
  put_bits w [ t.still; t.in_base; t.facing = 1 ]

let get_thing (r : r) : Soldat_things.t =
  let kind : Soldat_things.kind =
    match Wire.get_u8 r with
    | 0 -> Weapon (get_gun r)
    | 1 -> Medikit
    | 2 -> Grenade_kit
    | 3 -> Flag (Wire.get_u8 r)
    | 4 -> Bonus (get_one r kits "a kit")
    | _ -> Wire.fail r "not a thing"
  in
  let points = get_particles r in
  if Array.length points <> (match kind with Weapon _ -> 2 | _ -> 4) then Wire.fail r "a thing's points";
  let ttl = Wire.get_varint r in
  let holder = Wire.get_signed r in
  let k = Wire.get_u16 r in
  { kind; points; ttl; interest = 0; still = bit k 0; in_base = bit k 1; facing = (if bit k 2 then 1 else -1); place = -1; hits = 1; holder }

let put_event (w : w) ((owner, e) : int * Soldat_event.t) : unit =
  Wire.put_signed w owner;
  match e with
  | Sound (sfx, at) -> Wire.put_u8 w 0; put_one w sounds sfx; put_point w at
  | Shot { weapon; hand; bullet; aim; speed; facing } ->
      Wire.put_u8 w 1; put_weapon w weapon; put_point w hand; put_point w bullet; put_point w aim; put_point w speed; put_bool w (facing = 1)
  | Pumped { hand; along; speed; facing } -> Wire.put_u8 w 2; put_point w hand; put_point w along; put_point w speed; put_bool w (facing = 1)
  | Clip { weapon; hand; speed } -> Wire.put_u8 w 3; put_weapon w weapon; put_point w hand; put_point w speed
  | Jets { feet = (f1, f2); legs = (l1, l2); speed } -> Wire.put_u8 w 4; List.iter (put_point w) [ f1; f2; l1; l2; speed ]
  | Dust { at; speed; up } -> Wire.put_u8 w 5; put_point w at; put_point w speed; put_float w up
  | Wall (at, v) -> Wire.put_u8 w 6; put_point w at; put_point w v
  | Ricochet (at, v) -> Wire.put_u8 w 7; put_point w at; put_point w v
  | Blood (at, v) -> Wire.put_u8 w 8; put_point w at; put_point w v
  | Flesh (at, v) -> Wire.put_u8 w 9; put_point w at; put_point w v
  | Blast (weapon, at) -> Wire.put_u8 w 10; put_weapon w weapon; put_point w at

let get_event (r : r) : int * Soldat_event.t =
  let owner = Wire.get_signed r in
  let two () =
    let at = get_point r in
    let v = get_point r in
    (at, v)
  in
  let e : Soldat_event.t =
    match Wire.get_u8 r with
    | 0 ->
        let sfx = get_one r sounds "a sound" in
        let at = get_point r in
        Sound (sfx, at)
    | 1 ->
        let weapon = get_weapon r in
        let hand = get_point r in
        let bullet = get_point r in
        let aim = get_point r in
        let speed = get_point r in
        let right = get_bool r in
        Shot { weapon; hand; bullet; aim; speed; facing = (if right then 1 else -1) }
    | 2 ->
        let hand = get_point r in
        let along = get_point r in
        let speed = get_point r in
        let right = get_bool r in
        Pumped { hand; along; speed; facing = (if right then 1 else -1) }
    | 3 ->
        let weapon = get_weapon r in
        let hand = get_point r in
        let speed = get_point r in
        Clip { weapon; hand; speed }
    | 4 ->
        let f1 = get_point r in
        let f2 = get_point r in
        let l1 = get_point r in
        let l2 = get_point r in
        let speed = get_point r in
        Jets { feet = (f1, f2); legs = (l1, l2); speed }
    | 5 ->
        let at = get_point r in
        let speed = get_point r in
        let up = get_float r in
        Dust { at; speed; up }
    | 6 -> let (at, v) = two () in Wall (at, v)
    | 7 -> let (at, v) = two () in Ricochet (at, v)
    | 8 -> let (at, v) = two () in Blood (at, v)
    | 9 -> let (at, v) = two () in Flesh (at, v)
    | 10 ->
        let weapon = get_weapon r in
        let at = get_point r in
        Blast (weapon, at)
    | _ -> Wire.fail r "not an event"
  in
  (owner, e)

(*****************************************************************************)
(* What is exchanged *)
(*****************************************************************************)

let encode_control (c : Soldat_soldier.control) : string = Wire.to_bytes (fun w -> put_control w c)
let decode_control (bytes : string) : (Soldat_soldier.control, string) result = Wire.parse get_control bytes
let encode_body (s : Soldat_soldier.t) : string = Wire.to_bytes (fun w -> put_body w s)
let decode_body (bytes : string) : (Soldat_soldier.t, string) result = Wire.parse get_body bytes

let encode_world (p : play) (events : (int * Soldat_event.t) list) : string =
  Wire.to_bytes (fun w ->
      put_one w modes p.mode;
      Wire.put_varint w (fst p.captures); Wire.put_varint w (snd p.captures);
      (match p.news with
      | Some (words, ticks) -> put_bool w true; Wire.put_string w words; Wire.put_varint w ticks
      | None -> put_bool w false);
      Wire.put_varint w p.time_left;
      Wire.put_varint w p.frame;
      put_list w (fun (killer, weapon, killed, ticks) -> Wire.put_string w killer; put_one w (None :: List.map Option.some weapons) weapon; Wire.put_string w killed; Wire.put_varint w ticks) p.log;
      put_list w (put_soldier w) (Array.to_list p.soldiers);
      put_list w (put_bullet w) p.bullets;
      put_list w (put_thing w) p.things;
      put_list w (put_event w) events)

let decode_world (map : Soldat_map.t) (bytes : string) : (play, string) result =
  Wire.parse
    (fun r ->
      let mode = get_one r modes "a mode" in
      let alpha = Wire.get_varint r in
      let bravo = Wire.get_varint r in
      let news =
        if get_bool r then begin
          let words = Wire.get_string r in
          let ticks = Wire.get_varint r in
          Some (words, ticks)
        end
        else None
      in
      let time_left = Wire.get_varint r in
      let frame = Wire.get_varint r in
      let log =
        get_list r (fun () ->
            let killer = Wire.get_string r in
            let weapon = get_one r (None :: List.map Option.some weapons) "a weapon" in
            let killed = Wire.get_string r in
            (killer, weapon, killed, Wire.get_varint r))
      in
      let soldiers = Array.of_list (get_list r (fun () -> get_soldier r)) in
      if Array.length soldiers = 0 then Wire.fail r "a round without a soldier";
      let bullets = get_list r (fun () -> get_bullet r) in
      let things = get_list r (fun () -> get_thing r) in
      let events = get_list r (fun () -> get_event r) in
      let n = Array.length soldiers in
      (* who a bullet or a flag is of must be one of them *)
      if List.exists (fun (b : bullet) -> b.owner < -1 || b.owner >= n) bullets || List.exists (fun (t : Soldat_things.t) -> t.holder < -1 || t.holder >= n) things then
        Wire.fail r "a soldier that is not there";
      {
        map; mode; captures = (alpha, bravo); news; camera = (0., 0.); soldiers; brains = Array.make n None; minds = Array.make n None; bullets; things;
        sparks = []; spark_seed = Lehmer.of_int 1; sounds = []; events; time_left; seed = Lehmer.of_int 1; frame; log; bonuses = 0;
      })
    bytes
