(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_juice.mli *)

type kind = Blood | Chip | Smoke | Fire
type t = { emitter : kind Emitter.t; trauma : float; time : float }

let none : t = { emitter = Emitter.empty ~cap:400 ~seed:11 (); trauma = 0.; time = 0. }
let dt = 1. /. 60.

(* the recipes: how many, how fast, which way, how long, how big;
 * falling (a negative gravity) or rising *)
let recipe count speed direction spread life size gravity : Emitter.recipe =
  { count; speed; direction; spread; life; size; spin = 0.; gravity; drag = 1.5 }

let blood = recipe 20 (40., 160.) 90. 360. (0.3, 0.8) (1., 2.2) (-500.)
let chips = recipe 6 (30., 110.) 90. 180. (0.2, 0.5) (0.8, 1.6) (-400.)
let puff = recipe 2 (5., 25.) 90. 60. (0.3, 0.7) (2., 4.) 30.
let fire = recipe 40 (60., 320.) 90. 360. (0.2, 0.6) (3., 8.) 0.
let smoke = recipe 12 (20., 80.) 90. 360. (0.6, 1.4) (6., 12.) 60.
let flame = recipe 1 (20., 60.) 270. 30. (0.1, 0.25) (1.5, 3.) 0.

let of_event (j : t) (e : Soldat_event.t) : t =
  (* a place of the map, y downwards, into the emitter's, y upwards *)
  let burst (kind : kind) (r : Emitter.recipe) ((x, y) : float * float) (j : t) : t = { j with emitter = Emitter.burst r ~data:(fun _ -> kind) x (-.y) j.emitter } in
  match e with
  | Blood (at, _) | Flesh (at, _) -> burst Blood blood at j
  | Wall (at, _) | Ricochet (at, _) -> burst Chip chips at j
  | Shot { hand; _ } -> burst Smoke puff hand j
  | Jets { feet = (foot, _); _ } -> burst Fire flame foot j
  | Blast (_, at) -> { (j |> burst Fire fire at |> burst Smoke smoke at) with trauma = Trauma.add 0.6 j.trauma }
  | _ -> j

let step (j : t) : t = { emitter = Emitter.step ~dt j.emitter; trauma = Trauma.decay ~dt j.trauma; time = j.time +. dt }

let dots (j : t) : (float * float * float * kind * float) list =
  List.map (fun (p : kind Emitter.particle) -> (p.x, p.y, p.size, p.data, Float.max 0. (1. -. (p.age /. p.life)))) (Emitter.particles j.emitter)

let shake (j : t) : float * float =
  let o = Trauma.offset ~max_offset:14. ~seed:3 ~trauma:j.trauma j.time in
  (o.dx, o.dy)

(*****************************************************************************)
(* The part *)
(*****************************************************************************)

type Soldat_state.fx += Juice of t

let of_fx (fx : Soldat_state.fx) : t = match fx with Juice j -> j | _ -> none

(* the twin as the game's effects (Soldat_parts): the dots, the shake,
 * and the camera going after its soldier a part of the way each tick
 * (Follow.smooth: 1 - e^(-rate dt) of what is left) *)
let part : Soldat_parts.effects =
  {
    tick = (fun _ ~random:_ events fx -> (Juice (step (List.fold_left (fun j (_, event) -> of_event j event) (match fx with Juice j -> j | _ -> none) events)), []));
    shake = (fun ~random:_ fx -> match fx with Juice j -> shake j | _ -> (0., 0.));
    follow = (fun ~camera:(x, y) (px, py) ~look:(lx, ly) -> (Follow.smooth ~rate:9. ~dt (px +. lx) x, Follow.smooth ~rate:9. ~dt (py +. ly) y));
  }
