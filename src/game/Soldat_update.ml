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
 * and come back; then the camera.
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

(* ticks an explosion is drawn for *)
let explosion_ticks = 24

(* a round on a map: the player with [primary], against [bots], each
 * at a place of the map as far as can be from those before it.
 * [engine]: the last of them is not Soldat's but the one on
 * elm-playground's Sense and Bot (Soldat_engine_bot). [seed]: the
 * round's chance, the same round from the same one *)
let start ?(bots : character list = []) ?(engine = false) ?(primary : Soldat_weapons.id = Ak74) ?(seed = 1) (map : Soldat_map.t) : play =
  (* which of the bots, numbered from 1 as the soldiers are, is it *)
  let engine_at = if engine && bots <> [] then List.length bots else -1 in
  let bots = List.mapi (fun i c -> if i + 1 = engine_at then Soldat_engine_bot.character else c) bots in
  let seed = ref (Lehmer.scramble seed) in
  let random () =
    seed := Lehmer.next !seed;
    Lehmer.to_unit !seed
  in
  let soldier (place : float * float) (name : string) ~(shirt : int * int * int) ~(trousers : int * int * int) ~(skin : int * int * int) ~(human : bool) (primary : Soldat_weapons.id) : soldier =
    let (r, g, b) = shirt in
    { name; color = Playground.rgb r g b; shirt; trousers; skin; human; body = Soldat_soldier.create ~primary ~human place map.jet; health = full_health; dead = None; kills = 0; primary; hit_by = -1 }
  in
  let first = spawn map 0 in
  let (soldiers, _) =
    List.fold_left
      (fun (soldiers, taken) (c : character) ->
        let place = farthest map taken in
        let weapon = if c == Soldat_engine_bot.character then c.favourite else Soldat_bots.weapon c ~random in
        (soldier place c.bot ~shirt:c.bot_shirt ~trousers:c.bot_trousers ~skin:c.bot_skin ~human:false weapon :: soldiers, place :: taken))
      ([ soldier first "YOU" ~shirt:(220, 60, 50) ~trousers:(110, 30, 25) ~skin:(230, 180, 120) ~human:true primary ], [ first ])
      bots
  in
  let things = Soldat_things.kits map ~random in
  {
    map; camera = first; soldiers = Array.of_list (List.rev soldiers);
    brains = Array.of_list (None :: List.mapi (fun i c -> if i + 1 = engine_at then None else Some (Soldat_bots.brain c)) bots);
    minds = Array.of_list (None :: List.mapi (fun i _ -> if i + 1 = engine_at then Some (Bot.start still) else None) bots);
    bullets = []; explosions = []; things; time_left = time_limit; seed = !seed; frame = 0;
  }

(* a tick: [player] is what the human soldier wants, [look] where its
 * cursor is from the screen's middle, in the map's units *)
let tick (p : play) (player : intent) ~(look : float * float) : play =
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
  (* 1. the living soldiers: their keys, their move, their shots *)
  soldiers
  |> Array.iteri (fun i s ->
         if s.dead = None then begin
           let it =
             match (brains.(i), minds.(i)) with
             | (None, None) -> player
             | (None, Some mind) ->
                 (* the bot of ai=engine: its senses, late, and its mind *)
                 let (it, mind) = Bot.step Soldat_engine_bot.mind (p, i) mind in
                 minds.(i) <- Some mind;
                 it
             | (Some brain, _) ->
                 let (it, brain, looked) = Soldat_bots.control p i brain ~random in
                 brains.(i) <- Some brain;
                 List.iter (fun n -> !things.(n) <- { (!things.(n)) with interest = !things.(n).interest - 1 }) looked;
                 it
           in
           let body = Soldat_soldier.tick p.map ~ticks:p.frame ~random s.body it in
           shots := !shots @ List.map (Soldat_bullets.of_shot ~owner:i) body.shots;
           (* out of the map: back at a spawn point, as Soldat does *)
           let body = if Soldat_soldier.out_of_map p.map body then Soldat_soldier.create ~primary:s.primary ~human:s.human (spawn p.map (i + p.frame)) p.map.jet else body in
           soldiers.(i) <- { s with body; hit_by = -1 }
         end);
  (* 2. the bullets: tested along their way, then moved *)
  let (soldiers, bullets, explosions) = Soldat_bullets.tick p.map soldiers (p.bullets @ !shots) in
  (* 3. the walls (by one's own hand, as Soldat counts it) *)
  let world : Soldat_bullets.world = { map = p.map; soldiers; pushes = Array.make (Array.length soldiers) (0., 0.); bullets = [||]; explosions = [] } in
  soldiers
  |> Array.iteri (fun i s ->
         if s.dead = None then begin
           let damage = wall_damage p.frame s in
           if damage <> 0. then Soldat_bullets.hurt world i ~by:i ~where:1 damage
         end);
  (* 4. the things: they fall; a living soldier in reach takes one, the
   * nearest first; a kit taken or lost appears again elsewhere *)
  let things =
    Array.to_list !things
    |> List.filter_map (fun (thing : Soldat_things.t) ->
           match Soldat_things.tick p.map thing with
           | None -> None
           | Some thing when Soldat_things.lost p.map thing -> Some (Soldat_things.again p.map ~random thing)
           | Some thing -> (
               let wants (s : soldier) : bool =
                 s.dead = None
                 &&
                 match thing.kind with
                 | Medikit -> s.health < full_health
                 | Grenade_kit -> s.body.grenades < Soldat_things.max_grenades
                 | Weapon _ -> true
               in
               let nearest =
                 Array.to_list (Array.mapi (fun i (s : soldier) -> (i, s)) soldiers)
                 |> List.filter_map (fun (i, (s : soldier)) -> if wants s then Option.map (fun d -> (d, i)) (Soldat_things.reach thing (s.body.x, s.body.y)) else None)
                 |> List.sort compare
               in
               match (nearest, thing.kind) with
               | ((_, i) :: _, Weapon g) ->
                   let s = soldiers.(i) in
                   if s.body.weapon.kind.id = Hands && s.body.body.id <> Change && thing.ttl < Soldat_things.gun_time - 30 then begin
                     soldiers.(i) <- { s with body = Soldat_soldier.take s.body g };
                     None
                   end
                   else Some thing
               | ((_, i) :: _, Medikit) ->
                   soldiers.(i) <- { (soldiers.(i)) with health = full_health };
                   Some (Soldat_things.again p.map ~random thing)
               | ((_, i) :: _, Grenade_kit) ->
                   let s = soldiers.(i) in
                   soldiers.(i) <- { s with body = { s.body with grenades = Soldat_things.max_grenades } };
                   Some (Soldat_things.again p.map ~random thing)
               | ([], _) -> Some thing))
  in
  (* the weapons let go of this tick, thrown away or by the dead *)
  let dropped = ref [] in
  soldiers
  |> Array.iteri (fun i s ->
         match s.body.dropped with
         | Some g ->
             dropped := Soldat_things.weapon s.body ~alive:(s.dead = None) g :: !dropped;
             soldiers.(i) <- { s with body = { s.body with dropped = None } }
         | None -> ());
  let things = things @ List.rev !dropped in
  (* 5. the dead tumble, and come back after 3 s *)
  soldiers
  |> Array.iteri (fun i s ->
         match s.dead with
         | None -> ()
         | Some (ticks, ragdoll) ->
             if ticks > respawn_ticks then begin
               (* at one of the map's places, by chance (RandomizeStart) *)
               let (x, y) = List.nth p.map.spawns (min (List.length p.map.spawns - 1) (int_of_float (random () *. float_of_int (List.length p.map.spawns)))) in
               let primary = match brains.(i) with Some brain -> Soldat_bots.weapon brain.character ~random | None -> s.primary in
               soldiers.(i) <- { s with dead = None; health = full_health; body = Soldat_soldier.create ~primary ~human:s.human (x, y) p.map.jet }
             end
             else soldiers.(i) <- { s with dead = Some (ticks + 1, Soldat_ragdoll.tick p.map ragdoll) });
  let explosions = explosions @ List.filter_map (fun (e : explosion) -> if e.age < explosion_ticks then Some { e with age = e.age + 1 } else None) p.explosions in
  { p with camera = follow p soldiers.(0) look; soldiers; brains; minds; bullets; explosions; things; seed = !seed }

(*****************************************************************************)
(* The rounds *)
(*****************************************************************************)

(* who has won, if the round is over: the first at the kill limit; or,
 * the time over, who has most *)
let winner (p : play) : soldier option =
  let all = Array.to_list p.soldiers in
  match List.find_opt (fun s -> s.kills >= kill_limit) all with
  | Some s -> Some s
  | None -> if p.time_left > 0 then None else Some (List.fold_left (fun best s -> if s.kills > best.kills then s else best) (List.hd all) all)

let update (computer : computer) (model : model) : model =
  let scenes = Scene2d.update computer model.scenes in
  let space = Scene2d.pressed (fun k -> k.kspace) scenes in
  (* g: the next way of drawing, round to the first *)
  let model =
    if Scene2d.pressed (fun k -> Set_.mem "g" k.keys) scenes then { model with graphics = (model.graphics mod graphics_levels) + 1; graphics_shown = 150 }
    else { model with graphics_shown = max 0 (model.graphics_shown - 1) }
  in
  (* 1 to 9 and 0: the weapon to appear with, from now on *)
  let model = match chosen computer with Some primary -> { model with primary } | None -> model in
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
        (* a round's chance and its cast are its number's: each one its
         * own, and the same again *)
        (* ai=engine: one of them on Sense and Bot *)
        let engine = List.assoc_opt "ai" computer.flags = Some "engine" in
        if space then Scene2d.go (Playing (start ~bots:(Soldat_bots.cast model.bots model.rounds) ~engine ~primary:model.primary ~seed:model.rounds map)) scenes else scenes
    | Playing p -> (
        let z = zoom computer.screen in
        let p = if p.soldiers.(0).primary <> model.primary then { p with soldiers = Array.mapi (fun i (s : soldier) -> if i = 0 then { s with primary = model.primary } else s) p.soldiers } else p in
        let p = tick p (human computer p) ~look:(computer.mouse.mx /. z, -.computer.mouse.my /. z) in
        match winner p with Some s -> Scene2d.go (Over (s.name, p.map)) scenes | None -> { scenes with scene = Playing p })
  in
  let rounds = match (model.scenes.scene, scenes.scene) with ((Title _ | Over _), Playing _) -> model.rounds + 1 | _ -> model.rounds in
  { model with scenes; rounds }
