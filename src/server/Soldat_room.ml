(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_room.mli *)
open Soldat_model

type seat = {
  (* the player that has it, or none: its bot does *)
  nick : string option;
  character : character;
  (* its keys not played yet, the oldest first, each with its number *)
  queue : (int * Soldat_soldier.control) list;
  acked : int;
  last : Soldat_soldier.control;
}

type t = {
  name : string;
  play : play;
  seats : seat array;
  (* what happened since the last round sent *)
  pending : (int * Soldat_event.t) list;
  (* the rounds played here: the next one's seed *)
  rounds : int;
}

let name (t : t) : string = t.name
let play (t : t) : play = t.play
let players (t : t) : int = Array.fold_left (fun n (s : seat) -> if s.nick <> None then n + 1 else n) 0 t.seats

(* soldier [i] its bot's: its name, its mind *)
let to_bot (p : play) (i : int) (c : character) : play =
  let s = p.soldiers.(i) in
  let soldiers = Array.copy p.soldiers and minds = Array.copy p.minds and cast = Array.copy p.cast in
  soldiers.(i) <- { s with name = c.bot; human = false; trousers = c.bot_trousers; skin = c.bot_skin; body = { s.body with human = false } };
  (* a new mind, of the bots the server has (Soldat_parts) *)
  minds.(i) <- (match Soldat_parts.pick Soldat_parts.bots ~twin:false with Some part -> part.fresh c | None -> Soldat_state.Nobody);
  cast.(i) <- Some c;
  { p with soldiers; minds; cast }

(* soldier [i] a player's *)
let to_player (p : play) (i : int) (nick : string) : play =
  let s = p.soldiers.(i) in
  let soldiers = Array.copy p.soldiers and minds = Array.copy p.minds and cast = Array.copy p.cast in
  soldiers.(i) <- { s with name = nick; human = true; body = { s.body with human = true } };
  minds.(i) <- Soldat_state.Nobody;
  cast.(i) <- None;
  { p with soldiers; minds; cast }

(* a round for these seats: the first soldier, which Soldat_update makes
 * the player's, is its bot's until somebody takes it *)
let round ?mode ?bonuses (map : Soldat_map.t) (seats : seat array) (seed : int) : play =
  let cast = Array.to_list (Array.map (fun (s : seat) -> s.character) seats) in
  let p = Soldat_update.start ~bots:(List.tl cast) ~seed ?mode ?bonuses map in
  let p = to_bot p 0 (List.hd cast) in
  (* a team's soldier keeps its team's shirt; in a deathmatch, its own *)
  let p = if team p.soldiers.(0) = 0 then (
    let c = List.hd cast in
    let (r, g, b) = c.bot_shirt in
    let soldiers = Array.copy p.soldiers in
    soldiers.(0) <- { (soldiers.(0)) with shirt = c.bot_shirt; color = Playground.rgb r g b };
    { p with soldiers })
  else p in
  (* and those that players have are theirs again *)
  Array.to_list seats |> List.mapi (fun i s -> (i, s)) |> List.fold_left (fun p (i, (s : seat)) -> match s.nick with Some nick -> to_player p i nick | None -> p) p

let create ?(seats = 6) ?(seed = 1) ?mode ?bonuses ~(name : string) (map : Soldat_map.t) : t =
  let seats =
    Array.of_list (List.map (fun character -> { nick = None; character; queue = []; acked = -1; last = Soldat_soldier.no_control }) (Soldat_cast.cast (max 1 seats) seed))
  in
  { name; play = round ?mode ?bonuses map seats seed; seats; pending = []; rounds = 1 }

let join (nick : string) (t : t) : (t * int) option =
  let rec free i = if i >= Array.length t.seats then None else if t.seats.(i).nick = None then Some i else free (i + 1) in
  Option.map
    (fun i ->
      let seats = Array.copy t.seats in
      let me = t.play.soldiers.(i).body in
      (* until its first keys come: looking where its soldier looks *)
      seats.(i) <- { (seats.(i)) with nick = Some nick; queue = []; acked = -1; last = { Soldat_soldier.no_control with aim = (me.aim_x, me.aim_y) } };
      ({ t with seats; play = to_player t.play i nick }, i))
    (free 0)

let leave (i : int) (t : t) : t =
  if i < 0 || i >= Array.length t.seats || t.seats.(i).nick = None then t
  else begin
    let seats = Array.copy t.seats in
    seats.(i) <- { (seats.(i)) with nick = None; queue = [] };
    { t with seats; play = to_bot t.play i seats.(i).character }
  end

let input (i : int) ~(seq : int) (c : Soldat_soldier.control) (t : t) : t =
  if i < 0 || i >= Array.length t.seats || t.seats.(i).nick = None then t
  else begin
    let seats = Array.copy t.seats in
    let queue = seats.(i).queue @ [ (seq, c) ] in
    (* a program faster than the server: its last two only *)
    let queue = if List.length queue > 8 then List.filteri (fun k _ -> k >= List.length queue - 2) queue else queue in
    seats.(i) <- { (seats.(i)) with queue };
    { t with seats }
  end

let weapon ?secondary (i : int) (primary : Soldat_weapons.id option) (t : t) : t =
  if i < 0 || i >= Array.length t.seats || t.seats.(i).nick = None then t
  else begin
    let soldiers = Array.copy t.play.soldiers in
    let s = soldiers.(i) in
    soldiers.(i) <- { s with primary = Option.value primary ~default:s.primary; secondary = Option.value secondary ~default:s.secondary };
    { t with play = { t.play with soldiers } }
  end

let acked (t : t) (i : int) : int = if i >= 0 && i < Array.length t.seats then t.seats.(i).acked else -1

let tick (t : t) : t =
  (* each seat's keys for this tick: its oldest not played, or its last again *)
  let seats = Array.map (fun (s : seat) -> match s.queue with (seq, c) :: rest -> { s with queue = rest; acked = seq; last = c } | [] -> s) t.seats in
  let p = Soldat_update.tick ~controls:(fun i -> seats.(i).last) t.play still ~look:(0., 0.) in
  let pending = t.pending @ p.events in
  match Soldat_update.winner p with
  | None -> { t with seats; play = p; pending }
  | Some who ->
      (* the round is over: another, on the same map, said to all *)
      let next = round ~mode:p.mode ~bonuses:p.bonuses p.map seats (t.rounds + 1) in
      { t with seats; play = { next with news = Some (who ^ " wins the round", 300) }; pending = []; rounds = t.rounds + 1 }

let snapshot (t : t) : t * string = ({ t with pending = [] }, Soldat_wire.encode_world t.play t.pending)
