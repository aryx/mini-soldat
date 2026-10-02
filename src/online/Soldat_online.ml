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
  mutable frames : int;
  mutable camera : float * float;
  mutable sparks : Soldat_sparks.t list;
  mutable spark_seed : Lehmer.t;
  (* what the last rounds gave to hear, not played yet *)
  mutable heard : (Soldat_sfx.t * (float * float)) list;
}

type session = { transport : Transport.t; nick : string; room : string; mutable game : game option; mutable status : string }

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
  let s = { transport; nick; room; game = None; status = "saying hello to the server..." } in
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

(* a server's message *)
let received (s : session) (model : model) (message : Soldat_protocol.to_client) : model =
  match message with
  | Welcome nick ->
      s.status <- "entering " ^ s.room ^ "...";
      if s.room <> Soldat_protocol.lobby then send s (Join s.room);
      said model ("you are " ^ nick)
  | Refused why -> said model ("refused: " ^ why)
  | Rooms rooms -> said model (String.concat "  " (List.map (fun (room, n) -> Printf.sprintf "%s (%d)" room n) rooms))
  | Entered (room, nicks) -> said model (Printf.sprintf "in %s: %s" room (String.concat " " nicks))
  | Came nick -> said model (nick ^ " came")
  | Went nick -> said model (nick ^ " went")
  | Said (nick, text) -> said model (nick ^ ": " ^ text)
  | Seat { seat; map } ->
      s.status <- "loading " ^ map ^ "...";
      s.game <-
        Some
          { seat; map_name = map; map = None; seq = 0; ahead = None; rounds = Interpolation.create ~delay; latest = None; frames = 0; camera = (0., 0.);
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
      let model = typed s computer scenes model in
      let scene =
        match s.game with
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
                Online { p with camera = g.camera }
            | (None, _) -> Connecting ("loading " ^ g.map_name ^ "...")
            | (Some _, None) -> Connecting "waiting for the server's first word...")
      in
      { model with scenes = { scenes with scene } }
