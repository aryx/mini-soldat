(* Soldat_room: a room's game, as the server plays it.

   A room other than the lobby is a round (Soldat_update's, the very
   one a player plays alone), which the server steps 60 times a second
   whether anybody presses a key or not. It has a fixed number of
   *seats*, its soldiers, six by default, each driven by one of
   Soldat's bots until a player takes it:

       seat   0        1        2       3       4      5
              Admiral  pad      Blain   mm      Dutch  Danko
              (a bot)  (a player's keys)  ...

   Who enters the room is given the first seat a bot has; the soldier
   keeps its place, its health and its kills, changes its name, and is
   from then on moved by that player's keys. Who leaves gives it back
   to its bot. So a game is never empty, never waits, and nobody's
   number changes when somebody comes or goes (a bullet remembers who
   fired it by that number).

   **A player's keys** come numbered, 60 a second, and not evenly: two
   in a tick, then none. Each seat has a queue of them: a tick plays
   the oldest, or the last one played again when the queue is empty
   (the key is probably still held). The number of the last one played
   goes back with each round sent ([acked]): the player's program
   needs it to know from where to play its own guesses again
   (elm-playground's Prediction, in Soldat_online). A queue more than
   8 long is a program faster than the server: it is cut to its last
   two.

   **What is sent** is the round and what happened in it since the
   last one sent ([snapshot]), the same bytes to everyone in the room.

   It is a value: [tick] is a function, and the tests call it without
   a socket.

   This is elm-playground's Snapshot.Server (numbered inputs, one
   played a tick, the last repeated), with seats that change hands,
   which that one does not have: a game there has its players for
   good.

   In Soldat: server/ServerLoop.pas (AppOnIdle), and the player's side
   of a snapshot in shared/network/NetworkServerSprite.pas.
*)

type t

(* a room for a map, named as the players ask for it; [seats] soldiers
 * (6), all bots' at first *)
val create : ?seats:int -> ?seed:int -> name:string -> Soldat_map.t -> t

val name : t -> string
val play : t -> Soldat_model.play

(* how many seats players have *)
val players : t -> int

(* a player takes the first seat a bot has: the room, and the seat; None
 * when players have them all *)
val join : string -> t -> (t * int) option

(* a seat given back to its bot *)
val leave : int -> t -> t

(* a player's keys, numbered, for its seat; of a seat no player has,
 * dropped *)
val input : int -> seq:int -> Soldat_soldier.control -> t -> t

(* the number of the last keys played for a seat; none yet: -1 *)
val acked : t -> int -> int

(* a tick of the round, each seat's keys its player's or its bot's. A
 * round that is over starts again, its players in their seats *)
val tick : t -> t

(* the round as bytes (Soldat_wire.encode_world), with what happened
 * since the last time this was asked *)
val snapshot : t -> t * string
