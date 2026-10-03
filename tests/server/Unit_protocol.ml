(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Unit_protocol.mli *)

let hex (s : string) : string = String.concat " " (List.map (fun c -> Printf.sprintf "%02x" (Char.code c)) (List.of_seq (String.to_seq s)))

let to_server : Soldat_protocol.to_server list = [ Hello "pad"; Join "ctf_Ash"; Leave; Say "anyone?"; List; Input (300, "keys"); Weapon 0; Weapon 9; Secondary 3 ]

let to_client : Soldat_protocol.to_client list =
  [ Welcome "pad"; Refused "this nick is taken"; Rooms []; Rooms [ ("ctf_Ash", 3); ("lobby", 200) ];
    Entered ("lobby", []); Entered ("ctf_Ash", [ "pad"; "mm" ]); Came "mm"; Went "mm"; Said ("pad", "h\xC3\xA9 !") ]

let tests =
  Testo.categorize "Protocol"
    [
      Testo.create "the worked example" (fun () ->
          Alcotest.(check string) "Hello" "10 03 70 61 64" (hex (Soldat_protocol.encode_to_server (Hello "pad")));
          Alcotest.(check string) "Weapon" "16 08" (hex (Soldat_protocol.encode_to_server (Weapon 8)));
          Alcotest.(check string) "Said" "26 03 70 61 64 02 68 69" (hex (Soldat_protocol.encode_to_client (Said ("pad", "hi"))));
          Alcotest.(check string) "Rooms" "22 01 05 6c 6f 62 62 79 02" (hex (Soldat_protocol.encode_to_client (Rooms [ ("lobby", 2) ]))));
      Testo.create "every message, written and read back" (fun () ->
          List.iter
            (fun m -> Alcotest.(check bool) (hex (Soldat_protocol.encode_to_server m)) true (Soldat_protocol.decode_to_server (Soldat_protocol.encode_to_server m) = Ok m))
            to_server;
          List.iter
            (fun m -> Alcotest.(check bool) (hex (Soldat_protocol.encode_to_client m)) true (Soldat_protocol.decode_to_client (Soldat_protocol.encode_to_client m) = Ok m))
            to_client);
      Testo.create "what is refused" (fun () ->
          let refused name bytes = Alcotest.(check bool) name true (Result.is_error (Soldat_protocol.decode_to_server bytes)) in
          refused "nothing" "";
          refused "an unknown first byte" "\x7f";
          refused "a weapon's key that is none" "\x16\x0a";
          refused "a second weapon that is none" "\x17\x04";
          refused "the relay's welcome" "\x02\x00";
          refused "a server's message" (Soldat_protocol.encode_to_client (Welcome "pad"));
          refused "bytes missing" "\x10\x03pa";
          refused "bytes left over" "\x12\x00";
          refused "a string of 256 bytes" (Soldat_protocol.encode_to_server (Say (String.make 256 'a')));
          Alcotest.(check bool) "a count that lies" true (Result.is_error (Soldat_protocol.decode_to_client "\x22\xff\x7f\x01a\x01"));
          Alcotest.(check bool) "a player's message, to a player" true (Result.is_error (Soldat_protocol.decode_to_client (Soldat_protocol.encode_to_server Leave))));
      Testo.create "a name, a line" (fun () ->
          let name = Soldat_protocol.valid_name and text = Soldat_protocol.valid_text in
          Alcotest.(check (list bool)) "names" [ true; true; false; false; false; false; false ]
            [ name "pad"; name (String.make 24 'a'); name ""; name (String.make 25 'a'); name "a b"; name "a\nb"; name "caf\xC3\xA9" ];
          Alcotest.(check (list bool)) "lines" [ true; true; true; false; false; false ]
            [ text "hello there"; text "h\xC3\xA9"; text (String.make 200 'a'); text ""; text (String.make 201 'a'); text "a\x07b" ]);
    ]
