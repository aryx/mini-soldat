(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_online.mli *)
open Playground
open Soldat_model (* its types, used all along *)

(* a seat in a room's game: what this program keeps of it *)
type game = {
  seat : int;
  map_name : string;
  mutable map : Soldat_map.t option;
  (* the number of the next keys sent *)
  mutable seq : int;
  (* its own soldier's body and the round's tick, played ahead *)
  mutable ahead : (Soldat_soldier.t * int) Prediction.t option;
  (* the server's rounds, for the others' places between two of them *)
  rounds : play Interpolation.t;
  mutable latest : play option;
  (* the weapon last asked for: none yet *)
  mutable asked : (Soldat_weapons.id * Soldat_weapons.id) option;
  mutable frames : int;
  mutable camera : float * float;
  mutable sparks : Soldat_sparks.t list;
  mutable spark_seed : Lehmer.t;
  (* what the last rounds gave to hear, not played yet *)
  mutable heard : (Soldat_sfx.t * (float * float)) list;
}

type session = {
  transport : Transport.t;
  nick : string;
  (* the room to enter once welcomed (the flag room=); the lobby: none *)
  room : string;
  mutable game : game option;
  mutable status : string;
  mutable welcomed : bool;
  (* the room it is in, and with whom *)
  mutable current : string;
  mutable here : string list;
  (* a room asked for, its seat not given yet *)
  mutable entering : string option;
  (* the lobby's screen: the server's rooms, the cursor, frames since it came *)
  mutable rooms : (string * int) list;
  mutable chosen : int;
  (* the mode a room entered will be asked with: none (the map's own),
   * or one of Soldat_model.mode_words, by its place there from 1 *)
  mutable mode : int;
  mutable waited : int;
}

let session : session option ref = ref None

(* times the server's word moved its own soldier more than a unit from
 * where it had guessed it *)
let corrected = ref 0
let corrections () : int = !corrected

(* maps given by hand, by their names: before the content's *)
let known : (string, Soldat_map.t) Hashtbl.t = Hashtbl.create 4
let know (name : string) (map : Soldat_map.t) : unit = Hashtbl.replace known name map

let reset () : unit =
  session := None;
  corrected := 0

(* the rounds come 30 a second: two of them behind *)
let delay = 2. /. 30.

let send (s : session) (message : Soldat_protocol.to_server) : unit = s.transport.send (Soldat_protocol.encode_to_server message)

let connected (transport : Transport.t) ~(nick : string) ~(room : string) : unit =
  let s =
    { transport; nick; room; game = None; status = "saying hello to the server..."; welcomed = false; current = Soldat_protocol.lobby; here = [];
      entering = None; rooms = []; chosen = 0; mode = 0; waited = 0 }
  in
  send s (Hello nick);
  session := Some s

(* a server to connect to at the first frame: a platform installs how
 * to (Transport.set_connect) when it starts, not before *)
let wanted : (unit -> (unit, string) result) option ref = ref None

let connect (caps : < Cap.network ; .. >) ~(host : string) ~(port : int) ~(nick : string) ~(room : string) : unit =
  wanted := Some (fun () -> Result.map (fun transport -> connected transport ~nick ~room) (Transport.connect caps (Relay { host; port })))

(*****************************************************************************)
(* Its own soldier, ahead *)
(*****************************************************************************)

(* a tick of its own soldier alone, by its keys: what Prediction plays,
 * and plays again *)
let ahead_of (map : Soldat_map.t) (seat : int) (players : int) (body : Soldat_soldier.t) (tick : int) : (Soldat_soldier.t * int) Prediction.t =
  let update (inputs : string array) ((body, tick) : Soldat_soldier.t * int) : Soldat_soldier.t * int =
    match Soldat_wire.decode_control inputs.(seat) with
    | Ok keys -> (Soldat_soldier.tick map ~ticks:(tick + 1) ~random:(fun () -> 0.5) body keys, tick + 1)
    | Error _ -> (body, tick + 1)
  in
  Prediction.create ~me:seat ~players ~update (body, tick)

(*****************************************************************************)
(* The others, between two rounds *)
(*****************************************************************************)

let lerp (f : float) ((ax, ay) : float * float) ((bx, by) : float * float) : float * float = (ax +. ((bx -. ax) *. f), ay +. ((by -. ay) *. f))

(* a soldier between what it was in a round and in the next: its
 * skeleton's points, alive in both; its body's, dead in both; else as
 * it is in the second *)
let between (f : float) (a : soldier) (b : soldier) : soldier =
  match (a.dead, b.dead) with
  | (None, None) when Array.length a.body.skeleton = Array.length b.body.skeleton ->
      let (x, y) = lerp f (a.body.x, a.body.y) (b.body.x, b.body.y) in
      { b with body = { b.body with x; y; skeleton = Array.mapi (fun i p -> lerp f a.body.skeleton.(i) p) b.body.skeleton } }
  | (Some (_, ra), Some (ticks, rb)) when Array.length ra.points = Array.length rb.points ->
      let points = Array.mapi (fun i (p : Particles.particle) -> { p with pos = lerp f ra.points.(i).pos p.pos }) rb.points in
      { b with dead = Some (ticks, { rb with points }) }
  | _ -> b

(*****************************************************************************)
(* The room's talk *)
(*****************************************************************************)

let said (model : model) (line : string) : model =
  let lines = model.lines @ [ line ] in
  { model with lines = List.filteri (fun i _ -> i >= List.length lines - 6) lines }

(* a line typed: t starts one, a key that goes down adds its letter,
 * enter says it, escape forgets it *)
let typed (s : session) (computer : computer) (scenes : scene Scene2d.t) (model : model) : model =
  let down name = Scene2d.pressed (fun k -> Set_.mem name k.keys) scenes in
  match model.typing with
  | None -> if down "t" then { model with typing = Some "" } else model
  | Some line ->
      if Scene2d.pressed (fun k -> k.kenter) scenes then begin
        if Soldat_protocol.valid_text line then send s (Say line);
        { model with typing = None }
      end
      else if down "Escape" then { model with typing = None }
      else if Scene2d.pressed (fun k -> k.kbackspace) scenes then { model with typing = Some (String.sub line 0 (max 0 (String.length line - 1))) }
      else if Scene2d.pressed (fun k -> k.kspace) scenes then { model with typing = Some (line ^ " ") }
      else
        (* the keys of one character that just went down *)
        let letters = List.filter (fun name -> String.length name = 1 && down name) (Set_.elements computer.keyboard.keys) in
        { model with typing = Some (String.concat "" (line :: letters)) }

(*****************************************************************************)
(* A frame *)
(*****************************************************************************)

(* a room's map, by its name: the content's file, when it has come; the
 * one the program carries, if there is none *)
let map_of (name : string) : Soldat_map.t option =
  match Hashtbl.find_opt known name with
  | Some map -> Some map
  | None ->
  match Soldat_assets.bytes ("maps/" ^ name ^ ".pms") with
  | Loading -> None
  | Missing -> Some (Lazy.force Soldat_map.arena2)
  | Here bytes -> ( match Pms.parse bytes with Ok pms -> Some (Soldat_map.of_pms pms) | Error _ -> Some (Lazy.force Soldat_map.arena2))

(* a room asked for *)
let enter (s : session) (room : string) : unit =
  s.entering <- Some room;
  s.status <- "entering " ^ room ^ "...";
  send s (Join room)

(* what the lobby's screen offers: a room for each of the game's maps,
 * there or not yet (a room is made by entering it), then the others
 * the server has; each with how many players are in it *)
let offered (s : session) : (string * int) list =
  let players room = Option.value (List.assoc_opt room s.rooms) ~default:0 in
  List.map (fun map -> (map, players map)) maps
  @ List.filter (fun (room, _) -> room <> Soldat_protocol.lobby && not (List.mem room maps)) s.rooms

(* a server's message *)
let received (s : session) (model : model) (message : Soldat_protocol.to_client) : model =
  match message with
  | Welcome nick ->
      s.welcomed <- true;
      if s.room <> Soldat_protocol.lobby then enter s s.room;
      said model ("you are " ^ nick)
  | Refused why ->
      (* a room entered whose game has no soldier left: back to the lobby *)
      if s.current <> Soldat_protocol.lobby && s.game = None then send s Leave;
      s.entering <- None;
      if not s.welcomed then s.status <- "refused: " ^ why;
      said model ("refused: " ^ why)
  | Rooms rooms ->
      s.rooms <- rooms;
      model
  | Entered (room, nicks) ->
      s.current <- room;
      s.here <- nicks;
      if room = Soldat_protocol.lobby then begin
        s.game <- None;
        s.entering <- None;
        s.waited <- 0
      end;
      said model (Printf.sprintf "in %s: %s" room (String.concat " " nicks))
  | Came nick ->
      s.here <- s.here @ [ nick ];
      said model (nick ^ " came")
  | Went nick ->
      s.here <- List.filter (( <> ) nick) s.here;
      said model (nick ^ " went")
  | Said (nick, text) -> said model (nick ^ ": " ^ text)
  | Seat { seat; map } ->
      s.status <- "loading " ^ map ^ "...";
      s.entering <- None;
      s.game <-
        Some
          { seat; map_name = map; map = None; seq = 0; ahead = None; rounds = Interpolation.create ~delay; latest = None; asked = None; frames = 0; camera = (0., 0.);
            sparks = []; spark_seed = Lehmer.scramble (seat + 7); heard = [] };
      model
  | World { acked; world } -> (
      match s.game with
      | Some ({ map = Some map; _ } as g) -> (
          match Soldat_wire.decode_world map world with
          | Error _ -> model
          | Ok round when g.seat >= Array.length round.soldiers -> model
          | Ok round ->
              let mine = round.soldiers.(g.seat) in
              (* its own soldier: where the server says, and its keys since played again *)
              (match g.ahead with
              | None ->
                  g.ahead <- Some (ahead_of map g.seat (Array.length round.soldiers) mine.body round.frame);
                  g.camera <- (mine.body.x, mine.body.y)
              | Some ahead ->
                  let (guessed, _) = Prediction.model ahead in
                  Prediction.correct ahead ~world:(mine.body, round.frame) ~acked ~latest:(Array.make (Array.length round.soldiers) "");
                  let (now, _) = Prediction.model ahead in
                  if mine.dead = None && Float.hypot (now.x -. guessed.x) (now.y -. guessed.y) > 1. then incr corrected);
              Interpolation.add g.rounds ~time:(float_of_int g.frames /. 60.) round;
              g.latest <- Some round;
              (* what happened since the last: its sparks, made here, and its sounds *)
              let random () =
                g.spark_seed <- Lehmer.next g.spark_seed;
                Lehmer.to_unit g.spark_seed
              in
              List.iter
                (fun (owner, event) ->
                  let (sparks, sounds) = Soldat_sparks.of_event map ~random ~owner event in
                  g.sparks <- g.sparks @ sparks;
                  g.heard <- g.heard @ sounds)
                round.events;
              model)
      | _ -> model)

(* the round to show: the server's last, the others between two of its
 * rounds, this program's own soldier where its keys have taken it *)
let shown (g : game) (round : play) : play =
  let now = float_of_int g.frames /. 60. in
  let soldiers =
    match Interpolation.sample g.rounds ~now with
    | Some (a, b, f) when Array.length a.soldiers = Array.length round.soldiers && Array.length b.soldiers = Array.length round.soldiers ->
        Array.mapi (fun i _ -> between f a.soldiers.(i) b.soldiers.(i)) round.soldiers
    | _ -> Array.copy round.soldiers
  in
  let mine = round.soldiers.(g.seat) in
  soldiers.(g.seat) <- (match (mine.dead, g.ahead) with (None, Some ahead) -> { mine with body = fst (Prediction.model ahead) } | _ -> mine);
  { round with soldiers; sparks = g.sparks; camera = g.camera }

let update (computer : computer) (model : model) : model =
  (* the first frame: the connection asked for, made now *)
  let refused =
    match !wanted with
    | Some dial ->
        wanted := None;
        (match dial () with Ok () -> None | Error why -> Some why)
    | None -> None
  in
  match (!session, refused) with
  | (None, Some why) -> { model with scenes = Scene2d.go (Connecting ("no server: " ^ why)) model.scenes }
  | (None, None) -> (
      (* a server that could not be had: said, and nothing more *)
      match model.scenes.scene with Connecting _ -> model | _ -> Soldat_update.update computer model)
  | (Some s, _) ->
      let (model, scenes) = Soldat_update.common computer model in
      (* what the server said since the last frame *)
      let model =
        List.fold_left
          (fun model bytes -> match Soldat_protocol.decode_to_client bytes with Ok message -> received s model message | Error _ -> model)
          model (s.transport.receive ())
      in
      let typing = model.typing <> None in
      let model = typed s computer scenes model in
      let key name = (not typing) && Scene2d.pressed (fun k -> Set_.mem name k.keys) scenes in
      (* escape, in a game: back to the lobby *)
      if s.game <> None && key "Escape" then send s Leave;
      let scene =
        match s.game with
        | None when s.welcomed && s.entering = None && s.current = Soldat_protocol.lobby ->
            (* the lobby's screen: its rooms asked for each second, the
             * arrows (or w and s) to choose one, enter to enter it *)
            if s.waited = 0 then Soldat_sound.jets ~listener:(0., 0.) ~soldiers:32 [] (* a game left: its jets heard no more *);
            if s.waited mod 60 = 0 then send s List;
            s.waited <- s.waited + 1;
            let rooms = offered s in
            let n = List.length rooms in
            let up = (not typing) && Scene2d.pressed (fun k -> k.kup || k.kw) scenes and down = (not typing) && Scene2d.pressed (fun k -> k.kdown || k.ks) scenes in
            s.chosen <- (s.chosen + (if down then 1 else 0) + (if up then n - 1 else 0)) mod n;
            (* left and right: the mode to ask a new room with *)
            let words = "" :: List.map fst mode_words in
            let left = (not typing) && Scene2d.pressed (fun k -> k.kleft || k.ka) scenes and right = (not typing) && Scene2d.pressed (fun k -> k.kright || k.kd) scenes in
            s.mode <- (s.mode + (if right then 1 else 0) + (if left then List.length words - 1 else 0)) mod List.length words;
            let word = List.nth words s.mode in
            let room = fst (List.nth rooms s.chosen) in
            (* a room that is there has its mode; a map's name with a mode makes one *)
            let asked = if word = "" || not (List.mem room maps) then room else room ^ "." ^ word in
            if (not typing) && Scene2d.pressed (fun k -> k.kenter) scenes then enter s asked;
            Lobby { rooms; chosen = s.chosen; here = s.here; mode = word }
        | None -> Connecting (s.status ^ "  (" ^ s.transport.status () ^ ")")
        | Some g -> (
            if g.map = None then g.map <- map_of g.map_name;
            match (g.map, g.latest) with
            | (Some map, Some round) ->
                g.frames <- g.frames + 1;
                let before = shown g round in
                (* its keys: none while a line is typed *)
                let keys = Soldat_update.human computer before in
                let keys = if model.typing <> None then { Soldat_soldier.no_control with aim = keys.aim } else keys in
                let bytes = Soldat_wire.encode_control keys in
                send s (Input (g.seq, bytes));
                (* the weapon to come back with (the keys 1 to 9, 0): said when it changes *)
                if g.asked <> Some (model.primary, model.secondary) then begin
                  g.asked <- Some (model.primary, model.secondary);
                  List.iteri (fun i id -> if id = model.primary then send s (Weapon ((i + 1) mod 10))) Soldat_weapons.primaries;
                  List.iteri (fun i id -> if id = model.secondary then send s (Secondary i)) Soldat_weapons.secondaries
                end;
                Option.iter (fun ahead -> Prediction.step ahead ~seq:g.seq bytes) g.ahead;
                g.seq <- g.seq + 1;
                (* the sparks' own tick, and what was heard *)
                let random () =
                  g.spark_seed <- Lehmer.next g.spark_seed;
                  Lehmer.to_unit g.spark_seed
                in
                let (sparks, clinks) = Soldat_sparks.tick map ~random g.sparks in
                g.sparks <- Soldat_sparks.capped sparks;
                let p = shown g round in
                let me = p.soldiers.(g.seat) in
                let listener = Soldat_bullets.place me in
                Soldat_sound.play ~listener ~frame:g.frames (g.heard @ clinks);
                g.heard <- [];
                Soldat_sound.jets ~listener ~soldiers:(Array.length p.soldiers)
                  (List.filter_map (fun (i, (o : soldier)) -> if o.dead = None && o.body.jetting then Some (i, (o.body.x, o.body.y)) else None) (List.mapi (fun i o -> (i, o)) (Array.to_list p.soldiers)));
                (* the camera: its own, as alone *)
                let z = zoom computer.screen in
                let (cx, cy) = Soldat_update.follow p me (computer.mouse.mx /. z, -.computer.mouse.my /. z) in
                let (wx, wy) = Soldat_sparks.wobble ~random g.sparks in
                g.camera <- (cx +. wx, cy +. wy);
                Online ({ p with camera = g.camera }, g.seat)
            | (None, _) -> Connecting ("loading " ^ g.map_name ^ "...")
            | (Some _, None) -> Connecting "waiting for the server's first word...")
      in
      { model with scenes = { scenes with scene } }
