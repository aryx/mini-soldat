(* Soldat_lockstep: the network's twin: two players, no server.

   Soldat_online plays on a server: the server alone computes the
   round and sends it, some 4 KB thirty times a second, and each
   player's program guesses and corrects (Soldat_room, Prediction,
   Interpolation). This is the same game as elm-playground's netcode
   library would have one share it first (docs/twins.md), the oldest
   way (Doom, 1993): **nobody sends the round**. A round is a function
   of its players' keys (Soldat_update.tick: nothing in it is random
   that is not its seed's), so each of the two programs plays the
   whole round itself, bots and all, from the same start, and they
   send each other *only their keys*: 10 bytes a tick.

       host (soldier 0)                      the other (soldier 1)
       my keys of tick 9  ----------------->
                          <-----------------  its keys of tick 9
       both have both: each plays tick 9, and gets the same round

   The library does the waiting (Lockstep):

     Lockstep.step lock mine   every player's keys for the next tick,
                               if they have all come; mine, read now,
                               are for 3 ticks later (the input delay:
                               they have that long to arrive)
     Lockstep.packet           what to send the other, each frame: my
                               keys not yet acknowledged
     Lockstep.receive          the other's packet
     Lockstep.checksum, desync the round's checksum each second, sent
                               along: if the two rounds ever differ,
                               it is seen and said

   What it costs, against the server's way: one's own keys are felt 3
   ticks late (50 ms), always, and when the other's keys are late the
   game waits for them: the slower connection sets both players' pace.
   What it gives: no server to run, and a few bytes where the other way
   sends kilobytes.

   **Or guess** (Rollback, the flag rollback): waiting 3 ticks for
   one's own keys is what a fighting game cannot have. The other way
   plays my keys at once and *guesses* the other's (it still holds
   what it held); when its real keys come and the guess was wrong,
   the round goes back to the tick of the guess and plays again from
   there, in one frame. Going back is free here: a round is a value,
   and to go back to one is to have kept it (Rollback.create is given
   the tick as a function, and keeps the rounds itself).

     Rollback.step r mine      my keys, played now; the replay, if a
                               guess was wrong
     Rollback.model r          the round to show, maybe on guesses

   Its price is not delay but the other's soldier seen to jump when a
   guess was wrong, and ticks played twice.

   Both programs must be started alike (the same map, mode, bots and
   flags): the round's start is not sent either. Its camera, its sparks
   and its sounds are each program's own, and no part of the checksum.

   Flags: net=host (wait for the other; port=7777, bind=127.0.0.1) and
   net=join (host=127.0.0.1, port=7777), as elm-playground's
   Multiplayer has them. Natively the two talk over UDP.

   Not here: more than two players, a player coming late, a browser
   against a native program (their floats may differ in a last digit,
   and a lockstep game does not forgive it).

   In Soldat: nothing; its network is a server's.
*)
open Playground

(* a peer's game: soldier [me] (0 the host, 1 the other) of a round *)
type t

(* the round both start from: [play] with its second soldier a
 * player's too, not a bot's *)
val start : ?rollback:bool -> me:int -> Soldat_model.play -> t

(* a frame: the other's packets since the last, my keys and where my
 * cursor is; the game after (a tick later, or waiting for the other's
 * keys), and the packet to send *)
val frame : t -> incoming:string list -> Soldat_model.intent -> look:float * float -> t * string

val play : t -> Soldat_model.play

(* the tick at which the two rounds were seen to differ, if they were *)
val desync : t -> int option

(* how many frames it waited for the other's keys *)
val stalls : t -> int

(* with rollback: how many guesses were wrong, and the ticks played again *)
val rollbacks : t -> int * int

(* this program as a peer: the connection asked for (made at the first
 * frame), the round started when the title's space is pressed *)
val connect : ?rollback:bool -> < Cap.network ; .. > -> Transport.role -> unit

(* a frame: Soldat_update.update until the round starts, then the
 * peer's; nothing of it without [connect] *)
val update : computer -> Soldat_model.model -> Soldat_model.model
