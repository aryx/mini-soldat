(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* A tick of the game, in Soldat's order (server/ServerLoop.pas): each
 * living soldier moves and fires (Soldat_soldier.tick: its keys, the
 * player's or a bot's), each bullet is tested along where it is going
 * and then moves (Soldat_bullets), the walls hurt who touches them,
 * the things fall and are picked up (Soldat_things), the dead tumble
 * and come back; then what all of that gave to see and hear: the
 * sparks (Soldat_sparks) and the tick's sounds; then the camera.
 *
 * **A round** is a deathmatch: the first to 10 kills, or who has most
 * when 10 minutes are over (Soldat's sv_killlimit and sv_timelimit).
 * The dead come back after 3 seconds, at a place of the map taken by
 * chance, with the weapon they chose.
 *
 * [tick] knows no keyboard and no screen: it is given what the player
 * wants (an intent, as the bots give theirs) and where it looks. So a
 * test calls it, and one day a server will, with the intents the
 * network brought. [update] is the Playground's: it reads the keys and
 * the mouse, and calls [tick].
 *
 * **Chance.** A shot's direction is turned by chance (Soldat's
 * Random). The game's own numbers come from a seed kept in its state
 * (Lehmer: the next seed is 16807 times the last, modulo 2^31 - 1),
 * drawn in the order the soldiers fire: the same seed and the same
 * keys give the same game, on any machine.
 *
 * In Soldat: client/UpdateFrame.pas and server/ServerLoop.pas (the
 * tick), TSprite.Respawn (Sprites.pas).
 *)
open Playground
open Soldat_model (* its types, used all along *)

(*****************************************************************************)
(* The player *)
(*****************************************************************************)

(* Soldat's keys (client/configs/controls.cfg): A and D, W to jump, S to
 * crouch, X to lie down, the left button to fire, the right one for the
 * jets (shift too, for a pad without one), R to reload, Q for the other
 * weapon, E for a grenade, F to throw the weapon away.
 * The mouse is on the screen, y upwards; the soldier in the map, y
 * downwards *)
let human (computer : computer) (p : play) : intent =
  let k = computer.keyboard and m = computer.mouse in
  let key l = Set_.mem l k.keys in
  let z = zoom computer.screen in
  let (cx, cy) = p.camera in
  {
    left = key "a"; right = key "d"; up = key "w"; down = key "s"; prone = key "x";
    jetpack = m.mrdown || k.kshift;
    fire = m.mdown;
    reload = key "r"; change = key "q"; grenade = key "e"; drop = key "f";
    aim = (cx +. (m.mx /. z), cy -. (m.my /. z));
  }

(* the key of a weapon in Soldat's menu, 1 to 9 then 0, if one is down *)
let chosen (computer : computer) : Soldat_weapons.id option =
  List.mapi (fun i id -> (string_of_int ((i + 1) mod 10), id)) Soldat_weapons.primaries
  |> List.find_map (fun (key, id) -> if Set_.mem key computer.keyboard.keys then Some id else None)

(*****************************************************************************)
(* The walls *)
(*****************************************************************************)

(* what the walls a soldier touched this tick do to its health
 * (HandleSpecialPolyTypes, S:3071, the server's branches): the deadly
 * ones take all of it and more, the hurting ones and lava 5 now and
 * then, the healing ones give 2 back every 12 ticks. Soldat hurts one
 * tick in ten by chance; here every tenth tick *)
let wall_damage (ticks : int) (s : soldier) : float =
  List.fold_left
    (fun damage (kind : Pms.kind) ->
      match kind with
      | Deadly -> Float.max damage (s.health +. 50.)
      | Bloody_deadly -> Float.max damage (s.health +. 450.)
      | Explodes -> Float.max damage 4000.
      | Hurts | Lava -> if ticks mod 10 = 0 then Float.max damage 5. else damage
      | Regenerates -> if ticks mod 12 = 0 && damage = 0. && s.health < full_health then -2. else damage
      | _ -> damage)
    0. s.body.touched

(*****************************************************************************)
(* A tick *)
(*****************************************************************************)

(* Soldat's camera (client/UpdateFrame.pas): 0.14 of the way to the
 * player each tick, and moved by a seventh of [look], where the cursor
 * is from the screen's middle: one sees farther where one points. Dead,
 * it follows the body's head *)
let follow (p : play) (me : soldier) ((lx, ly) : float * float) : float * float =
  let (cx, cy) = p.camera in
  let (px, py) = Soldat_bullets.place me in
  (cx +. (0.14 *. (px -. cx)) +. (lx /. 7.), cy +. (0.14 *. (py -. cy)) +. (ly /. 7.))

(* sv_respawntime *)
let respawn_ticks = 180

(* a place for a soldier of a team to appear at, by chance: one of its
 * team's, or of everyone's (RandomizeStart) *)
let place (map : Soldat_map.t) ~(random : unit -> float) (team : int) : float * float =
  let places = match team with 1 when map.alpha_spawns <> [] -> map.alpha_spawns | 2 when map.bravo_spawns <> [] -> map.bravo_spawns | _ -> map.spawns in
  List.nth places (min (List.length places - 1) (int_of_float (random () *. float_of_int (List.length places))))

(* Rambo's bow, at one of the map's places for it, or for a soldier if
 * it has none (RandomizeStart(a, 15)) *)
let bow (map : Soldat_map.t) ~(random : unit -> float) : Soldat_things.t =
  let places = if map.bow_spawns <> [] then map.bow_spawns else map.spawns in
  Soldat_things.bow (List.nth places (min (List.length places - 1) (int_of_float (random () *. float_of_int (List.length places)))))

(* a round on a map: the player with [primary], against [bots].
 * [mode]: the map's own if none is said (capture the flag where it has
 * the two flags' places). In a deathmatch each appears as far as can
 * be from those before it; with teams, the player is Alpha's and the
 * bots are Bravo's and Alpha's in turn, each at one of its team's
 * places. [engine]: the last of the bots is not Soldat's but the one
 * on elm-playground's Sense and Bot (Soldat_engine_bot). [seed]: the
 * round's chance, the same round from the same one *)
let start ?(bots : character list = []) ?(engine = false) ?(primary : Soldat_weapons.id = Ak74) ?(secondary : Soldat_weapons.id = Socom) ?(bonuses = 0) ?(seed = 1) ?(mode : mode option) (map : Soldat_map.t) : play =
  let mode = Option.value mode ~default:(mode_of map) in
  let seed' = seed in
  (* which of the bots, numbered from 1 as the soldiers are, is it *)
  let engine_at = if engine && bots <> [] then List.length bots else -1 in
  let bots = List.mapi (fun i c -> if i + 1 = engine_at then Soldat_engine_bot.character else c) bots in
  let seed = ref (Lehmer.scramble seed) in
  let random () =
    seed := Lehmer.next !seed;
    Lehmer.to_unit !seed
  in
  let teams = Soldat_model.teams mode in
  let soldier (place : float * float) (name : string) ~(team : int) ~(shirt : int * int * int) ~(trousers : int * int * int) ~(skin : int * int * int) ~(human : bool) (primary : Soldat_weapons.id) : soldier =
    let secondary = if human then secondary else Soldat_weapons.Socom in
    (* a team's soldiers wear its colour *)
    let shirt = if team = 0 then shirt else team_shirt team in
    let (r, g, b) = shirt in
    { name; color = Playground.rgb r g b; shirt; trousers; skin; human; body = Soldat_soldier.create ~primary ~secondary ~human ~team place map.jet; health = full_health; dead = None; kills = 0; deaths = 0; primary; hit_by = -1;
      secondary; bonus = None; vest = 0. }
  in
  let first = if teams then place map ~random 1 else spawn map 0 in
  let (soldiers, _) =
    List.fold_left
      (fun (soldiers, taken) (c : character) ->
        (* Bravo's, then Alpha's, and so on: the player is Alpha's *)
        let team = if teams then if List.length soldiers mod 2 = 1 then 2 else 1 else 0 in
        let at = if teams then place map ~random team else farthest map taken in
        let weapon = if c == Soldat_engine_bot.character then c.favourite else Soldat_bots.weapon c ~random in
        (soldier at c.bot ~team ~shirt:c.bot_shirt ~trousers:c.bot_trousers ~skin:c.bot_skin ~human:false weapon :: soldiers, at :: taken))
      ([ soldier first "YOU" ~team:(if teams then 1 else 0) ~shirt:(220, 60, 50) ~trousers:(110, 30, 25) ~skin:(230, 180, 120) ~human:true primary ], [ first ])
      bots
  in
  let kits = Soldat_things.kits map ~random in
  let things = kits @ (match mode with
      | Capture_the_flag | Infiltration -> Soldat_things.flags map
      | Pointmatch | Hold_the_flag -> [ Soldat_things.yellow map ~random ]
      | _ -> []) @ if mode = Rambomatch then [ bow map ~random ] else [] in
  {
    map; mode; captures = (0, 0); news = None; camera = first; soldiers = Array.of_list (List.rev soldiers);
    brains = Array.of_list (None :: List.mapi (fun i c -> if i + 1 = engine_at then None else Some (Soldat_bots.brain c)) bots);
    minds = Array.of_list (None :: List.mapi (fun i _ -> if i + 1 = engine_at then Some (Bot.start still) else None) bots);
    bullets = []; things; events = []; sparks = []; spark_seed = Lehmer.scramble (seed' + 1000); sounds = []; time_left = time_limit; seed = !seed; frame = 0; log = []; bonuses;
    ai = top Ai; physics = top Physics; effects = top Effects; juice = Soldat_juice.none;
  }

(* a tick: [player] is what the human soldier wants, [look] where its
 * cursor is from the screen's middle, in the map's units. With several
 * players (a server's room), [controls i] is what soldier [i] wants,
 * for each that no bot drives; [me], the soldier the camera follows *)
let tick ?(controls : (int -> intent) option) ?(me = 0) (p : play) (player : intent) ~(look : float * float) : play =
  let p = { p with frame = p.frame + 1; time_left = max 0 (p.time_left - 1) } in
  let soldiers = Array.copy p.soldiers in
  let brains = Array.copy p.brains in
  let minds = Array.copy p.minds in
  let seed = ref p.seed in
  let random () =
    seed := Lehmer.next !seed;
    Lehmer.to_unit !seed
  in
  let shots = ref [] in
  let things = ref (Array.of_list p.things) in
  (* what is to be heard and seen of this tick, each with the soldier
   * it is of (nobody's: -1), the last first *)
  let events = ref [] in
  let heard = ref [] in
  let say (owner : int) (l : Soldat_event.t list) : unit = events := List.rev_append (List.map (fun e -> (owner, e)) l) !events in
  (* 1. the living soldiers: their keys, their move, their shots *)
  soldiers
  |> Array.iteri (fun i s ->
         if s.dead = None then begin
           let it =
             (* a bot at the round's level of bots (docs/twins.md): 0, it
              * stands; 1, the Playground's twin for all of them *)
             let mind = if p.ai = 1 && brains.(i) <> None then Some (Option.value minds.(i) ~default:(Bot.start still)) else minds.(i) in
             match (brains.(i), mind) with
             | (None, None) -> ( match controls with Some of_ -> of_ i | None -> player)
             | (Some _, _) when p.ai = 0 -> still
             | (_, Some mind) when p.ai = 1 || brains.(i) = None ->
                 (* the twin: its senses, late, and its mind *)
                 let (it, mind) = Bot.step Soldat_engine_bot.mind (p, i) mind in
                 minds.(i) <- Some mind;
                 it
             | (None, Some _) -> still
             | (Some brain, _) ->
                 let (it, brain, looked) = Soldat_bots.control p i brain ~random in
                 brains.(i) <- Some brain;
                 List.iter (fun n -> !things.(n) <- { (!things.(n)) with interest = !things.(n).interest - 1 }) looked;
                 it
           in
           let body = Soldat_soldier.tick p.map ~ticks:p.frame ~random s.body it in
           shots := !shots @ List.map (Soldat_bullets.of_shot ~owner:i) body.shots;
           say i (List.rev body.events);
           (* out of the map: back at a spawn point, as Soldat does *)
           let body = if Soldat_soldier.out_of_map p.map body then Soldat_soldier.create ~primary:s.primary ~secondary:s.secondary ~human:s.human ~team:(team s) (spawn p.map (i + p.frame)) p.map.jet else body in
           soldiers.(i) <- { s with body; hit_by = -1 }
         end);
  (* 2. the bullets: tested along their way, then moved *)
  let (flown, bullets) = Soldat_bullets.run ~rambo:(p.mode = Rambomatch) p.map soldiers (p.bullets @ !shots) in
  let soldiers = flown.soldiers and knives = flown.knives in
  say (-1) (List.rev flown.events);
  (* a Pointmatch: a kill is worth two to who holds the yellow flag
   * (S:1705; Soldat's points for several kills in a row are not here) *)
  if p.mode = Pointmatch then
    List.iter
      (fun (t : Soldat_things.t) ->
        if t.kind = Flag 0 && t.holder >= 0 then begin
          let s = soldiers.(t.holder) in
          soldiers.(t.holder) <- { s with kills = s.kills + max 0 (s.kills - p.soldiers.(t.holder).kills) }
        end)
      p.things;
  (* 3. the walls (by one's own hand, as Soldat counts it) *)
  let world : Soldat_bullets.world = { (Soldat_bullets.world ~rambo:(p.mode = Rambomatch) p.map soldiers []) with soldiers } in
  soldiers
  |> Array.iteri (fun i s ->
         if s.dead = None then begin
           let damage = wall_damage p.frame s in
           if damage <> 0. then Soldat_bullets.hurt world i ~by:i ~where:1 damage
         end);
  say (-1) (List.rev world.events);
  (* who killed whom, said for 7 seconds, the last 6 of them *)
  let log =
    List.map (fun (by, i, weapon) -> (soldiers.(by).name, (if by = i then None else weapon), soldiers.(i).name, 420)) (world.killed @ flown.killed)
    @ List.filter_map (fun (a, w, b, ticks) -> if ticks > 1 then Some (a, w, b, ticks - 1) else None) p.log
    |> List.filteri (fun n _ -> n < 6)
  in
  (* 4. the things: they fall; a living soldier in reach takes one, the
   * nearest first; a kit taken or lost appears again elsewhere *)
  let captures = ref p.captures and news = ref (match p.news with Some (words, ticks) when ticks > 1 -> Some (words, ticks - 1) | _ -> None) in
  let tell words = news := Some (words, 180) in
  let colour t = if t = 1 then "Red" else "Blue" in
  let members t = Array.fold_left (fun n (s : soldier) -> if Soldat_model.team s = t then n + 1 else n) 0 soldiers in
  (* a flag (the round's rules for it: TThing.Update and
   * CheckSpriteCollision): carried, its foot at its carrier's waist; *)
  let flag (team : int) (thing : Soldat_things.t) : Soldat_things.t =
    let carrier = if thing.holder >= 0 && soldiers.(thing.holder).dead = None then thing.holder else -1 in
    let carried = if carrier >= 0 then Some (Soldat_soldier.point soldiers.(carrier).body 8) else None in
    let thing = Option.get (Soldat_things.tick ~heard ?carried p.map { thing with holder = carrier }) in
    let foot = thing.points.(0).pos in
    (* the other team's flag, as the tick found it *)
    let other = if team = 0 then None else List.find_opt (fun (t : Soldat_things.t) -> t.kind = Flag (3 - team)) p.things in
    if Soldat_things.lost p.map thing || (carrier < 0 && thing.ttl = 0) then Soldat_things.again p.map ~random thing
    else if carrier >= 0 then begin
      (* brought to its carrier's own flag, standing at home: a point *)
      match other with
      | Some home when home.in_base && home.holder < 0 && Float.hypot (fst foot -. fst home.points.(0).pos) (snd foot -. snd home.points.(0).pos) < Soldat_things.touchdown_radius ->
          let (a, b) = !captures in
          (* Infiltration: Alpha's 30 for the objective brought home (sv_inf_redaward),
           * less 5 for each soldier it has more than Bravo (T:879) *)
          let award = if p.mode = Infiltration then max 0 (30 - (5 * max 0 (members 1 - members 2))) else 1 in
          captures := if team = 2 then (a + award, b) else (a, b + award);
          tell (Printf.sprintf "%s Team scores! (%s)" (team_name (3 - team)) soldiers.(carrier).name);
          heard := Sound (Ctf_score, foot) :: !heard;
          Soldat_things.again p.map ~random thing
      | _ -> thing
    end
    else begin
      (* the nearest living soldier within its reach, past its first 90
       * ticks: its own team's takes it home at once, unless it is
       * there; the other's carries it off *)
      let near =
        Array.to_list (Array.mapi (fun i (s : soldier) -> (i, s)) soldiers)
        |> List.filter_map (fun (i, (s : soldier)) ->
               if s.dead = None && s.body.ceasefire = 0 then Option.map (fun d -> (d, i)) (Soldat_things.reach thing (s.body.x, s.body.y)) else None)
        |> List.sort compare
      in
      match near with
      (* Infiltration: Alpha's flag is only where the objective is brought (T:1763) *)
      | _ when p.mode = Infiltration && team = 1 -> thing
      | (_, i) :: _ when team = 0 ->
          tell (soldiers.(i).name ^ " got the Yellow Flag");
          heard := Sound (Capture, foot) :: !heard;
          { thing with holder = i; still = false }
      | (_, i) :: _ when Soldat_model.team soldiers.(i) = team && not thing.in_base ->
          tell (Printf.sprintf "%s returned the %s Flag" soldiers.(i).name (colour team));
          heard := Sound (Capture, foot) :: !heard;
          Soldat_things.again p.map ~random thing
      | (_, i) :: _ when Soldat_model.team soldiers.(i) <> team ->
          tell (Printf.sprintf "%s captured the %s Flag" soldiers.(i).name (colour team));
          heard := Sound (Capture, foot) :: !heard;
          { thing with holder = i; still = false }
      | _ -> thing
    end
  in
  let things =
    Array.to_list !things
    |> List.filter_map (fun (thing : Soldat_things.t) ->
           match thing.kind with
           | Flag team -> Some (flag team thing)
           | _ ->
           (* the physics' level 0: a thing stays where it is *)
           match Soldat_things.tick ~heard p.map (if p.physics = 0 then { thing with still = true } else thing) with
           | None -> None
           | Some thing when Soldat_things.lost p.map thing -> Some (Soldat_things.again p.map ~random thing)
           | Some thing -> (
               let wants (s : soldier) : bool =
                 s.dead = None
                 &&
                 match thing.kind with
                 | Medikit -> s.health < full_health
                 | Grenade_kit -> s.body.grenades < Soldat_things.max_grenades && not (s.body.cluster && s.body.grenades > 0)
                 | Weapon _ | Flag _ -> true
                 (* a bonus: for who has none, and may fire; a vest, for
                  * who has less than a whole one (T:1716) *)
                 | Bonus Vest_kit -> s.vest < default_vest
                 | Bonus Cluster_kit -> (not s.body.cluster) || s.body.grenades = 0
                 | Bonus Flamer_kit -> s.bonus = None && s.body.ceasefire = 0 && not (rambo s)
                 | Bonus (Predator_kit | Berserker_kit) -> s.bonus = None && s.body.ceasefire = 0
               in
               let nearest =
                 Array.to_list (Array.mapi (fun i (s : soldier) -> (i, s)) soldiers)
                 |> List.filter_map (fun (i, (s : soldier)) -> if wants s then Option.map (fun d -> (d, i)) (Soldat_things.reach thing (s.body.x, s.body.y)) else None)
                 |> List.sort compare
               in
               match (nearest, thing.kind) with
               | ((_, i) :: _, Weapon g) ->
                   let s = soldiers.(i) in
                   let bow = Soldat_things.is_bow thing in
                   if s.body.weapon.kind.id = Hands && s.body.body.id <> Change && thing.ttl < Soldat_things.gun_time - (if bow then 100 else 30) then begin
                     if bow then begin
                       (* the bow: an arrow on it, its other arrows as the
                        * second weapon; who has it is Rambo (T:1963) *)
                       soldiers.(i) <- { s with body = { (Soldat_soldier.take s.body { g with ammo = 1 }) with secondary = Soldat_soldier.gun Bow2 } };
                       heard := Sound (Take_bow, (s.body.x, s.body.y)) :: !heard;
                       tell (if s.human && i = me then "You got the Bow!" else s.name ^ " is Rambo")
                     end
                     else begin
                       soldiers.(i) <- { s with body = Soldat_soldier.take s.body g };
                       heard := Sound (Take_gun, (s.body.x, s.body.y)) :: !heard
                     end;
                     None
                   end
                   else Some thing
               | ((_, i) :: _, Medikit) ->
                   soldiers.(i) <- { (soldiers.(i)) with health = full_health };
                   heard := Sound (Take_medikit, (soldiers.(i).body.x, soldiers.(i).body.y)) :: !heard;
                   Some (Soldat_things.again p.map ~random thing)
               | ((_, i) :: _, Grenade_kit) ->
                   let s = soldiers.(i) in
                   soldiers.(i) <- { s with body = { s.body with grenades = Soldat_things.max_grenades; cluster = false } };
                   heard := Sound (Pickup, (s.body.x, s.body.y)) :: !heard;
                   Some (Soldat_things.again p.map ~random thing)
               | ((_, i) :: _, Bonus b) ->
                   (* T:2041: the kit's gift, said to who took it *)
                   let s = soldiers.(i) in
                   let (s, sound, words) : soldier * Soldat_sfx.t * string =
                     match b with
                     | Flamer_kit ->
                         (* its weapon goes to its back, the flamer to its hands *)
                         let body = { s.body with secondary = s.body.weapon; weapon = Soldat_soldier.gun Flamer } in
                         ({ s with body; bonus = Some (Flame_god, flamer_time); health = full_health }, God_flame, "Flame God Mode!")
                     | Predator_kit -> ({ s with bonus = Some (Predator, predator_time); health = full_health }, Predator, "Predator Mode!")
                     | Berserker_kit -> ({ s with bonus = Some (Berserker, berserker_time); health = full_health }, Berserker, "Berserker Mode!")
                     | Vest_kit -> ({ s with vest = default_vest }, Vest_take, "Bulletproof Vest!")
                     | Cluster_kit -> ({ s with body = { s.body with grenades = cluster_grenades; cluster = true } }, Pickup, "Cluster grenades!")
                   in
                   soldiers.(i) <- s;
                   heard := Sound (sound, (s.body.x, s.body.y)) :: !heard;
                   if i = me then tell words;
                   None
               | (_, Flag _) | ([], _) -> Some thing))
  in
  (* the weapons let go of this tick, thrown away or by the dead *)
  let dropped = ref [] in
  soldiers
  |> Array.iteri (fun i s ->
         match s.body.dropped with
         | Some g ->
             (* the flamer is nobody's to pick up *)
             if g.kind.id <> Flamer then dropped := Soldat_things.weapon s.body ~alive:(s.dead = None) g :: !dropped;
             soldiers.(i) <- { s with body = { s.body with dropped = None } }
         | None -> ());
  (* the points time gives (ServerLoop:598): in Hold the Flag, one to
   * the team that has the yellow flag, every 5 seconds, and 2 seconds
   * more for each soldier it has more than the other; in Infiltration,
   * one to Bravo every 5 seconds its flag is at home, and 2 seconds
   * more for each soldier it has more than Alpha *)
  let every team = 300 + (120 * max 0 (members team - members (3 - team))) in
  let point team = let (a, b) = !captures in captures := if team = 1 then (a + 1, b) else (a, b + 1) in
  List.iter
    (fun (t : Soldat_things.t) ->
      match (p.mode, t.kind) with
      | (Hold_the_flag, Flag 0) when t.holder >= 0 ->
          let team = Soldat_model.team soldiers.(t.holder) in
          if p.frame mod every team = 0 then point team
      | (Infiltration, Flag 2) when t.in_base && p.frame mod every 2 = 0 -> point 2
      | _ -> ())
    things;
  (* a knife thrown lies where it fell (B:1395) *)
  let things = things @ List.rev !dropped @ List.map (Soldat_things.lying Knife) knives in
  (* a bonus's time (S:1250); the dead have none, nor a vest (S:2353);
   * the flamer leaves with the Flame God's (this last is not Soldat's:
   * there the flamer is kept) *)
  soldiers
  |> Array.iteri (fun i (s : soldier) ->
         match s.bonus with
         | _ when s.dead <> None -> if s.bonus <> None || s.vest > 0. then soldiers.(i) <- { s with bonus = None; vest = 0. }
         | Some (b, ticks) when ticks > 1 -> soldiers.(i) <- { s with bonus = Some (b, ticks - 1) }
         | Some (Flame_god, _) when s.body.weapon.kind.id = Flamer -> soldiers.(i) <- { s with bonus = None; body = { s.body with weapon = Soldat_soldier.gun Hands } }
         | Some _ -> soldiers.(i) <- { s with bonus = None }
         | None -> ());
  (* the bonus kits appear now and then, by chance (ServerLoop:378) *)
  let things =
    if p.bonuses = 0 then things
    else
      let often = [| 7400; 4300; 2500; 1600; 800 |].(min 4 (p.bonuses - 1)) in
      let clusters = if p.mode = Capture_the_flag then 3 else 4 in
      List.fold_left
        (fun things ((kit : Soldat_things.bonus), every, one_in) ->
          if p.frame mod every = 0 && int_of_float (random () *. float_of_int one_in) = 0 then things @ Option.to_list (Soldat_things.bonus p.map ~random kit) else things)
        things
        [ (Berserker_kit, often, 4); (Flamer_kit, 444, 5); (Predator_kit, often, 5); (Vest_kit, often / 2, 4); (Cluster_kit, often / 2, clusters) ]
  in
  (* a Rambomatch: the bow gives health back to who holds it, one every
   * 3 ticks (S:1276); and, looked at every second, if it is neither on
   * the map nor in anybody's hands, another appears (ServerLoop:642) *)
  if p.mode = Rambomatch && p.frame mod 3 = 0 then
    Array.iteri (fun i (s : soldier) -> if rambo s && s.health < full_health then soldiers.(i) <- { s with health = s.health +. 1. }) soldiers;
  let things =
    if p.mode = Rambomatch && p.frame mod 60 = 0
       && (not (List.exists Soldat_things.is_bow things))
       && not (Array.exists (fun (s : soldier) -> s.dead = None && (Soldat_weapons.is_bow s.body.weapon.kind.id || Soldat_weapons.is_bow s.body.secondary.kind.id)) soldiers)
    then things @ [ bow p.map ~random ]
    else things
  in
  (* 5. the dead tumble, and come back after 3 s *)
  soldiers
  |> Array.iteri (fun i s ->
         match s.dead with
         | None -> ()
         | Some (ticks, ragdoll) ->
             if ticks > respawn_ticks then begin
               (* at one of the map's places for it, by chance (RandomizeStart) *)
               let (x, y) = place p.map ~random (team s) in
               let primary = match brains.(i) with Some brain -> Soldat_bots.weapon brain.character ~random | None -> s.primary in
               soldiers.(i) <- { s with dead = None; health = full_health; body = Soldat_soldier.create ~primary ~secondary:s.secondary ~human:s.human ~team:(team s) (x, y) p.map.jet };
               if not s.human then heard := Sound (Spawn, (x, y)) :: !heard
             end
             else soldiers.(i) <- { s with dead = Some (ticks + 1, if p.physics = 0 then ragdoll else Soldat_ragdoll.tick ~heard p.map ragdoll) });
  say (-1) (List.rev !heard);
  (* 6. what it all gave to see and to hear: the sparks, with a chance
   * of their own, and the sounds *)
  let spark_seed = ref p.spark_seed in
  let random () =
    spark_seed := Lehmer.next !spark_seed;
    Lehmer.to_unit !spark_seed
  in
  let (old, clinks) = Soldat_sparks.tick p.map ~random p.sparks in
  let (fresh, sounds) =
    List.fold_left
      (fun (sparks, sounds) (owner, event) ->
        let (s, h) = Soldat_sparks.of_event p.map ~random ~owner event in
        (sparks @ s, sounds @ h))
      ([], clinks) (List.rev !events)
  in
  (* the effects' level: 2, Soldat's sparks; 1, the Playground's twin,
   * fed the same events (the sounds are the sparks' all the same); 0, none *)
  let sparks = if p.effects = 2 then Soldat_sparks.capped (old @ fresh) else [] in
  let juice = if p.effects = 1 then Soldat_juice.step (List.fold_left (fun j (_, event) -> Soldat_juice.of_event j event) p.juice (List.rev !events)) else Soldat_juice.none in
  (* the camera, shaken by an explosion's fire; the twin's goes after
   * its soldier with Follow, and is shaken by its Trauma *)
  let (cx, cy) =
    if p.effects = 1 then
      let (px, py) = Soldat_bullets.place soldiers.(me) and (x, y) = p.camera in
      (Follow.smooth ~rate:9. ~dt:(1. /. 60.) (px +. fst look) x, Follow.smooth ~rate:9. ~dt:(1. /. 60.) (py +. snd look) y)
    else follow p soldiers.(me) look
  in
  let (wx, wy) = match p.effects with 2 -> Soldat_sparks.wobble ~random sparks | 1 -> Soldat_juice.shake juice | _ -> (0., 0.) in
  { p with log; juice; captures = !captures; news = !news; camera = (cx +. wx, cy +. wy); soldiers; brains; minds; bullets; things; events = List.rev !events; sparks; spark_seed = !spark_seed; sounds; seed = !seed }

(*****************************************************************************)
(* The rounds *)
(*****************************************************************************)

(* who has won, if the round is over: a soldier's name, or a team's.
 * The first at the limit; or, the time over, who has most *)
let winner (p : play) : string option =
  let all = Array.to_list p.soldiers in
  let over = p.time_left = 0 in
  match p.mode with
  | Deathmatch | Rambomatch | Pointmatch -> (
      match List.find_opt (fun s -> s.kills >= limit p) all with
      | Some s -> Some s.name
      | None -> if over then Some (List.fold_left (fun best s -> if s.kills > best.kills then s else best) (List.hd all) all).name else None)
  | Team_match | Capture_the_flag | Hold_the_flag | Infiltration ->
      let (a, b) = (score p 1, score p 2) in
      if a >= limit p || (over && a > b) then Some "ALPHA TEAM"
      else if b >= limit p || (over && b > a) then Some "BRAVO TEAM"
      else if over then Some "NOBODY"
      else None

(* the keys that are any scene's: g, the next way of drawing; 1 to 9
 * and 0, the weapon to appear with. With the scenes a frame later,
 * which know the keys that just went down *)
let common (computer : computer) (model : model) : model * scene Scene2d.t =
  let scenes = Scene2d.update computer model.scenes in
  (* a layer's key: its next level, round to its first, said for a moment *)
  let model = { model with said = (match model.said with Some (words, frames) when frames > 1 -> Some (words, frames - 1) | _ -> None) } in
  let model =
    List.fold_left
      (fun model (layer, key, name, first, names) ->
        if model.typing = None && Scene2d.pressed (fun k -> Set_.mem key k.keys) scenes then begin
          let n = first + ((level model layer - first + 1) mod List.length names) in
          { model with levels = (layer, n) :: List.remove_assoc layer model.levels; said = Some (Printf.sprintf "%s %d: %s" name n (List.nth names (n - first)), 150) }
        end
        else model)
      model layers
  in
  (* z: every twin at once, the Playground's libraries; again: Soldat's own *)
  let model =
    if model.typing = None && Scene2d.pressed (fun k -> Set_.mem "z" k.keys) scenes then begin
      let on = List.for_all (fun (layer, n) -> level model layer = n) twins in
      let levels = List.map (fun (layer, n) -> match List.assoc_opt layer twins with Some twin -> (layer, if on then top layer else twin) | None -> (layer, n)) model.levels in
      { model with levels; said = Some ((if on then "Soldat's own" else "the twins: the Playground's Space, Juice and ai"), 150) }
    end
    else model
  in
  Soldat_sound.level := level model Audio;
  (* 1 to 9 and 0: the weapon to appear with, from now on *)
  let model = match chosen computer with Some primary -> { model with primary } | None -> model in
  (* c: the second weapon, round the four *)
  let model =
    if Scene2d.pressed (fun k -> Set_.mem "c" k.keys) scenes && model.typing = None then
      let all = Soldat_weapons.secondaries in
      let rec next = function a :: b :: _ when a = model.secondary -> b | _ :: rest -> next rest | [] -> List.hd all in
      { model with secondary = next all }
    else model
  in
  (model, scenes)

let update (computer : computer) (model : model) : model =
  let (model, scenes) = common computer model in
  let space = Scene2d.pressed (fun k -> k.kspace) scenes in
  let scenes =
    match scenes.scene with
    | Loading name -> (
        (* the map asked by its name: its file comes when it comes; if
         * it does not, or is no map, the one the program carries *)
        match Soldat_assets.bytes ("maps/" ^ name ^ ".pms") with
        | Loading -> scenes
        | Missing -> Scene2d.go (Title (Lazy.force Soldat_map.arena2)) scenes
        | Here bytes -> (
            match Pms.parse bytes with
            | Ok pms -> Scene2d.go (Title (Soldat_map.of_pms pms)) scenes
            | Error _ -> Scene2d.go (Title (Lazy.force Soldat_map.arena2)) scenes))
    | Title map | Over (_, map) ->
        (* nobody flies: no jets are heard *)
        Soldat_sound.jets ~listener:(0., 0.) ~soldiers:16 [];
        (* and the sounds are got meanwhile *)
        if not !Soldat_sound.mute then ignore (Soldat_sound.warm ());
        (* a round's chance and its cast are its number's: each one its
         * own, and the same again *)
        (* ai=engine: one of them on Sense and Bot *)
        let engine = List.assoc_opt "ai" computer.flags = Some "engine" in
        (* m: the next of the game's maps, got as any content *)
        if Scene2d.pressed (fun k -> Set_.mem "m" k.keys) scenes then Scene2d.go (Loading (List.nth maps (model.next_map mod List.length maps))) scenes
        else if space then Scene2d.go (Playing (start ~bots:(Soldat_bots.cast model.bots model.rounds) ~engine ~primary:model.primary ~secondary:model.secondary ~bonuses:model.bonuses ~seed:model.rounds ?mode:model.mode map)) scenes else scenes
    | Online _ | Lobby _ | Connecting _ -> scenes (* Soldat_online's *)
    | Playing p -> (
        let z = zoom computer.screen in
        let mine = p.soldiers.(0) in
        let p =
          (* the round's layers are the model's *)
          let p = { p with ai = level model Ai; physics = level model Physics; effects = level model Effects } in
          if mine.primary <> model.primary || mine.secondary <> model.secondary then
            { p with soldiers = Array.mapi (fun i (s : soldier) -> if i = 0 then { s with primary = model.primary; secondary = model.secondary } else s) p.soldiers }
          else p
        in
        let p = tick p (human computer p) ~look:(computer.mouse.mx /. z, -.computer.mouse.my /. z) in
        (* what the tick gave to hear, from where the player is *)
        let listener = Soldat_bullets.place p.soldiers.(0) in
        Soldat_sound.play ~listener ~frame:p.frame p.sounds;
        Soldat_sound.jets ~listener ~soldiers:(Array.length p.soldiers)
          (List.filter_map (fun (i, (s : soldier)) -> if s.dead = None && s.body.jetting then Some (i, (s.body.x, s.body.y)) else None) (List.mapi (fun i s -> (i, s)) (Array.to_list p.soldiers)));
        match winner p with Some name -> Scene2d.go (Over (name, p.map)) scenes | None -> { scenes with scene = Playing p })
  in
  let model = match (model.scenes.scene, scenes.scene) with ((Title _ | Over _), Loading _) -> { model with next_map = model.next_map + 1 } | _ -> model in
  let rounds = match (model.scenes.scene, scenes.scene) with ((Title _ | Over _), Playing _) -> model.rounds + 1 | _ -> model.rounds in
  { model with scenes; rounds }
