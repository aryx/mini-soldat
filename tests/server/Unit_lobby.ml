(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_lobby.mli *)

(* a message as text, with whom it is for: "2<Came pad" *)
let show ((id, m) : int * Soldat_protocol.to_client) : string =
  Printf.sprintf "%d<%s" id
    (match m with
    | Welcome nick -> "Welcome " ^ nick
    | Refused _ -> "Refused"
    | Rooms rooms -> "Rooms " ^ String.concat "," (List.map (fun (room, n) -> Printf.sprintf "%s=%d" room n) rooms)
    | Entered (room, nicks) -> Printf.sprintf "Entered %s [%s]" room (String.concat "," nicks)
    | Came nick -> "Came " ^ nick
    | Went nick -> "Went " ^ nick
    | Said (nick, text) -> Printf.sprintf "Said %s: %s" nick text
    | Seat { seat; map } -> Printf.sprintf "Seat %d %s" seat map
    | World { acked; _ } -> Printf.sprintf "World %d" acked)

(* connection [id] sends [message]: what goes out is checked, and the
 * lobby after it kept *)
let step (lobby : Soldat_lobby.t ref) (name : string) (id : int) (message : Soldat_protocol.to_server) (expected : string list) : unit =
  let (after, out) = Soldat_lobby.receive id message !lobby in
  lobby := after;
  Alcotest.(check (list string)) name expected (List.map show out)

let rooms (lobby : Soldat_lobby.t ref) : string list =
  List.map (fun (room, nicks) -> Printf.sprintf "%s: %s" room (String.concat " " nicks)) (Soldat_lobby.rooms !lobby)

(* pad (1), mm (2) and zak (3), all named, in the lobby *)
let three () : Soldat_lobby.t ref =
  let lobby = ref (Soldat_lobby.create ~capacity:2 ()) in
  List.iter (fun (id, nick) -> lobby := fst (Soldat_lobby.receive id (Hello nick) !lobby)) [ (1, "pad"); (2, "mm"); (3, "zak") ];
  lobby

let tests =
  Testo.categorize "Lobby"
    [
      Testo.create "an evening" (fun () ->
          let lobby = ref (Soldat_lobby.create ()) in
          Alcotest.(check (list string)) "empty" [ "lobby: " ] (rooms lobby);
          step lobby "the first one in" 1 (Hello "pad") [ "1<Welcome pad"; "1<Entered lobby [pad]" ];
          step lobby "the second, announced" 2 (Hello "mm") [ "2<Welcome mm"; "2<Entered lobby [pad,mm]"; "1<Came mm" ];
          step lobby "a line, to both" 1 (Say "hi") [ "1<Said pad: hi"; "2<Said pad: hi" ];
          step lobby "a room made" 1 (Join "ctf_Ash") [ "2<Went pad"; "1<Entered ctf_Ash [pad]" ];
          step lobby "a line in it, to nobody else" 1 (Say "anyone?") [ "1<Said pad: anyone?" ];
          step lobby "the rooms" 2 List [ "2<Rooms ctf_Ash=1,lobby=1" ];
          step lobby "joined there" 2 (Join "ctf_Ash") [ "1<Came mm"; "2<Entered ctf_Ash [pad,mm]" ];
          Alcotest.(check (list string)) "the lobby empty, still there" [ "ctf_Ash: pad mm"; "lobby: " ] (rooms lobby);
          step lobby "back to the lobby" 1 Leave [ "2<Went pad"; "1<Entered lobby [pad]" ];
          let (after, out) = Soldat_lobby.left 2 !lobby in
          lobby := after;
          Alcotest.(check (list string)) "the last one out of a room: nobody to tell" [] (List.map show out);
          Alcotest.(check (list string)) "and the room is gone" [ "lobby: pad" ] (rooms lobby);
          step lobby "its nick free again" 4 (Hello "mm") [ "4<Welcome mm"; "4<Entered lobby [pad,mm]"; "1<Came mm" ];
          let (after, out) = Soldat_lobby.left 4 !lobby in
          Alcotest.(check (list string)) "gone, the other told" [ "1<Went mm" ] (List.map show out);
          Alcotest.(check (list string)) "a connection never named goes silently" [] (List.map show (snd (Soldat_lobby.left 9 after))));
      Testo.create "what is refused" (fun () ->
          let lobby = three () in
          let before = rooms lobby in
          let refused name id message = step lobby name id message [ Printf.sprintf "%d<Refused" id ] in
          refused "anything before a Hello" 7 (Say "hi");
          refused "a List before a Hello" 7 List;
          refused "a second Hello" 1 (Hello "pad2");
          refused "a nick taken" 7 (Hello "pad");
          refused "whatever its case" 7 (Hello "PAD");
          refused "a nick with a space" 7 (Hello "p ad");
          refused "an empty nick" 7 (Hello "");
          refused "a room that is not a name" 1 (Join "the room");
          refused "the room one is in" 1 (Join "lobby");
          refused "leaving the lobby" 1 Leave;
          refused "an empty line" 1 (Say "");
          refused "a line with a bell in it" 1 (Say "a\x07b");
          Alcotest.(check (list string)) "nothing changed" before (rooms lobby));
      Testo.create "a full room" (fun () ->
          let lobby = three () in
          step lobby "one" 1 (Join "dm") [ "2<Went pad"; "3<Went pad"; "1<Entered dm [pad]" ];
          step lobby "two" 2 (Join "dm") [ "3<Went mm"; "1<Came mm"; "2<Entered dm [pad,mm]" ];
          step lobby "a third, refused" 3 (Join "dm") [ "3<Refused" ];
          Alcotest.(check (list string)) "left where it was" [ "dm: pad mm"; "lobby: zak" ] (rooms lobby);
          step lobby "the lobby is never full" 1 Leave [ "2<Went pad"; "3<Came pad"; "1<Entered lobby [pad,zak]" ]);
    ]
