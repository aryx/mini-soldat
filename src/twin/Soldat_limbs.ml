(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_limbs.mli *)

(* a limb: the points at its two ends (numbered from 1, as Soldat's; an
 * end at several is at their middle), those it carries, how thick it
 * is, and the limb it hangs from with the point they meet at (the
 * torso: none) *)
type limb = { from : int list; to_ : int list; carries : int list; thick : float; parent : (int * int) option }

let limbs : limb array =
  let limb ?parent ?(thick = 3.) from to_ carries = { from; to_; carries; thick; parent } in
  [| limb ~thick:6. [ 5; 6 ] [ 10; 11 ] [ 5; 6; 7; 8; 9; 10; 11 ]; (* the torso *)
     limb ~parent:(0, 9) ~thick:5. [ 9 ] [ 12 ] [ 12 ]; (* the head *)
     limb ~parent:(0, 10) [ 10 ] [ 13 ] [ 13 ]; limb ~parent:(2, 13) [ 13 ] [ 16 ] [ 16; 20 ]; (* an arm, its forearm and hand *)
     limb ~parent:(0, 11) [ 11 ] [ 14 ] [ 14 ]; limb ~parent:(4, 14) [ 14 ] [ 15 ] [ 15; 19 ];
     limb ~parent:(0, 5) [ 5 ] [ 4 ] [ 4 ]; limb ~parent:(6, 4) [ 4 ] [ 1 ] [ 1; 17 ]; (* a leg, its shin and foot *)
     limb ~parent:(0, 6) [ 6 ] [ 3 ] [ 3 ]; limb ~parent:(8, 3) [ 3 ] [ 2 ] [ 2; 18 ] |]

let grey = Playground.rgb 128 128 128

(* a limb's place: its middle and its angle (the map's: y downwards, radians) *)
let pose (at : int -> float * float) (l : limb) : float * float * float =
  let middle points = let n = float_of_int (List.length points) in List.fold_left (fun (x, y) p -> let (px, py) = at p in (x +. (px /. n), y +. (py /. n))) (0., 0.) points in
  let (ax, ay) = middle l.from and (bx, by) = middle l.to_ in
  ((ax +. bx) /. 2., (ay +. by) /. 2., Float.atan2 (by -. ay) (bx -. ax))

let tumble (map : Soldat_map.t) (ragdoll : Soldat_ragdoll.t) : Soldat_ragdoll.t =
  let now n = ragdoll.points.(n - 1).pos and was n = ragdoll.points.(n - 1).old in
  let length (l : limb) = let (ax, ay) = now (List.hd l.from) and (bx, by) = now (List.hd l.to_) in Float.max 2. (Float.hypot (bx -. ax) (by -. ay)) in
  (* each limb a body: where its points are, going as they went (the
   * Playground's: y upwards, degrees, a second's speeds) *)
  let degrees a = a *. 180. /. Float.pi in
  let body (l : limb) : Physics.body =
    let (x, y, a) = pose now l and (ox, oy, oa) = pose was l in
    let turned = Float.atan2 (sin (a -. oa)) (cos (a -. oa)) in
    Physics.body (Playground.rectangle grey (length l) l.thick)
    |> Physics.at x (-.y) |> Physics.pointing (-.degrees a) |> Physics.moving ((x -. ox) *. 60.) ((oy -. y) *. 60.)
    |> Physics.turn (-.degrees turned *. 60.) |> Physics.rough 0.5
  in
  let bodies = Array.to_list (Array.map body limbs) in
  let (cx, cy, _) = pose now limbs.(0) in
  let walls = List.filter (fun (w : Soldat_map.wall) -> Soldat_map.stops_soldier w.kind) (Soldat_map.sector map cx cy) in
  (* the joints: a pin where a limb hangs from another. Limit 6
   * (Soldat_limbs.mli): a body's limbs overlap all the time, and must
   * not push each other apart: they are one group (Physics.grouped) *)
  let world = ref (Physics.world (List.map (Physics.grouped 1) bodies @ List.map Soldat_bodies.wall walls)) in
  Array.iteri
    (fun i (l : limb) -> match l.parent with Some (parent, point) -> let (x, y) = now point in world := Physics.pin parent i ~at:(x, -.y) !world | None -> ())
    limbs;
  let moved = Array.of_list (Physics.simulate ~gravity:(Soldat_soldier.grav *. 3600.) ~steps:Soldat_bodies.steps !world).bodies in
  (* the points, each taken where the limb that carries it went, and
   * where the limb's speed and spin say it was a tick ago (limit 2).
   * Limit 7: a pin gives a little, and a limb rebuilt each tick from
   * its points would take that gap for its length. So the torso goes
   * as its body went, and a limb that hangs from another is turned as
   * its body turned, but about the point they meet at, where its
   * parent took that point: no joint drifts apart, no limb grows.
   * The limbs are in that order: a parent before what hangs from it *)
  let points = Array.copy ragdoll.points in
  let radians d = -.d *. Float.pi /. 180. in
  Array.iteri
    (fun i (l : limb) ->
      let (x, y, a) = pose now l and (b : Physics.body) = moved.(i) in
      (* about [pivot], which goes to [pivot']: turned by [turn] *)
      let about (px, py) (px', py') (turn : float) ((qx, qy) : float * float) : float * float =
        let (dx, dy) = (qx -. px, qy -. py) in
        (px' +. (dx *. cos turn) -. (dy *. sin turn), py' +. (dx *. sin turn) +. (dy *. cos turn))
      in
      let (angle, before) = (radians b.angle, radians (b.angle -. (b.spin /. 60.))) in
      let (pivot, at, was) =
        match l.parent with
        | Some (_, joint) -> (now joint, points.(joint - 1).pos, points.(joint - 1).old)
        | None -> ((x, y), (b.x, -.b.y), (b.x -. (b.vx /. 60.), -.(b.y -. (b.vy /. 60.))))
      in
      List.iter
        (fun point ->
          let p = ragdoll.points.(point - 1) in
          points.(point - 1) <- { p with pos = about pivot at (angle -. a) p.pos; old = about pivot was (before -. a) p.pos })
        l.carries)
    limbs;
  { ragdoll with points }
