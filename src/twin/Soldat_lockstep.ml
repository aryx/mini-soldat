(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_lockstep.mli *)
open Playground
open Soldat_model

(* the two ways to share the keys: wait for the other's (Lockstep), or
 * guess them and play again when the guess was wrong (Rollback) *)
type engine = Lock of Lockstep.t | Roll of play Rollback.t

(* [look]: where this program's cursor is, for its camera: read by the
 * tick, whichever frame plays it *)
type t = { engine : engine; me : int; play : play; look : (float * float) ref }

(* keys read at a tick are played 3 ticks later: the time they have to
 * reach the other *)
let delay = 3

(* Limit 3: what of a round the two must agree on, and no more: its
 * soldiers' bodies, healths and kills. Not the whole round: its camera
 * is each program's own, and would differ at the first tick *)
let checksum (p : play) : int32 =
  Checksum.fnv1a (String.concat "" (Array.to_list (Array.map (fun (s : soldier) -> Soldat_wire.encode_body s.body ^ Printf.sprintf "%.3f %d" s.health s.kills) p.soldiers)))

(* a tick, by each player's keys (none yet in the first ticks) *)
let tick ~(me : int) ~(look : (float * float) ref) (keys : string array) (p : play) : play =
  let controls i = if i < Array.length keys then Result.value (Soldat_wire.decode_control keys.(i)) ~default:still else still in
  Soldat_update.tick ~controls ~me p still ~look:!look

let start ?(rollback = false) ~(me : int) (p : play) : t =
  let soldiers = Array.copy p.soldiers and minds = Array.copy p.minds and cast = Array.copy p.cast in
  (* the two players' soldiers, named the same in both programs *)
  soldiers.(0) <- { (soldiers.(0)) with name = "PLAYER 1" };
  if Array.length soldiers > 1 then begin
    let s = soldiers.(1) in
    soldiers.(1) <- { s with name = "PLAYER 2"; human = true; body = { s.body with human = true } };
    minds.(1) <- Soldat_state.Nobody;
    cast.(1) <- None
  end;
  let play = { p with soldiers; minds; cast } and look = ref (0., 0.) in
  let engine =
    if not rollback then Lock (Lockstep.create ~me ~players:2 ~delay)
    else begin
      (* a round is a value: to go back to one is to have kept it. A
       * tick whose keys are all known is final: its checksum is sent *)
      let it = ref None in
      let on_confirm n (p : play) = if n mod 60 = 0 then Option.iter (fun r -> Rollback.checksum r ~tick:n (checksum p)) !it in
      let r = Rollback.create ~me ~players:2 ~update:(tick ~me ~look) ~on_confirm play in
      it := Some r;
      Roll r
    end
  in
  { engine; me; play; look }

let play (t : t) : play = t.play
let desync (t : t) : int option = Option.map fst (match t.engine with Lock l -> Lockstep.desync l | Roll r -> Rollback.desync r)
let stalls (t : t) : int = match t.engine with Lock l -> (Lockstep.stats l).stalls | Roll r -> (Rollback.stats r).stalls
let rollbacks (t : t) : int * int = match t.engine with Lock _ -> (0, 0) | Roll r -> ((Rollback.stats r).rollbacks, (Rollback.stats r).replayed)

let frame (t : t) ~(incoming : string list) (mine : intent) ~(look : float * float) : t * string =
  t.look := look;
  let keys = Soldat_wire.encode_control mine in
  match t.engine with
  | Lock lock ->
      List.iter (Lockstep.receive lock) incoming;
      let t =
        match Lockstep.step lock keys with
        | None -> t (* the other's keys have not come: wait *)
        | Some all ->
            let play = tick ~me:t.me ~look:t.look all t.play in
            if play.frame mod 60 = 0 then Lockstep.checksum lock ~tick:(Lockstep.tick lock - 1) (checksum play);
            { t with play }
      in
      (t, Lockstep.packet lock)
  | Roll r ->
      (* my keys played at once, the other's guessed; what came says
       * if a guess was wrong, and the ticks since are played again *)
      List.iter (Rollback.receive r) incoming;
      Rollback.step r keys;
      ({ t with play = Rollback.model r }, Rollback.packet r)

(*****************************************************************************)
(* This program as a peer *)
(*****************************************************************************)

type session = { transport : Transport.t; me : int; rollback : bool; mutable game : t option }

let session : session option ref = ref None

(* Limit 1 (Soldat_lockstep.mli): asked for here, and made at the first
 * frame: a platform says how to connect only once it has started, and
 * Transport.connect before that answers that there is no network *)
let wanted : (unit -> (session, string) result) option ref = ref None

let connect ?(rollback = false) (caps : < Cap.network ; .. >) (role : Transport.role) : unit =
  let me = match role with Host _ -> 0 | _ -> 1 in
  wanted := Some (fun () -> Result.map (fun transport -> { transport; me; rollback; game = None }) (Transport.connect caps role))

let update (computer : computer) (model : model) : model =
  (match !wanted with
  | Some dial ->
      wanted := None;
      (match dial () with Ok s -> session := Some s | Error why -> prerr_endline ("lockstep: " ^ why))
  | None -> ());
  match (!session, model.scenes.scene) with
  | (Some ({ game = Some game; _ } as s), Online _) ->
      let (model, scenes) = Soldat_update.common computer model in
      let z = zoom computer.screen in
      let (game, packet) =
        frame game ~incoming:(s.transport.receive ()) (Soldat_update.human computer game.play) ~look:(computer.mouse.mx /. z, -.computer.mouse.my /. z)
      in
      s.transport.send packet;
      s.game <- Some game;
      let p = game.play in
      Soldat_sound.play ~listener:(Soldat_bullets.place p.soldiers.(s.me)) ~frame:p.frame p.sounds;
      let model = match desync game with Some tick -> { model with said = Some (Printf.sprintf "the two rounds differ since tick %d" tick, 60) } | None -> model in
      { model with scenes = { scenes with scene = Online (p, s.me) } }
  | (Some s, _) -> (
      (* the title, as alone; the round it starts is the peer's *)
      let model = Soldat_update.update computer model in
      match model.scenes.scene with
      | Playing p ->
          s.game <- Some (start ~rollback:s.rollback ~me:s.me p);
          { model with scenes = { model.scenes with scene = Online (p, s.me) }; said = Some (s.transport.status (), 240) }
      | _ -> model)
  | (None, _) -> Soldat_update.update computer model
