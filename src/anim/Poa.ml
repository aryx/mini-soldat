(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Poa.mli *)

type frame = (float * float) array
type skeleton = { points : (float * float) array; sticks : (int * int * float) array }

exception Bad of string

(* the lines, without what a line ends with on any system *)
let lines (text : string) : string list = String.split_on_char '\n' text |> List.map String.trim

(* a number as the files write them: 1.5, -0.01, 2.19840430581986E-11 *)
let number (s : string) : float = match float_of_string_opt s with Some x -> x | None -> raise (Bad ("not a number: " ^ s))

let max_points = 20
let max_frames = 40

let animation (text : string) : (frame array, string) result =
  let blank () = Array.make max_points (0., 0.) in
  (* the frames done, the newest first, and the one being read *)
  let rec read (ls : string list) (frames : frame list) (frame : frame) : frame list =
    match ls with
    | "ENDFILE" :: _ -> frame :: frames
    | "NEXTFRAME" :: rest ->
        if List.length frames + 1 = max_frames then raise (Bad "more than 40 frames");
        read rest (frame :: frames) (blank ())
    | p :: x :: _y :: z :: rest ->
        (match int_of_string_opt p with
        | Some p when p >= 1 && p <= max_points -> frame.(p - 1) <- (-3. *. number x /. 1.1, -3. *. number z)
        | _ -> raise (Bad ("not a point's number: " ^ p)));
        read rest frames frame
    | _ -> raise (Bad "no ENDFILE")
  in
  match read (lines text) [] (blank ()) with
  | frames -> Ok (Array.of_list (List.rev frames))
  | exception Bad why -> Error why

let skeleton ~(scale : float) (text : string) : (skeleton, string) result =
  let rec points (ls : string list) (acc : (float * float) list) : (float * float) list * string list =
    match ls with
    | "CONSTRAINTS" :: rest -> (List.rev acc, rest)
    | _name :: x :: _y :: z :: rest -> points rest ((-.number x *. scale /. 1.2, -.number z *. scale) :: acc)
    | _ -> raise (Bad "no CONSTRAINTS")
  in
  (* "P12": 12 *)
  let named (ps : (float * float) array) (s : string) : int =
    match int_of_string_opt (String.sub s 1 (String.length s - 1)) with
    | Some n when n >= 1 && n <= Array.length ps -> n
    | _ -> raise (Bad ("not a point: " ^ s))
    | exception Invalid_argument _ -> raise (Bad "an empty line among the sticks")
  in
  let rec sticks (ps : (float * float) array) (ls : string list) (acc : (int * int * float) list) : (int * int * float) list =
    match ls with
    | "ENDFILE" :: _ -> List.rev acc
    | a :: b :: rest ->
        let a = named ps a and b = named ps b in
        let (ax, ay) = ps.(a - 1) and (bx, by) = ps.(b - 1) in
        sticks ps rest ((a, b, Float.hypot (ax -. bx) (ay -. by)) :: acc)
    | _ -> raise (Bad "no ENDFILE")
  in
  match
    let (ps, rest) = points (lines text) [] in
    let ps = Array.of_list ps in
    { points = ps; sticks = Array.of_list (sticks ps rest []) }
  with
  | s -> Ok s
  | exception Bad why -> Error why
