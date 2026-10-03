(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)
(* The picture of a tick: the map, the soldiers, the bullets, the
 * explosions, the score, and what the player has: health, ammunition,
 * jets, grenades.
 *
 * The game is in Soldat's coordinates, y downwards; the Playground's y
 * goes up. Here, and only here, a point (x, y) of the game is drawn at
 * (x, -y) ([at]), through a camera that shows 640 units across, as
 * Soldat does.
 *
 * A soldier is drawn as Soldat draws it, a picture on each limb of
 * its skeleton (Soldat_gostek), alive or dead. The flag sticks adds
 * the skeleton's own sticks over it, and hitboxes what the game tests:
 * the particle, the points of the head and the feet, the circles a
 * bullet hits.
 *
 * A bullet is a streak along its way, a grenade its picture; the
 * sparks (blood, shells, smoke, an explosion's fire) are
 * Soldat_sparks_view's, over the soldiers and under the map's
 * polygons, as Soldat has them: a drop that falls into the ground is
 * not seen again.
 *
 * The interface is bars and words at the bottom left, where Soldat
 * has its own (drawn with pictures there: interface-gfx/): the health,
 * the ammunition (which fills again as the reload goes), the jets, the
 * grenades; and the weapons to choose from, by their keys, on the
 * title and while dead (Soldat's menu, there clicked).
 *
 * In Soldat: client/GameRendering.pas, whose order this follows (what
 * is behind, the bullets, the soldiers, then the map's polygons over
 * them), over MapGraphics.pas, GostekGraphics.pas and
 * InterfaceGraphics.pas.
 *)
open Playground
open Basics (* float arithmetics *)
open Soldat_model (* its types, used all along *)

(* a point of the game, in the picture *)
let at ((x, y) : float * float) : float * float = (x, -.y)

let text (color : color) (size : number) (s : string) : shape = words color s |> scale size

(* a line from a to b, points of the game *)
let segment (color : color) (width : number) (a : float * float) (b : float * float) : shape =
  let (x1, y1) = at a and (x2, y2) = at b in
  rectangle color (Float.hypot (x2 - x1) (y2 - y1)) width
  |> rotate (Float.atan2 (y2 - y1) (x2 - x1) * 180. / Float.pi)
  |> move ((x1 + x2) / 2.) ((y1 + y2) / 2.)

let dot (color : color) (radius : number) (p : float * float) : shape =
  let (x, y) = at p in
  circle color radius |> move x y

let bar (color : color) (width : number) (fraction : number) ((x, y) : float * float) : shape list =
  let fraction = Float.max 0. (Float.min 1. fraction) in
  [ rectangle (rgb 40 40 40) width 1.5 |> move x y; rectangle color (width * fraction) 1.5 |> move (x - (width * (1. - fraction) / 2.)) y ]

(* the skeleton's sticks alone, thin: what the flag sticks shows *)
let figure (color : color) (points : (float * float) array) : shape list =
  List.map (fun (st : Particles.stick) -> segment color 0.5 points.(st.a) points.(st.b)) Soldat_ragdoll.sticks

(* a soldier as its skeleton and no more, in its colour: the sticks,
 * a head above the neck, away from the hips, and a line for its gun *)
let stick_figure (color : color) (points : (float * float) array) (gun : ((float * float) * (float * float)) option) : shape list =
  let (nx, ny) = points.(8) and (hx, hy) = points.(5) in
  let d = Float.max 0.001 (Float.hypot (nx - hx) (ny - hy)) in
  List.map (fun (st : Particles.stick) -> segment color 1.6 points.(st.a) points.(st.b)) Soldat_ragdoll.sticks
  @ [ dot color 2.6 (nx + ((nx - hx) / d * 3.5), ny + ((ny - hy) / d * 3.5)) ]
  @ match gun with Some (from, to_) -> [ segment (rgb 30 30 30) 1.4 from to_ ] | None -> []

(* a soldier's colours: a bot's are its character's *)
let colors (s : soldier) : Soldat_gostek.colors = { shirt = s.shirt; trousers = s.trousers; skin = s.skin }

(* the weapon's clip is in: with ammunition, or early or late in a
 * reload (RenderGostek's ShowClip); the minigun's belt until late *)
let clip_in (g : Soldat_soldier.gun) : bool =
  g.ammo > 0 || if g.kind.id = Minigun then g.reload_count < 65 else g.reload_count < g.kind.clip_in || g.reload_count > g.kind.clip_out

let view_soldier (computer : computer) ~(graphics : int) (s : soldier) : shape list =
  let b = s.body in
  let sticks = List.mem_assoc "sticks" computer.flags in
  match s.dead with
  | Some (_, ragdoll) ->
      let points = Array.map (fun (p : Particles.particle) -> p.pos) ragdoll.points in
      (* the weapon on its back stays there; the one it held is gone *)
      (if graphics >= 2 then
         Soldat_gostek.view ~back:(Soldat_gostek.on_back b.secondary.kind.id) (colors s) ~point:(fun n -> points.(n -.. 1)) ~direction:b.direction ~jets:false ~dead:true
       else List.map (fun (st : Particles.stick) -> segment s.color 1.6 points.(st.a) points.(st.b)) (Soldat_ragdoll.holding ragdoll))
      @ if sticks then figure white points else []
  | None ->
      let over = at (b.x, b.y - 30.) in
      (if graphics >= 2 then
         Soldat_gostek.view
           ~weapon:(Soldat_gostek.in_hands b.weapon.kind.id ~clip:(clip_in b.weapon) ~fire:b.fired)
           ~back:(Soldat_gostek.on_back b.secondary.kind.id) (colors s) ~point:(Soldat_soldier.point b) ~direction:b.direction ~jets:b.jetting ~dead:false
         (* the predator's is hardly seen (PREDATORALPHA: 5 of 255; here a tenth, to be played) *)
         |> List.map (if has s Predator then fade 0.1 else Fun.id)
       else
         (* the gun: from the arm's end, away from the hand that holds it *)
         let (hx, hy) = Soldat_soldier.point b 16 and (tx, ty) = Soldat_soldier.point b 15 in
         stick_figure s.color b.skeleton (Some ((tx, ty), (tx + ((tx - hx) / 7. * 6.), ty + ((ty - hy) / 7. * 6.)))))
      @ (if sticks then figure white b.skeleton else [])
      (* the others' health over their heads; one's own is in the interface *)
      @ if s.human then [] else bar (rgb 220 60 60) 16. (s.health / full_health) over

(* what the game tests, over a soldier *)
let view_tested (s : soldier) : shape list =
  if s.dead <> None then []
  else
    let b = s.body in
    List.map (fun p -> dot (rgb 255 255 255) 7. (Soldat_soldier.point b p) |> fade 0.25) Soldat_bullets.hit_points
    @ List.map (dot (rgb 255 0 255) 0.8) [ (b.x, b.y); (b.x - 3.5, b.y - 12.); (b.x + 3.5, b.y - 12.); (b.x + 2., b.y + 2.); (b.x - 2., b.y + 2.) ]

(* the map under a camera looking at a point of the game: what goes
 * behind the soldiers, the sky first, and what goes over them *)
let scene (computer : computer) ~(graphics : int) (map : Soldat_map.t) (centre : float * float) : shape list * shape list =
  let z = zoom computer.screen in
  let (back, front) =
    if graphics >= 3 then Soldat_scene.view map ~centre ~half:(computer.screen.width / 2. / z, computer.screen.height / 2. / z) else (map.back, map.front)
  in
  (map.sky @ back, front)

(* the map alone, seen from where the first soldier will appear: what
 * is behind a title *)
let view_map (computer : computer) ~(graphics : int) (map : Soldat_map.t) : shape =
  let (x, y) = at (spawn map 0) in
  let (back, front) = scene computer ~graphics map (spawn map 0) in
  Camera2d.view { x; y; zoom = zoom computer.screen; angle = 0. } (back @ front)

(* a bullet: a streak behind it, longer and brighter for a rifle's; a
 * grenade its picture, turning as it goes; the M79's its shell, along
 * its way *)
let view_bullet ~(graphics : int) (b : bullet) : shape list =
  let plain () = [ segment (rgb 250 230 120) 0.8 (b.x, b.y) (b.x - (b.vx * 0.6), b.y - (b.vy * 0.6)) ] in
  let or_dot name angle = match if graphics >= 2 then Soldat_gostek.loose name (b.x, b.y) angle else [] with [] -> [ dot (rgb 60 70 50) 1.6 (b.x, b.y) ] | shapes -> shapes in
  match (Soldat_weapons.get b.weapon).style with
  | Plain -> plain ()
  | Pellets -> [ segment (rgb 250 240 180) 0.6 (b.x, b.y) (b.x - (b.vx * 0.3), b.y - (b.vy * 0.3)) ]
  | Thrown -> or_dot (if b.weapon = Cluster_grenade then "cluster-grenade" else "frag-grenade") (float_of_int b.ttl * -0.2 * if b.vx >= 0. then 1. else -1.)
  | Explosive -> or_dot (match b.weapon with Law -> "missile" | Cluster -> "cluster" | _ -> "m79-bullet") (Float.atan2 b.vy b.vx)
  (* a blow is not seen; a flame grows as it goes; the knife turns *)
  | Melee -> []
  | Flame -> let (x, y) = at (b.x, b.y) in [ circle (rgb 255 150 40) (3. + (float_of_int (32 -.. b.ttl) / 3.)) |> fade 0.6 |> move x y ]
  | Flying_knife -> or_dot "knife" (float_of_int b.ttl * 0.4)
  | Arrow -> or_dot "arrow" (Float.atan2 b.vy b.vx)

(* a thing on the ground (TThing.Render): a weapon its picture from
 * its first point along to its second, blinking in its last 5 seconds;
 * a kit its box's picture over its four points *)
let view_thing ~(graphics : int) (thing : Soldat_things.t) : shape list =
  let (ax, ay) = thing.points.(0).pos and (bx, by) = thing.points.(1).pos in
  let angle = Float.atan2 (by - ay) (bx - ax) in
  let plain color = [ segment color 1.5 (ax, ay) (bx, by) ] in
  match thing.kind with
  | Flag team ->
      (* its pole, and its cloth between its top, its two loose points
       * and the pole's middle, in its team's colour; blinking in the
       * last 5 seconds before it goes home by itself *)
      if thing.holder < 0 && (not thing.in_base) && thing.ttl < 300 && thing.ttl mod 6 < 3 then []
      else
        let p n = thing.points.(n).pos in
        let (r, g, b) = team_shirt team in
        let middle = ((ax + bx) / 2., (ay + by) / 2.) in
        [ polygon (rgb r g b) (List.map at [ p 1; p 2; p 3; middle ]); segment (rgb 200 200 200) 1. (p 0) (p 1) ]
  | Weapon g ->
      if thing.ttl < 300 && thing.ttl mod 6 < 3 then []
      else if graphics < 2 then plain (rgb 40 40 40)
      else (
        (* the bow on the ground has pictures of its own *)
        let name = (if Soldat_weapons.is_bow g.kind.id then "n-bow" else (Soldat_gostek.look g.kind.id).image) ^ if thing.facing = 1 then "" else "-2" in
        match Soldat_gostek.lying name (ax, ay) angle with [] -> plain (rgb 40 40 40) | shapes -> shapes)
  | Medikit | Grenade_kit | Bonus _ -> (
      let name =
        match thing.kind with
        | Medikit -> "medikit"
        | Bonus Flamer_kit -> "flamerkit"
        | Bonus Predator_kit -> "predatorkit"
        | Bonus Vest_kit -> "vestkit"
        | Bonus Berserker_kit -> "berserkerkit"
        | Bonus Cluster_kit -> "clusterkit"
        | _ -> "grenadekit"
      in
      let n = float_of_int (Array.length thing.points) in
      let middle = Array.fold_left (fun (x, y) (p : Particles.particle) -> (x + (fst p.pos / n), y + (snd p.pos / n))) (0., 0.) thing.points in
      let box () =
        let (x, y) = at middle in
        [ rectangle (if thing.kind = Medikit then rgb 230 230 230 else rgb 90 110 70) 10.75 8.6 |> rotate (-.angle * 180. / Float.pi + 180.) |> move x y ]
      in
      if graphics < 2 then box ()
      else match Soldat_assets.picture ~keyed:false "textures/objects" name with
        | Here picture ->
            let (x, y) = at middle in
            [ bitmap 10.75 8.6 picture |> rotate (-.angle * 180. / Float.pi + 180.) |> move x y ]
        | Loading | Missing -> box ())

(* the map's waypoints, what the bots walk along (the flag waypoints):
 * each a dot, a line to each it leads to, and the keys it says to hold *)
let view_waypoints (map : Soldat_map.t) : shape list =
  let place (w : Pms.waypoint) = (float_of_int w.x, float_of_int w.y) in
  Array.to_list map.waypoints
  |> List.concat_map (fun (w : Pms.waypoint) ->
         if not w.active then []
         else
           let keys = (if w.left then "<" else "") ^ (if w.up then "^" else "") ^ (if w.jetpack then "*" else "") ^ (if w.down then "v" else "") ^ if w.right then ">" else "" in
           let (x, y) = at (place w) in
           List.filter_map (fun n -> if n >= 1 && n <= Array.length map.waypoints then Some (segment (rgb 255 255 0) 0.4 (place w) (place map.waypoints.(n -.. 1)) |> fade 0.5) else None) w.connections
           @ [ dot (if w.path = 1 then rgb 255 255 0 else rgb 255 140 0) 1.5 (place w); text white 0.5 keys |> move x (y + 5.) ])

(* what the player has, at the bottom left: its health, its weapon's
 * name and ammunition (filling again as it reloads), its jets, its
 * grenades *)
let view_interface (computer : computer) (map : Soldat_map.t) (me : soldier) : shape list =
  let screen = computer.screen in
  let g = me.body.weapon in
  let line i = screen.bottom + 70. + (26. * float_of_int i) in
  let gauge i color name fraction said =
    let fraction = Float.max 0. (Float.min 1. fraction) in
    let x = screen.left + 150. in
    [ text white 1.6 name |> move (screen.left + 50.) (line i);
      rectangle (rgb 30 30 30) 124. 14. |> move x (line i) |> fade 0.6;
      rectangle color (120. * fraction) 10. |> move (x - (60. * (1. - fraction))) (line i);
      text white 1.6 said |> move (screen.left + 260.) (line i) ]
  in
  let ammo =
    if g.ammo > 0 || g.kind.id = Spas then float_of_int g.ammo / float_of_int g.kind.ammo
    else 1. - (float_of_int g.reload_count / float_of_int (max 1 g.kind.reload_time))
  in
  gauge 3 (rgb 220 60 60) "health" (me.health / full_health) (string_of_int (int_of_float (Float.max 0. me.health)))
  @ gauge 2 (if g.ammo > 0 then rgb 230 230 230 else rgb 130 130 130) "ammo" ammo (if g.ammo > 0 || g.kind.id = Spas then string_of_int g.ammo else "reloading")
  @ gauge 1 (rgb 240 200 60) "jets" (float_of_int me.body.jets / float_of_int (max 1 map.jet)) ""
  @ (if me.vest > 0. then gauge 4 (rgb 120 160 220) "vest" (me.vest / default_vest) "" else [])
  @ [ text white 1.6
        (Printf.sprintf "%s    %s %d%s" g.kind.name (if me.body.cluster then "clusters" else "grenades") me.body.grenades
           (match me.bonus with
           | Some (b, ticks) -> Printf.sprintf "    %s %d" (match b with Flame_god -> "flame god" | Predator -> "predator" | Berserker -> "berserker") (ticks /.. 60)
           | None -> ""))
      |> move (screen.left + 150.) (line 0) ]

(* Soldat's menu: the ten weapons by their keys, the one chosen marked *)
let view_menu ?(secondary : Soldat_weapons.id = Socom) (chosen : Soldat_weapons.id) ((x, y) : float * float) : shape list =
  (text white 1.8 ("c  " ^ (Soldat_weapons.get secondary).name) |> move x (y - 250.))
  :: List.mapi
    (fun i id ->
      let w = Soldat_weapons.get id in
      text (if id = chosen then rgb 255 220 80 else white) 1.8 (Printf.sprintf "%d  %s" ((i +.. 1) mod 10) w.name) |> move x (y - (24. * float_of_int i)))
    Soldat_weapons.primaries

(* the scores, the best first, at the top right; the time left and the
 * points to reach, at the top; with teams, each team's points beside
 * it, and what just happened to a flag under it *)
let view_scores (computer : computer) (p : play) : shape list =
  let screen = computer.screen in
  let ranked = List.stable_sort (fun (a : soldier) (b : soldier) -> compare b.kills a.kills) (Array.to_list p.soldiers) in
  let seconds = p.time_left /.. 60 in
  let teams =
    if p.mode = Deathmatch || p.mode = Rambomatch then []
    else
      let colour t = let (r, g, b) = team_shirt t in rgb r g b in
      [ text (colour 1) 3. (Printf.sprintf "Alpha %d" (score p 1)) |> move (-170.) (screen.top - 70.);
        text (colour 2) 3. (Printf.sprintf "%d Bravo" (score p 2)) |> move 170. (screen.top - 70.) ]
  in
  let news = match p.news with Some (words, ticks) -> [ text white 2.5 words |> move_y (screen.top - 110.) |> fade (Float.min 1. (float_of_int ticks / 40.)) ] | None -> [] in
  teams @ news
  @ (text white 2. (Printf.sprintf "%d:%02d    first to %d" (seconds /.. 60) (seconds mod 60) (limit p)) |> move_y (screen.top - 30.))
  :: List.mapi
       (fun i (s : soldier) ->
         (* its shirt's colour, half way to white: a dark blue is not read on the sky *)
         let (r, g, b) = s.shirt in
         let light c = (c +.. 255) /.. 2 in
         text (rgb (light r) (light g) (light b)) 1.8 (Printf.sprintf "%-12s %2d" (if p.mode = Rambomatch && rambo s then s.name ^ " *" else s.name) s.kills) |> move (screen.right - 110.) (screen.top - 30. - (24. * float_of_int i)))
       ranked

(* through the camera, in Soldat's order: what is behind, the bullets,
 * the soldiers, then the map's polygons over them; over it all and
 * not moving with the map, the score *)
let view_play ?(me = 0) (computer : computer) ~(graphics : int) ~(primary : Soldat_weapons.id) (p : play) : shape list =
  let top = computer.screen.top in
  let (x, y) = at p.camera in
  let soldiers = Array.to_list p.soldiers in
  let (back, front) = scene computer ~graphics p.map p.camera in
  Camera2d.view
    { x; y; zoom = zoom computer.screen; angle = 0. }
    (back
    @ List.concat_map (view_bullet ~graphics) p.bullets
    @ List.concat_map (view_thing ~graphics) p.things
    @ List.concat_map (view_soldier computer ~graphics) soldiers
    @ Soldat_sparks_view.view p.sparks
    @ front
    @ (if List.mem_assoc "waypoints" computer.flags then view_waypoints p.map else [])
    @ if List.mem_assoc "hitboxes" computer.flags then List.concat_map view_tested soldiers else [])
  :: view_scores computer p
  @ view_interface computer p.map p.soldiers.(me)
  @ (if p.soldiers.(me).dead <> None then (text white 3. "respawning..." |> move_y (top - 150.)) :: view_menu primary (0., top - 200.) else [])

let view (computer : computer) (model : model) : shape list =
  let graphics = model.graphics in
  (* the way of drawing just chosen, said for a moment *)
  let said = if model.graphics_shown > 0 then [ text white 2. ("graphics " ^ graphics_name graphics) |> move_y (computer.screen.bottom + 40.) ] else [] in
  (match model.scenes.scene with
  | Loading name -> [ rectangle (rgb 40 60 80) computer.screen.width computer.screen.height; text white 3. ("loading " ^ name ^ "...") ]
  | Title map ->
      (* the sparks' pictures asked for meanwhile: a round's first
       * explosion will not wait for them *)
      ignore (Soldat_sparks_view.warm ());
      [ view_map computer ~graphics map;
        text white 6. "MINI SOLDAT" |> move_y 300.;
        text white 2. "a/d run   w jump   s crouch   x lie down   r reload   q other weapon   e grenade   f throw it away" |> move_y 220.;
        text white 2. "mouse aim   left button shoot   right button (or shift) jets" |> move_y 185.;
        text white 2.
          (match Option.value model.mode ~default:(mode_of map) with
          | Deathmatch -> Printf.sprintf "a deathmatch: you against %d of Soldat's bots, first to %d kills" model.bots kill_limit
          | Team_match -> Printf.sprintf "a team match: you and Alpha against Bravo, %d bots, first team to %d kills" model.bots team_limit
          | Capture_the_flag -> Printf.sprintf "capture the flag: you and Alpha against Bravo, %d bots, first team to %d flags" model.bots capture_limit
          | Rambomatch -> Printf.sprintf "a Rambomatch: empty hands (f) take the bow; Rambo's kills count, first to %d" rambo_limit)
        |> move_y 150.;
        text white 2. (map.name ^ "      g: the graphics   m: the next map") |> move_y 110. ]
      @ view_menu ~secondary:model.secondary model.primary (0., 50.)
      @ Scene2d.blink 1. model.scenes [ text white 3. "PRESS SPACE" |> move_y (-230.) ]
  | Playing p -> view_play computer ~graphics ~primary:model.primary p
  | Lobby { rooms; chosen; here } ->
      let screen = computer.screen in
      [ rectangle (rgb 40 60 80) screen.width screen.height;
        text white 5. "MINI SOLDAT" |> move_y 320.;
        text white 2. "the server's rooms: a round each, bots in the seats nobody has" |> move_y 250. ]
      @ List.mapi
          (fun i (room, players) ->
            let line = Printf.sprintf "%s %-16s %s" (if i = chosen then ">" else " ") room (match players with 0 -> "nobody yet" | 1 -> "1 player" | n -> Printf.sprintf "%d players" n) in
            text (if i = chosen then rgb 255 220 80 else white) 2.5 line |> move_y (180. - (40. * float_of_int i)))
          rooms
      @ [ text white 1.8 ("here: " ^ String.concat " " here) |> move_y (-120.);
          text white 1.8 "up, down: choose   enter: play there   t: say a line   in a game, escape: back here" |> move_y (-160.) ]
      @ List.mapi (fun i line -> text white 1.6 line |> move 0. (screen.bottom + 150. - (22. * float_of_int i))) model.lines
      @ (match model.typing with Some line -> [ text (rgb 255 220 80) 1.8 ("say: " ^ line ^ "_") |> move 0. (screen.bottom + 20.) ] | None -> [])
  | Connecting why -> [ rectangle (rgb 40 60 80) computer.screen.width computer.screen.height; text white 3. why ]
  | Online (p, me) ->
      (* a server's round: the same picture, and what is said in the room *)
      let screen = computer.screen in
      view_play ~me computer ~graphics ~primary:model.primary p
      @ List.mapi (fun i line -> text white 1.6 line |> move 0. (screen.bottom + 150. - (22. * float_of_int i))) model.lines
      @ (match model.typing with Some line -> [ text (rgb 255 220 80) 1.8 ("say: " ^ line ^ "_") |> move 0. (screen.bottom + 20.) ] | None -> [])
  | Over (name, map) ->
      [ view_map computer ~graphics map; text white 5. (if name = "YOU" then "YOU WIN!" else name ^ " WINS") |> move_y 200. ]
      @ Scene2d.blink 1. model.scenes [ text white 3. "PRESS SPACE" |> move_y (-50.) ])
  @ said
