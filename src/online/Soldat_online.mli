(* Soldat_online: a round played on a server.

   Alone, this program plays the round itself (Soldat_update). Given a
   server (the flag server=HOST), it plays none: the server does
   (Soldat_room), and this is what remains here, each frame:

     its keys up      the keys and the cursor, numbered, one message a
                      frame (Soldat_protocol's Input)
     the round down   30 times a second, the round as the server has
                      it and what happened since (World): shown, and
                      heard, its sparks made here
     its own soldier  moved at once by its keys, without waiting for
                      the server to say so
     the others       drawn where they were a fifteenth of a second
                      ago, between two of the server's rounds

   **Its own soldier, at once** (elm-playground's Prediction). Shown
   only what the server sends, a key would be felt a round trip late.
   A soldier's tick being a function of its body and its keys
   (Soldat_soldier.tick), this program plays its own soldier's itself,
   with the keys it just sent. Then the server's round comes, saying
   "this is the world after your keys number 41": the soldier is put
   where the server says and the keys sent since, 42 to 45, played on
   it again. When nothing else moved it they land where the guess
   was, and nothing shows; when a bullet pushed it, it is corrected,
   30 times a second.

       sent:      39   40   41   42   43   44   45
       server:    "after your 41, you are here"
       replayed:                 42   43   44   45    on what it says

   Only the body is guessed: what its shots hit, its health, its
   death are the server's alone. And the guess is right only once the
   first keys have been answered: until then the server plays its
   ticks without them, the keys on their way are played here on top,
   and a soldier still falling from where it appeared is shown a
   little ahead, then put back (tests/server/Unit_online.ml counts
   it: five times, 100 ms away).

   **The others, a little in the past** (elm-playground's
   Interpolation). Rounds come 30 times a second and frames are drawn
   60: another soldier put at each round as it comes would move every
   other frame, and in jumps when one is late. Each is drawn instead
   where it was two rounds ago (66 ms), between the two rounds around
   that moment: its skeleton's points (or its dead body's) a fraction
   of the way from the one to the other.

   **Outside the model**, as the content's files are: the connection,
   what was sent and not yet answered, the last rounds, the sparks.
   Each frame's picture is still a value, the round shown
   ([Soldat_model.Online]), and the view draws it as any other.

   Also here: the room's talk (the key t, a line typed, enter), shown
   over the game with who came and who went.

   The weapon to come back with (the keys 1 to 9 and 0, as alone) is
   said to the server when it changes (Soldat_protocol's Weapon).

   **The lobby's screen.** Given no room (the flag room=), one is in
   the lobby, and the scene is [Soldat_model.Lobby]: a room for each
   of the game's maps, then the server's others, each with its
   players' number, asked each second (List); the arrows choose,
   enter enters (Join). In a game, escape comes back here (Leave).

   Not here: a connection lost and found again.

   In Soldat: shared/network/NetworkClient*.pas, where a client says
   where its own soldier is and the server believes it
   (TMsg_ClientSpriteSnapshot_Mov); here the server alone moves it,
   and the client only guesses.
*)
open Playground

(* a server to play on: connected to at the first frame (a platform
 * says how when it starts, not before), and told Hello; [room] is the
 * room to enter then (its name is its map's: "Arena2", "ctf_Ash").
 * From then on [update] plays there; if it cannot be had, the screen
 * says why *)
val connect : < Cap.network ; .. > -> host:string -> port:int -> nick:string -> room:string -> unit

(* connected: the same over a connection already made (a test's) *)
val connected : Transport.t -> nick:string -> room:string -> unit

(* a frame: Soldat_update.update, or, connected, the server's round *)
val update : computer -> Soldat_model.model -> Soldat_model.model

(* how many times the server's word moved this program's own soldier
 * more than a unit from where it had guessed it: a bullet's push, an
 * explosion, a death, and nothing when it is left alone *)
val corrections : unit -> int

(* a map by its name, known without its file: for the tests, whose
 * maps are made by hand *)
val know : string -> Soldat_map.t -> unit

(* the connection forgotten: for the tests *)
val reset : unit -> unit
