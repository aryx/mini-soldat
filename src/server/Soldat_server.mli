(* Soldat_server: the lobby (Soldat_lobby.mli) on the network.

   Players connect with WebSocket, from a browser or a native program;
   each binary message is one of Soldat_protocol's, handed to the
   lobby, whose answers are sent to whom they are for. The connections
   are elm-playground's Server: one event loop, non-blocking sockets,
   no thread, a slow player never holding the others up.

   Safe by default: it listens on 127.0.0.1, this computer only,
   unless given another address; bytes that are not a message close the
   connection that sent them.

   The port is Soldat's, 23073 (its net_port), though Soldat's is UDP's
   and this one TCP's: a browser has no UDP to give a page.
*)

type t

(* a server listening on [bind]:[port] (127.0.0.1:23073; 0: a free
 * port), and the port it got; [capacity] is Soldat_lobby.create's. A
 * room's game has [seats] soldiers (6), on the map [map_of] gives for
 * the room's map's name (Arena2, whatever the name, if none is given).
 * A room named "MAP.MODE" plays that mode (Soldat_protocol.room_mode);
 * [bonuses]: how often bonus kits appear in the rounds, 1 to 5 (0:
 * never) *)
val listen :
  < Cap.network ; .. > -> ?bind:string -> ?port:int -> ?capacity:int -> ?seats:int -> ?bonuses:int -> ?map_of:(string -> Soldat_map.t) -> unit -> t * int

(* everything that can be done without waiting: what arrived answered *)
val step : t -> unit

(* sleep until a player has something, or [timeout] seconds *)
val wait : t -> float -> unit

(* a tick of every room's game: to be called 60 times a second. A game
 * nobody plays any more is dropped; every other tick each player is
 * sent its room's round *)
val tick : t -> unit

(* the lobby now, and a room's game *)
val lobby : t -> Soldat_lobby.t
val game : t -> string -> Soldat_room.t option
