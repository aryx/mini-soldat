(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_bodies.mli *)

let grey = Playground.rgb 128 128 128
let degrees (radians : float) : float = radians *. 180. /. Float.pi

(* a thing's points as a box: its middle, its angle (of its first edge),
 * its width along that edge and its height *)
let box (points : (float * float) array) : (float * float) * float * float * float =
  let n = float_of_int (Array.length points) in
  let middle = Array.fold_left (fun (x, y) (px, py) -> (x +. (px /. n), y +. (py /. n))) (0., 0.) points in
  let (ax, ay) = points.(0) and (bx, by) = points.(1) in
  let width = Float.hypot (bx -. ax) (by -. ay) in
  (* a weapon is 4 thick: thinner, the engine's solver throws a box
   * that lands on its end out of the map (Soldat_bodies.mli) *)
  let height = if Array.length points < 4 then 4. else let (cx, cy) = points.(2) in Float.hypot (cx -. bx) (cy -. by) in
  (middle, Float.atan2 (by -. ay) (bx -. ax), width, height)

(* a wall as a body nothing moves: its triangle about its middle, y
 * turned over *)
let wall (w : Soldat_map.wall) : Physics.body =
  let corners = [ w.a; w.b; w.c ] in
  let (mx, my) = List.fold_left (fun (x, y) (px, py) -> (x +. (px /. 3.), y +. (py /. 3.))) (0., 0.) corners in
  let local = List.map (fun (x, y) -> (x -. mx, my -. y)) corners in
  (* its corners counterclockwise, as the engine's polygons are: a
   * map's go either way, and turning y over turns them the other *)
  let area = match local with [ (ax, ay); (bx, by); (cx, cy) ] -> ((bx -. ax) *. (cy -. ay)) -. ((by -. ay) *. (cx -. ax)) | _ -> 1. in
  Physics.body (Playground.polygon grey (if area < 0. then List.rev local else local)) |> Physics.at mx (-.my) |> Physics.immovable

let move (map : Soldat_map.t) (thing : Soldat_things.t) : Soldat_things.t =
  match thing.kind with
  | Flag _ -> thing
  | _ ->
      let now = Array.map (fun (p : Particles.particle) -> p.pos) thing.points and was = Array.map (fun (p : Particles.particle) -> p.old) thing.points in
      let ((x, y), angle, width, height) = box now and ((ox, oy), old_angle, _, _) = box was in
      (* the body: where the points are, going as they went since the
       * last tick (a speed is a second's: times 60) *)
      let turned = Float.atan2 (sin (angle -. old_angle)) (cos (angle -. old_angle)) in
      let body =
        Physics.body (Playground.rectangle grey width height)
        |> Physics.at x (-.y) |> Physics.pointing (-.degrees angle)
        |> Physics.moving ((x -. ox) *. 60.) ((oy -. y) *. 60.)
        |> Physics.turn (-.degrees turned *. 60.) |> Physics.rough 0.6
      in
      (* the walls around it that hold a thing *)
      let walls = List.filter (fun (w : Soldat_map.wall) -> Soldat_things.holds w.kind) (Soldat_map.sector map x y) in
      let gravity = Soldat_soldier.grav *. 3600. in
      let moved = List.hd (Physics.simulate ~gravity (Physics.world (body :: List.map wall walls))).bodies in
      (* its points, at the body's corners, in their order: along its
       * first edge from where the first one was *)
      (* the corners of a box at a place and an angle (the Playground's:
       * y upwards, degrees), in the map's coordinates *)
      let (w2, h2) = (width /. 2., height /. 2.) in
      (* which side of its first edge its third point is on: kept *)
      let flip =
        Array.length now >= 4
        && (let (ax, ay) = now.(0) and (bx, by) = now.(1) and (cx, cy) = now.(2) in
            ((bx -. ax) *. (cy -. by)) -. ((by -. ay) *. (cx -. bx)) < 0.)
      in
      let shape = if Array.length now < 4 then [| (-.w2, 0.); (w2, 0.) |] else [| (-.w2, -.h2); (w2, -.h2); (w2, h2); (-.w2, h2) |] in
      let shape = if flip then Array.map (fun (dx, dy) -> (dx, -.dy)) shape else shape in
      let corners (bx : float) (by : float) (degrees : float) : (float * float) array =
        let a = -.degrees *. Float.pi /. 180. in
        Array.map (fun (dx, dy) -> (bx +. (dx *. cos a) -. (dy *. sin a), -.by +. (dx *. sin a) +. (dy *. cos a))) shape
      in
      (* its points at the body's corners; where each was a tick ago is
       * where the body's speed and spin say, not where the point was:
       * what the solver moved a body out of a wall by is no speed *)
      let at = corners moved.x moved.y moved.angle in
      let before = corners (moved.x -. (moved.vx /. 60.)) (moved.y -. (moved.vy /. 60.)) (moved.angle -. (moved.spin /. 60.)) in
      let points = Array.mapi (fun i (p : Particles.particle) -> { p with pos = at.(i); old = before.(i) }) thing.points in
      (* at rest: it hardly moves, and something holds it (falling
       * free, a tick's gravity would have added to its speed) *)
      let held = moved.vy > body.vy -. (gravity /. 120.) in
      let still = held && Physics.speed moved < 12. && Float.abs moved.spin < 20. in
      { thing with points; still }
