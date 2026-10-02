(* Soldat_lobby: who is connected and in which room, and what each is
   told when one of them speaks, moves or goes.

   A value, no socket in it: a message comes in from a connection (a
   number), and out come the lobby after it and the messages to send,
   each with the connection it is for. So the rule is tested by calling
   it (tests/server), and the sockets are someone else's business
   (Soldat_server.mli).

     clients:  1 -> pad, in ctf_Ash        rooms:  lobby   -> mm
               2 -> mm,  in lobby                  ctf_Ash -> pad zak
               3 -> zak, in ctf_Ash

   Everyone named is in exactly one room: the lobby when it comes in
   (Hello), another once it asks (Join), the lobby again when it leaves
   that one (Leave). A room comes into being when the first player
   enters it, and goes away with the last; the lobby is always there. A
   line said goes to everyone in the speaker's room, the speaker too:
   a player's program shows what the server says was said, never what
   it sent.

   What is refused, with a Refused to whoever asked and nothing
   changed: anything before a Hello, a second Hello, a name that is not
   one (Soldat_protocol.valid_name), a nick someone has (whatever the
   case of its letters), a room that is full, a line that is not one.

   This is IRC's model (Jarkko Oikarinen, 1988; RFC 1459), nicks and
   channels, cut down to what a game's lobby needs: one channel at a
   time, and no operators. A room is to become a game: its map, its
   mode, its score, the server stepping it and sending each player the
   world.

   In Soldat: a server is one game of at most 32 players
   (MAX_PLAYERS), with its chat (MsgID_ChatMessage); server/Server.pas
   keeps who is connected.
*)

type t

(* an empty lobby, whose rooms (but the lobby itself) hold [capacity]
 * players at most (32) *)
val create : ?capacity:int -> unit -> t

(* [receive id message lobby]: connection [id] sent [message] *)
val receive : int -> Soldat_protocol.to_server -> t -> t * (int * Soldat_protocol.to_client) list

(* a connection's nick and the room it is in, once it has said Hello *)
val who : int -> t -> (string * string) option

(* connection [id] went away (nothing, if it had no nick) *)
val left : int -> t -> t * (int * Soldat_protocol.to_client) list

(* the rooms with someone in, by name, each with its nicks in the order
 * they connected; the lobby even when empty *)
val rooms : t -> (string * string list) list
