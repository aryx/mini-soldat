(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* A frame of the game: the soldiers act (the player's keys, the bots'
 * minds), the world steps, the bullets fly, the grenades blow up, the
 * dead become ragdolls and come back.
 *
 * - The bullets fly at 1500 pixels per second, 25 pixels a tick, more
 *   than a wall's or a soldier's width: tested by where they went
 *   (Physics.went_through, Collide's swept tests), not where they are
 *   -- tunneling.
 * - The grenades are bouncy bodies in the world, and their blast pushes
 *   the soldiers and the ragdolls away, weaker with the distance.
 *
 * In Soldat: shared/mechanics/Control.pas (the keys to a soldier's
 * moves), Sprites.pas (the soldier's frame), Bullets.pas, Things.pas,
 * and the frame itself, client/UpdateFrame.pas and
 * server/ServerLoop.pas.
 *)
open Playground
open Basics (* float arithmetics *)
open Soldat_model (* its types, used all along *)

(*****************************************************************************)
(* The player *)
(*****************************************************************************)

let human (computer : computer) (scenes : model) (p : play) : intent =
  let k = computer.keyboard and m = computer.mouse in
  let me = body_of p 0 in
  let letter l = Set_.mem l k.keys in
  {
    run = (if letter "d" then 1. else 0.) - if letter "a" then 1. else 0.;
    jump = Scene2d.pressed (fun k -> Set_.mem "w" k.keys) scenes;
    jet = letter "w";
    shoot = m.mdown || k.kspace;
    grenade = Scene2d.pressed (fun k -> Set_.mem "q" k.keys) scenes;
    aim = degrees (m.mx - me.x) (m.my - me.y);
  }

(*****************************************************************************)
(* A soldier *)
(*****************************************************************************)

(* feet on something: a thin box under the soldier touching the map or
 * another soldier *)
let grounded (p : play) (b : Physics.body) : bool =
  let feet = Physics.body (rectangle white 18. 6.) |> Physics.at b.x (b.y - 24.) in
  List.exists (fun other -> other != b && Physics.touching feet other) p.world.bodies

(* the soldier's body driven by its intent, before the world's step *)
let drive (p : play) (s : soldier) (it : intent) (b : Physics.body) : soldier * Physics.body =
  let on_ground = grounded p b in
  (* running: towards the speed wanted, fast on the ground, slowly in
   * the air *)
  let wanted = it.run * 300. in
  let vx = b.vx + ((wanted - b.vx) * if on_ground then 0.3 else 0.05) in
  let vy = if it.jump && on_ground then 450. else b.vy in
  let jetting = it.jet && (not on_ground) && s.fuel > 0. in
  let b = b |> Physics.moving vx vy |> fun b -> if jetting then Physics.push 0. 1900. b else b in
  let fuel = if jetting then s.fuel - 1.2 else if on_ground then min 100. (s.fuel + 2.) else s.fuel in
  ({ s with fuel; aim = it.aim }, b)

(* a body pointing where the soldier aims: what shot_from fires from *)
let gun (s : soldier) (b : Physics.body) : Physics.body = b |> Physics.at b.x (b.y + 10.) |> Physics.pointing s.aim

let bullet_shape = circle (rgb 250 230 120) 2.5
let grenade_shape = circle (rgb 50 70 40) 7.

let blast_radius = 160.

(*****************************************************************************)
(* A frame *)
(*****************************************************************************)

let update_play (computer : computer) (scenes : model) (p : play) : play =
  let p = { p with frame = p.frame +.. 1 } in
  let bodies = Array.of_list p.world.bodies in
  let soldiers = Array.copy p.soldiers in
  let minds = Array.copy p.minds in
  let new_bullets = ref [] and new_grenades = ref [] in
  (* 1. the living soldiers act *)
  soldiers
  |> Array.iteri (fun i s ->
         if s.dead = None then (
           let it =
             if s.human then human computer scenes p
             else if not p.ai_engine then Soldat_bots.bot p i
             else begin
               let (it, mind') = Bot.step Soldat_bots.mind (p, i) minds.(i) in
               minds.(i) <- mind';
               it
             end
           in
           let (s, b) = drive p s it bodies.(n_map +.. i) in
           bodies.(n_map +.. i) <- b;
           let s = if s.reload > 0 then { s with reload = s.reload -.. 1 } else s in
           let s = if s.grenade_reload > 0 then { s with grenade_reload = s.grenade_reload -.. 1 } else s in
           let s =
             if it.shoot && s.reload = 0 then (
               new_bullets := { b = Physics.body bullet_shape |> Physics.shot_from 1500. 26. (gun s b); owner = i; ttl = 60 } :: !new_bullets;
               { s with reload = 8 })
             else s
           in
           let s =
             if it.grenade && s.grenade_reload = 0 then (
               new_grenades :=
                 (Physics.body grenade_shape |> Physics.shot_from 550. 26. (gun s b) |> Physics.bouncy 0.5 |> Physics.rough 0.5 |> Physics.heavy 0.3, i)
                 :: !new_grenades;
               { s with grenade_reload = (if s.human then 60 else 240) })
             else s
           in
           soldiers.(i) <- s));
  (* 2. the world steps: the map, the soldiers, the grenades *)
  let world = Physics.simulate ~gravity:Soldat_map.gravity { p.world with bodies = Array.to_list bodies @ List.map fst !new_grenades } in
  let bodies = Array.of_list world.bodies in
  let grenades = p.grenades @ List.map (fun (_, i) -> { fuse = 120; thrower = i }) !new_grenades in
  let damage = Array.make 3 0. and killer = Array.make 3 (-1) and knock = Array.make 3 (0., 0.) in
  let hurt i amount by (kx, ky) =
    if soldiers.(i).dead = None then (
      damage.(i) <- damage.(i) + amount;
      killer.(i) <- by;
      knock.(i) <- (fst knock.(i) + kx, snd knock.(i) + ky))
  in
  (* 3. the bullets: swept against the map and the soldiers *)
  let bullets =
    (p.bullets @ !new_bullets)
    |> List.filter_map (fun (bl : bullet) ->
           let b = bl.b |> Physics.fall 150. |> Physics.step in
           let hit_soldier =
             List.find_opt (fun i -> i <> bl.owner && soldiers.(i).dead = None && Physics.went_through b bodies.(n_map +.. i)) [ 0; 1; 2 ]
           in
           match hit_soldier with
           | Some i ->
               hurt i 20. bl.owner (b.vx * 0.15, b.vy * 0.15);
               None
           | None ->
               if bl.ttl = 0 || List.exists (Physics.went_through b) Soldat_map.bodies then None
               else Some { bl with b; ttl = bl.ttl -.. 1 })
  in
  (* 4. the grenades' fuses, and their blasts *)
  let n_soldiers = 3 in
  let grenade_body k = bodies.(n_map +.. n_soldiers +.. k) in
  let blasts = ref (List.filter_map (fun bl -> if bl.age < 20 then Some { bl with age = bl.age +.. 1 } else None) p.blasts) in
  let ragdoll_kicks = ref [] in
  grenades
  |> List.iteri (fun k g ->
         if g.fuse = 0 then (
           let gb = grenade_body k in
           blasts := { x = gb.x; y = gb.y; age = 0 } :: !blasts;
           ragdoll_kicks := (gb.x, gb.y) :: !ragdoll_kicks;
           for i = 0 to n_soldiers -.. 1 do
             let sb = bodies.(n_map +.. i) in
             let d = Float.hypot (sb.x - gb.x) (sb.y - gb.y) in
             if d < blast_radius then (
               let f = 1. - (d / blast_radius) in
               let (ux, uy) = if d = 0. then (0., 1.) else ((sb.x - gb.x) / d, (sb.y - gb.y) / d) in
               hurt i (90. * f) g.thrower (ux * 600. * f, (uy * 600. * f) + (200. * f));
               if soldiers.(i).dead = None then bodies.(n_map +.. i) <- sb |> Physics.moving (sb.vx + (ux * 600. * f)) (sb.vy + (uy * 600. * f) + (200. * f)))
           done));
  (* the grenades that blew up leave the world (they're at its end) *)
  let keep = List.map (fun g -> g.fuse > 0) grenades in
  let bodies_list =
    Array.to_list bodies |> List.filteri (fun i _ -> i < n_map +.. n_soldiers || List.nth keep (i -.. n_map -.. n_soldiers))
  in
  let grenades = List.filter_map (fun g -> if g.fuse > 0 then Some { g with fuse = g.fuse -.. 1 } else None) grenades in
  let bodies = Array.of_list bodies_list in
  (* 5. the damage: deaths become ragdolls, the dead respawn after 2 s *)
  soldiers
  |> Array.iteri (fun i s ->
         match s.dead with
         | None ->
             let health = s.health - damage.(i) in
             if health <= 0. then (
               let b = bodies.(n_map +.. i) in
               soldiers.(i) <- { s with health = 0.; dead = Some (0, Soldat_ragdoll.ragdoll b knock.(i)) };
               if killer.(i) >= 0 && killer.(i) <> i then
                 soldiers.(killer.(i)) <- { (soldiers.(killer.(i))) with kills = soldiers.(killer.(i)).kills +.. 1 };
               bodies.(n_map +.. i) <- parked s.color)
             else soldiers.(i) <- { s with health }
         | Some (n, ps) ->
             (* the blasts kick the ragdolls too: their old positions
              * moved back, away from the blast *)
             let ps =
               List.fold_left
                 (fun ps (gx, gy) ->
                   Array.map
                     (fun (q : Particles.particle) ->
                       let (x, y) = q.pos in
                       let d = Float.hypot (x - gx) (y - gy) in
                       if d < blast_radius && d > 0. then
                         let f = 12. * (1. - (d / blast_radius)) in
                         { q with old = (fst q.old - ((x - gx) / d * f), snd q.old - ((y - gy) / d * f)) }
                       else q)
                     ps)
                 ps !ragdoll_kicks
             in
             if n > 120 then (
               (* respawn at the spawn point farthest from the living *)
               let living = List.filter (fun j -> soldiers.(j).dead = None) [ 0; 1; 2 ] in
               let room (x, y) = List.fold_left (fun m j -> let b = bodies.(n_map +.. j) in min m (Float.hypot (b.x - x) (b.y - y))) infinity living in
               let spot = List.fold_left (fun best sp -> if room sp > room best then sp else best) (List.hd Soldat_map.spawns) Soldat_map.spawns in
               bodies.(n_map +.. i) <- soldier_body s.color spot;
               soldiers.(i) <- { s with dead = None; health = 100.; fuel = 100. })
             else soldiers.(i) <- { s with dead = Some (n +.. 1, Soldat_ragdoll.move ps) });
  { p with world = { world with bodies = Array.to_list bodies }; soldiers; minds; bullets; grenades; blasts = !blasts }

(*****************************************************************************)
(* The rounds *)
(*****************************************************************************)

let winner (p : play) : soldier option = Array.to_list p.soldiers |> List.find_opt (fun s -> s.kills >= 5)

let update (computer : computer) (model : model) : model =
  let scenes = Scene2d.update computer model in
  let space = Scene2d.pressed (fun k -> k.kspace) scenes in
  match scenes.scene with
  | Title | Over _ ->
      (* ai=engine chooses the bots, at the start of a round *)
      let ai_engine = List.assoc_opt "ai" computer.flags = Some "engine" in
      if space then Scene2d.go (Playing (start ~ai_engine ())) scenes else scenes
  | Playing p -> (
      let p = update_play computer scenes p in
      match winner p with Some s -> Scene2d.go (Over s.name) scenes | None -> { scenes with scene = Playing p })
