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

type t = { lock : Lockstep.t; me : int; play : play }

(* keys read at a tick are played 3 ticks later: the time they have to
 * reach the other *)
let delay = 3

let start ~(me : int) (p : play) : t =
  let soldiers = Array.copy p.soldiers and brains = Array.copy p.brains in
  (* the two players' soldiers, named the same in both programs *)
  soldiers.(0) <- { (soldiers.(0)) with name = "PLAYER 1" };
  if Array.length soldiers > 1 then begin
    let s = soldiers.(1) in
    soldiers.(1) <- { s with name = "PLAYER 2"; human = true; body = { s.body with human = true } };
    brains.(1) <- None
  end;
  { lock = Lockstep.create ~me ~players:2 ~delay; me; play = { p with soldiers; brains } }

let play (t : t) : play = t.play
let desync (t : t) : int option = Option.map fst (Lockstep.desync t.lock)
let stalls (t : t) : int = (Lockstep.stats t.lock).stalls

(* what of a round the two must agree on: its soldiers' bodies, healths
 * and kills (not the camera, each program's own) *)
let checksum (p : play) : int32 =
  Checksum.fnv1a (String.concat "" (Array.to_list (Array.map (fun (s : soldier) -> Soldat_wire.encode_body s.body ^ Printf.sprintf "%.3f %d" s.health s.kills) p.soldiers)))

let frame (t : t) ~(incoming : string list) (mine : intent) ~(look : float * float) : t * string =
  List.iter (Lockstep.receive t.lock) incoming;
  let t =
    match Lockstep.step t.lock (Soldat_wire.encode_control mine) with
    | None -> t (* the other's keys have not come: wait *)
    | Some keys ->
        (* each player's keys of this tick; none yet in the first ticks *)
        let controls i = if i < Array.length keys then Result.value (Soldat_wire.decode_control keys.(i)) ~default:still else still in
        let play = Soldat_update.tick ~controls ~me:t.me t.play still ~look in
        if play.frame mod 60 = 0 then Lockstep.checksum t.lock ~tick:(Lockstep.tick t.lock - 1) (checksum play);
        { t with play }
  in
  (t, Lockstep.packet t.lock)

(*****************************************************************************)
(* This program as a peer *)
(*****************************************************************************)

type session = { transport : Transport.t; me : int; mutable game : t option }

let session : session option ref = ref None

(* asked for, and made at the first frame: a platform says how to
 * connect only once it has started *)
let wanted : (unit -> (session, string) result) option ref = ref None

let connect (caps : < Cap.network ; .. >) (role : Transport.role) : unit =
  let me = match role with Host _ -> 0 | _ -> 1 in
  wanted := Some (fun () -> Result.map (fun transport -> { transport; me; game = None }) (Transport.connect caps role))

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
          s.game <- Some (start ~me:s.me p);
          { model with scenes = { model.scenes with scene = Online (p, s.me) }; said = Some (s.transport.status (), 240) }
      | _ -> model)
  | (None, _) -> Soldat_update.update computer model
