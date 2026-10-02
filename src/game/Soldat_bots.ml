(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *
 * Adapted from OpenSoldat's shared/AI.pas, shared/Waypoints.pas and
 * shared/SharedConfig.pas, Copyright 2001-2020 Transhuman Design,
 * Copyright 2020-2023 OpenSoldat contributors (the MIT License).
 *)

(* See Soldat_bots.mli *)
open Soldat_model (* its types, used all along *)

(*****************************************************************************)
(* The characters *)
(*****************************************************************************)

(* the lines "Key=value" of a file *)
let values (text : string) : (string * string) list =
  String.split_on_char '\n' text
  |> List.filter_map (fun line ->
         let line = String.trim line in
         match String.index_opt line '=' with
         | Some i -> Some (String.sub line 0 i, String.trim (String.sub line (i + 1) (String.length line - i - 1)))
         | None -> None)

(* "$00BBGGRR", Delphi's TColor: blue first (ReadConfColor turns it
 * round) *)
let colour (s : string) : (int * int * int) option =
  match int_of_string_opt ("0x" ^ String.sub s 1 (String.length s - 1)) with
  | Some n when String.length s > 1 && s.[0] = '$' -> Some (n land 255, (n lsr 8) land 255, (n lsr 16) land 255)
  | _ -> None
  | exception Invalid_argument _ -> None

(* the skin's is read as it is, red first (ReadConfMagicColor) *)
let turned ((r, g, b) : int * int * int) : int * int * int = (b, g, r)

let character (text : string) : character option =
  let lines = String.split_on_char '\n' text |> List.map String.trim in
  let v = values text in
  let get key = List.assoc_opt key v in
  let number key default = Option.value (Option.bind (get key) int_of_string_opt) ~default in
  let colour_of key default = Option.value (Option.bind (get key) colour) ~default in
  let favourite =
    Option.bind (get "Favourite_Weapon") (fun name -> List.find_opt (fun id -> (Soldat_weapons.get id).name = name) Soldat_weapons.primaries)
  in
  match (List.mem "[BOT]" lines, get "Name", favourite) with
  | (true, Some bot, Some favourite) ->
      Some
        {
          bot;
          bot_shirt = colour_of "Color1" (128, 128, 128);
          bot_trousers = colour_of "Color2" (64, 64, 64);
          bot_skin = turned (colour_of "Skin_Color" (120, 180, 230));
          favourite;
          accuracy = number "Accuracy" 20;
          shoot_dead = number "Shoot_Dead" 0 = 1;
          grenade_freq = number "Grenade_Frequency" 200;
          camper = number "Camping" 0;
        }
  | _ -> None

let characters : character list Lazy.t = lazy (List.filter_map (fun (_, base64) -> character (Base64.decode base64)) Bots_data.all)

let cast (n : int) (round : int) : character list =
  let all = Array.of_list (Lazy.force characters) in
  let count = Array.length all in
  if count = 0 then [] else List.init n (fun i -> all.((((round + i) mod count) + count) mod count))

(* WAYPOINT_TIMEOUT_SMALL *)
let timeout_small = 320
let timeout_big = 480

(* WAYPOINTSEEKRADIUS *)
let seek_radius = 21.

let brain (character : character) : brain =
  {
    character; target = -1; pissed_off = -1; current = 0; next = 0; old = 0; last = 0; waypoint_time = 0; timeout = timeout_small; one_place = 0;
    go_thing = false; fall_save = false; keys = Soldat_soldier.no_control;
  }

(* Random(n): a whole number from 0 to n - 1; 0 for none *)
let whole ~(random : unit -> float) (n : int) : int = if n <= 0 then 0 else min (n - 1) (int_of_float (random () *. float_of_int n))

(* TSprite.Respawn: its favourite, or one of the first nine *)
let weapon (c : character) ~(random : unit -> float) : Soldat_weapons.id =
  if whole ~random 2 = 0 then c.favourite else List.nth Soldat_weapons.primaries (whole ~random 9)

(*****************************************************************************)
(* What it sees *)
(*****************************************************************************)

let distance ((ax, ay) : float * float) ((bx, by) : float * float) : float = Float.hypot (bx -. ax) (by -. ay)

(* Map.RayCast, as the bots use it: how far, if within 651 and nothing
 * of the map is between *)
let sees (map : Soldat_map.t) (a : float * float) (b : float * float) : float option =
  let d = distance a b in
  if d <= 651. && Soldat_map.clear map a b then Some d else None

let bucket (a : float) (b : float) : int =
  let d = Float.abs (a -. b) in
  if d <= 35. then 35 else if d <= 55. then 55 else if d <= 95. then 95 else if d <= 180. then 180 else if d <= 350. then 350 else if d <= 500. then 500 else if d <= 730. then 730 else 731

(* a waypoint by its number, from 1 *)
let waypoint (map : Soldat_map.t) (n : int) : Pms.waypoint option = if n >= 1 && n <= Array.length map.waypoints then Some map.waypoints.(n - 1) else None

(* TWaypoints.FindClosest: the first within a radius, but one *)
let closest (map : Soldat_map.t) ((x, y) : float * float) (radius : float) ~(but : int) : int =
  let n = Array.length map.waypoints in
  let rec from i =
    if i > n then 0
    else
      let w = map.waypoints.(i - 1) in
      if w.active && i <> but && distance (x, y) (float_of_int w.x, float_of_int w.y) < radius then i else from (i + 1)
  in
  from 1

(* ticks a waypoint says to wait there; to camp: for ever *)
let wait (action : int) : int option = match action with 1 -> Some max_int | 2 -> Some 60 | 3 -> Some 300 | 4 -> Some 600 | 5 -> Some 900 | 6 -> Some 1200 | _ -> None

(*****************************************************************************)
(* The keys *)
(*****************************************************************************)

(* a tick's keys, as the Pascal writes them one after the other *)
type keys = {
  mutable left : bool;
  mutable right : bool;
  mutable up : bool;
  mutable down : bool;
  mutable jetpack : bool;
  mutable prone : bool;
  mutable fire : bool;
  mutable reload : bool;
  mutable change : bool;
  mutable grenade : bool;
  mutable aim : float * float;
}

(* FreeControls *)
let free (k : keys) : unit =
  k.left <- false; k.right <- false; k.up <- false; k.down <- false; k.jetpack <- false; k.prone <- false;
  k.fire <- false; k.reload <- false; k.change <- false; k.grenade <- false

let control (p : play) (i : int) (brain : brain) ~(random : unit -> float) : Soldat_soldier.control * brain * int list =
  let map = p.map in
  let me = p.soldiers.(i) in
  let b = me.body in
  let c = brain.character in
  let whole = whole ~random in
  let m = (b.x, b.y) in
  (* the keys start free, but a grenade's while the arm winds up *)
  let k =
    { left = false; right = false; up = false; down = false; jetpack = false; prone = false; fire = false; reload = false; change = false;
      grenade = brain.keys.grenade && b.body.id = Throw; aim = brain.keys.aim }
  in
  let target = ref brain.target and current = ref brain.current and next = ref brain.next and old = ref brain.old in
  let waypoint_time = ref brain.waypoint_time and last = ref brain.last and one_place = ref brain.one_place in
  let go_thing = ref brain.go_thing in
  let action n = match waypoint map n with Some w -> w.action | None -> 0 in
  let head (s : soldier) = Soldat_bullets.point s 12 in
  let look = (fst (head me), snd (head me) -. 2.) in
  (* 1. who it sees: the nearest living one, or one it killed *)
  let seen = ref false and nearest = ref 999999. in
  Array.iteri
    (fun j (o : soldier) ->
      let shootable = match o.dead with None -> true | Some (ticks, _) -> c.shoot_dead && ticks < 180 in
      if j <> i && shootable then begin
        let (hx, hy) = head o in
        let at = if Soldat_map.in_bullet_wall map (hx, hy) then (hx, hy +. 6.) else (hx, hy) in
        match sees map look at with
        | Some d when !nearest > d ->
            target := j;
            (* its own team's is no target, and hides who is behind *)
            seen := not (team me <> 0 && team o = team me);
            if o.dead = None then nearest := d else k.grenade <- false
        | _ -> ()
      end)
    p.soldiers;
  (* who shot it last, if it can see them, before anyone else *)
  let pissed_off = ref (if me.hit_by >= 0 then me.hit_by else brain.pissed_off) in
  if !pissed_off = i then pissed_off := -1;
  if !pissed_off >= 0 && team me <> 0 && team p.soldiers.(!pissed_off) = team me then pissed_off := -1;
  (* with the enemy's flag, and seeing one of them who has not ours: it
   * runs on, along its way home *)
  let holding = List.exists (fun (t : Soldat_things.t) -> t.holder = i) p.things in
  let holds j = List.exists (fun (t : Soldat_things.t) -> t.holder = j) p.things in
  let run_away = !seen && holding && not (holds !target) in
  if run_away then seen := false;
  if !pissed_off >= 0 then
    if sees map look (head p.soldiers.(!pissed_off)) <> None then begin
      target := !pissed_off;
      seen := true
    end
    else pissed_off := -1;
  if not !seen then begin
    (* 2. nobody: along the waypoints (ControlBot) *)
    if (not !go_thing) && Array.length map.waypoints > 0 then begin
      let found = closest map m (if !current = 0 then 350. else seek_radius) ~but:!current in
      old := !current;
      if !next = 0 then next := 1;
      let path = match waypoint map !next with Some w -> w.path | None -> 0 in
      (* capture the flag: its team's way out; with the flag, the other's, which leads home *)
      let path = if p.mode = Capture_the_flag then (if holding then 3 - team me else team me) else path in
      (match waypoint map found with Some w when w.path = path || !current = 0 -> current := found | _ -> ());
      match waypoint map !current with
      | None -> ()
      | Some here ->
          (* a new waypoint: one of its ways on, by chance *)
          if !old <> !current then begin
            match List.nth_opt here.connections (whole (List.length here.connections)) with
            | Some n when n > 0 -> (
                next := n;
                match waypoint map n with Some w -> k.aim <- (float_of_int w.x, float_of_int w.y) | None -> ())
            | _ -> ()
          end;
          (match waypoint map !next with
          | Some w ->
              k.left <- w.left; k.right <- w.right; k.up <- w.up; k.down <- w.down; k.jetpack <- w.jetpack
          | None -> ());
          (* a waypoint to camp or wait at *)
          (match wait here.action with
          | Some ticks when !one_place < ticks ->
              k.left <- false; k.right <- false; k.up <- false; k.down <- false; k.jetpack <- false;
              if c.camper > 0 && !one_place > 180 then k.down <- true
          | _ -> ());
          if !last = !current then incr waypoint_time else waypoint_time := 0;
          last := !current;
          (* stuck? *)
          if here.action = 0 then begin
            if (k.left || k.right) && (not k.down) && distance m (b.old_x, b.old_y) < 3. then incr one_place else one_place := 0;
            if !one_place > 90 then begin
              if k.left && k.right then k.right <- false;
              k.up <- true
            end
          end
          else incr one_place;
          (* running home, at who shoots it *)
          if run_away && !pissed_off >= 0 then begin
            let (ax, ay) = Soldat_bullets.place p.soldiers.(!pissed_off) in
            k.aim <- (Float.round ax, Float.round (ay -. (175. /. b.weapon.kind.speed) -. float_of_int c.accuracy +. float_of_int (whole c.accuracy)));
            k.fire <- true
          end;
          (* back to its own weapon; a clip nearly empty changed *)
          if (b.weapon.kind.id = Socom || b.weapon.kind.id = Hands) && b.secondary.kind.id <> Hands then k.change <- true;
          if b.weapon.ammo < 4 && b.weapon.kind.ammo > 3 then k.reload <- true;
          if whole 150 = 0 && (b.body.id = Prone || b.body.id = Prone_move) then k.prone <- true
    end
  end
  else begin
    (* 3. somebody: SimpleDecision *)
    if !current <> 0 && action !current = 0 then current := 0;
    let them = p.soldiers.(!target) in
    let t = Soldat_bullets.place them in
    let towards () =
      k.right <- false; k.left <- false;
      if fst t > fst m then k.right <- true else if fst t < fst m then k.left <- true
    and away () =
      if not !go_thing then begin
        k.right <- false; k.left <- false;
        if fst t < fst m then k.right <- true else if fst t > fst m then k.left <- true
      end
    and still () = if not !go_thing then begin k.right <- false; k.left <- false end in
    if not !go_thing then towards ();
    let dx = bucket (fst m) (fst t) in
    let empty = b.weapon.ammo = 0 in
    let minigun = b.weapon.kind.id = Minigun in
    (match dx with
    | 35 ->
        away ();
        k.fire <- true
    | 55 ->
        still ();
        k.fire <- true;
        if empty then begin away (); k.fire <- false end
    | 95 ->
        still ();
        k.down <- true;
        k.fire <- true;
        if empty then begin away (); k.down <- false; k.fire <- false end
    | 180 ->
        k.down <- true;
        k.fire <- true;
        if empty then begin away (); k.down <- false; k.fire <- false end
    | 350 ->
        k.fire <- true;
        if c.camper > 127 && not !go_thing then begin k.up <- false; k.down <- true end
    | 500 | 730 ->
        if dx = 500 then k.up <- true;
        if whole (if dx = 500 then 2 else 4) = 0 || minigun then k.fire <- true;
        if c.camper > 0 then begin
          if whole (if dx = 500 then 250 else 300) = 0 && b.body.id <> Prone then k.prone <- true;
          if not !go_thing then begin k.right <- false; k.left <- false; k.up <- false; k.down <- true end
        end
    | _ -> ());
    (* a target that camps is gone to *)
    (match p.brains.(!target) with
    | Some theirs when (not !go_thing) && theirs.current > 0 && action theirs.current <> 0 -> towards ()
    | _ -> ());
    (* above: the jets *)
    let dy = bucket (snd m) (snd t) in
    if (not !go_thing) && dy >= 180 && snd m > snd t then k.jetpack <- true;
    (* a grenade, one tick in so many *)
    if c.grenade_freq > -1 then begin
      let often = c.grenade_freq in
      let often = if empty || b.weapon.fire_count > 125 then often / 2 else often in
      let often = if !current > 0 && action !current <> 0 then often / 2 else often in
      if whole often = 0 && dx < 350 && b.grenades > 0 && ((dy < 55 && snd m > snd t) || snd m < snd t) then k.grenade <- true
    end;
    (* the aim: where it will be in 10 ticks, raised for the fall, and
     * off by its accuracy *)
    let (vx, vy) = if them.dead = None then (them.body.vx, them.body.vy) else (0., 0.) in
    let (tx, ty) = (fst t +. (vx *. 10.), snd t +. (vy *. 10.)) in
    let rise = (if dx < 350 then 0.5 else 1.75) *. float_of_int dx /. b.weapon.kind.speed in
    let off = whole c.accuracy in
    k.aim <- (Float.round tx, Float.round (ty -. rise -. float_of_int c.accuracy +. float_of_int off));
    (* camping where a waypoint says to *)
    if !current > 0 && action !current = 1 then begin
      k.left <- false; k.right <- false; k.up <- false; k.down <- false; k.jetpack <- false
    end;
    waypoint_time := 0
  end;
  (* 4. a kit it wants, seen within 350: it goes (GoToThing) *)
  let look = (fst (head me), snd (head me) -. 4.) in
  let looked = ref [] and see_thing = ref false in
  List.iteri
    (fun n (thing : Soldat_things.t) ->
      let wanted =
        match thing.kind with
        | Medikit -> me.health < full_health && not run_away
        | Grenade_kit -> b.grenades < Soldat_things.max_grenades && not run_away
        | Weapon _ -> false
        | Flag _ -> thing.holder <> i
      in
      if (not !see_thing) && wanted then begin
        let (p1x, _) = thing.points.(0).pos and (p2x, p2y) = thing.points.(1).pos in
        match sees map look (p2x, p2y -. 5.) with
        | Some d when d < 350. ->
            (* a flag: not its own at home (unless it brings the other's
             * to it); not theirs while its own is away; and theirs at
             * home only from near *)
            let mine_home = List.exists (fun (t : Soldat_things.t) -> t.kind = Flag (team me) && t.in_base) p.things in
            let goes =
              match thing.kind with
              | Flag t when t = team me -> if thing.in_base then holding else true
              | Flag _ -> mine_home && not (thing.in_base && d > 95.)
              | _ -> true
            in
            if goes then begin
              see_thing := true;
              if thing.holder < 0 then looked := n :: !looked;
              if thing.interest - (if thing.holder < 0 then 1 else 0) > 0 then begin
                go_thing := true;
                (* the nearer of its two ends *)
                let tx = if (p2x > p1x && fst m > p1x) || (p2x < p1x && fst m <= p2x) then p1x else p2x in
                if tx >= fst m then k.right <- true else k.left <- true;
                (* one of its own carries it home: beside it, it stops
                 * and crouches, and flies when it does *)
                if thing.holder >= 0 && team p.soldiers.(thing.holder) = team me && not thing.in_base then begin
                  if bucket (fst m) tx <= 55 then begin k.right <- false; k.left <- false; k.down <- true end;
                  k.jetpack <- p.soldiers.(thing.holder).body.jetting
                end;
                if bucket (snd m) p2y >= 55 && snd m > p2y then k.jetpack <- true
              end
              else go_thing := false
            end
        | _ -> ()
      end)
    p.things;
  if not !see_thing then go_thing := false;
  (* 5. away from a grenade *)
  List.iter
    (fun (g : bullet) ->
      if g.weapon = Grenade && distance (g.x, g.y) m < Soldat_bullets.frag_radius *. 1.4 then
        if g.x > fst m then begin k.left <- true; k.right <- false end else begin k.right <- true; k.left <- false end)
    p.bullets;
  (* the arm wound up: let go *)
  if b.body.id = Throw && b.body.frame > 35 then k.grenade <- false;
  (* 6. every so often it gives up on where it was going, and jumps *)
  let timeout = ref (brain.timeout - 1) in
  if !timeout < 0 then begin
    current := !old;
    timeout := timeout_small;
    free k;
    k.up <- true
  end;
  if !waypoint_time > timeout_big then begin
    free k;
    current := 0;
    go_thing := false;
    waypoint_time := 0
  end;
  (* falling fast: the jets *)
  let fall_save = if b.vy > 3.35 then true else if b.vy < 1.35 then false else brain.fall_save in
  if fall_save then k.jetpack <- true;
  if whole 190 = 0 then pissed_off := -1;
  let keys : Soldat_soldier.control =
    { left = k.left; right = k.right; up = k.up; down = k.down; jetpack = k.jetpack; prone = k.prone; fire = k.fire; reload = k.reload; change = k.change;
      grenade = k.grenade; drop = false; aim = k.aim }
  in
  ( keys,
    { brain with target = !target; pissed_off = !pissed_off; current = !current; next = !next; old = !old; last = !last; waypoint_time = !waypoint_time;
      timeout = !timeout; one_place = !one_place; go_thing = !go_thing; fall_save; keys },
    !looked )
