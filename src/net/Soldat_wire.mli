(* Soldat_wire: the game as bytes, for the network.

   Soldat_protocol has the messages a player's program and the server
   exchange; two of them carry the game itself, as bytes this module
   writes and reads: a player's keys up (an [Input]'s), the round down
   (a [World]'s).

   **A player's keys** are 10 bytes: two of bits, one a key (left,
   right, jump, crouch, the jets, lie down, the trigger, reload, the
   other weapon, a grenade, throw the weapon away), and where the
   cursor is in the map, two numbers of 4 bytes.

       keys: left and the trigger; the cursor at (100.5, -20)
       00 41   42 c9 00 00   c1 a0 00 00

   **The round** is what a player's program needs to show it and to
   go on from it: its mode, its points, its time; each soldier whole
   (its particle, its two animations, its skeleton, its weapons and
   their counters: all a tick of it reads, so that the program can
   play its own soldier on from there, Soldat_online), its health, its
   body if dead; the bullets; the things; and what happened since the
   last one that is to be heard and seen (Soldat_event), of which the
   program makes its own sparks and sounds. Not the map (it has it),
   not the bots' minds (they are the server's), not the sparks.

   A number that is not whole travels as the 4 bytes of a single
   (IEEE 754, the high ones first): a place to a hundred-thousandth of
   a unit. Six soldiers, twenty bullets and five things are about
   4,200 bytes: thirty a second, 125 KB, the round sent whole each
   time (only what changed would be far less: not done).

   What does not parse is refused whole, as all of Wire's: a server's
   bytes are a stranger's too.

   In Soldat: the messages of shared/network/Net.pas
   (TMsg_ServerSpriteSnapshot, TMsg_BulletSnapshot,
   TMsg_ServerThingSnapshot...), one a kind of thing and only what
   changed, where this sends the round whole.
*)

(* a player's keys and cursor *)
val encode_control : Soldat_soldier.control -> string
val decode_control : string -> (Soldat_soldier.control, string) result

(* a soldier's body, whole: what Soldat_soldier.tick reads and writes *)
val encode_body : Soldat_soldier.t -> string
val decode_body : string -> (Soldat_soldier.t, string) result

(* a round, and what happened since the last sent ([events], each with
 * the soldier it is of). Read back on a map, it has no bots' minds, no
 * sparks and its camera at (0, 0): the reader's own *)
val encode_world : Soldat_model.play -> (int * Soldat_event.t) list -> string
val decode_world : Soldat_map.t -> string -> (Soldat_model.play, string) result
