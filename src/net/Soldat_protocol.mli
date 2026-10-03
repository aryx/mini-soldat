(* Soldat_protocol: what a player's program and the server say to each
   other, as bytes.

   The words of the lobby: a player names itself, enters a room, talks
   in it, asks which rooms there are; the server tells it who came, who
   went and what was said. And the game's: a room other than the lobby
   is a round the server plays, and whoever enters it is given a
   soldier of it ([Seat]); from then on it sends its keys, numbered
   ([Input]), and is sent the round 30 times a second ([World]), with
   the number of the last of its keys the server has played. What the
   keys and the round are as bytes is Soldat_wire's.

     player                              server
       Hello "pad"            ---->
                              <----      Welcome "pad"
                              <----      Entered ("lobby", ["mm"; "pad"])
       Join "ctf_Ash"         ---->
                              <----      Entered ("ctf_Ash", ["pad"])
                              <----      Seat { seat = 2; map = "ctf_Ash" }
       Input (0, keys)        ---->
       Input (1, keys)        ---->
                              <----      World { acked = 0; world }
       Say "anyone?"          ---->
                              <----      Said ("pad", "anyone?")

   A message is one WebSocket binary frame (what a browser has, and a
   native program speaks too), its bytes written with elm-playground's
   Wire: a first byte saying which message it is, then its fields, a
   string as its length (a varint) and its bytes, a list as its count
   then its items. The worked example, checked by the tests:

     Hello "pad"                        10  03 70 61 64
     Said ("pad", "hi")                 26  03 70 61 64  02 68 69
     Rooms [("lobby", 2)]               22  01  05 6c 6f 62 62 79  02
     Weapon 8  (the Barrett)            16  08

   The player's messages start at 10, the server's at 20; none starts
   with 02, the byte elm-playground's relay opens its welcome with
   (Relay.mli), which its WebSocket client keeps for itself.

   Anything that does not parse is refused whole (Wire's rule): bytes
   missing, bytes left over, an unknown first byte, a string longer
   than 255 bytes. The server closes the connection that sent it. What
   parses but is not acceptable (a name with a space in it, a nick
   already taken) is the lobby's business, answered with a Refused
   (Soldat_lobby.mli).

   In Soldat: shared/network/Net.pas, where each message is a packed
   record opening with its number (MsgID_ChatMessage,
   MsgID_PlayersList...), sent over UDP by Valve's
   GameNetworkingSockets. There a server is one game, and the list of
   servers is kept by another program, the lobby server, which each
   game server tells it exists (server/LobbyClient.pas); here one
   server holds the rooms itself. Its limits are kept: a name is 24
   characters at most (PLAYERNAME_CHARS).
*)

(* from a player to the server *)
type to_server =
  | Hello of string (* my nick; the first message *)
  | Join of string (* enter this room, made if it is new, leaving mine *)
  | Leave (* back to the lobby *)
  | Say of string (* a line, to everyone in my room *)
  | List (* which rooms are there? *)
  | Input of int * string (* my keys this tick, numbered from 0 (Soldat_wire's bytes) *)
  | Weapon of int (* the weapon to appear with from now on, by its key in Soldat's menu: 0 to 9 *)
  | Secondary of int (* and the second one: 0 the USSOCOM, 1 the knife, 2 the chainsaw, 3 the LAW *)

(* from the server to a player *)
type to_client =
  | Welcome of string (* you are in, under this nick *)
  | Refused of string (* what you asked was not done, and why *)
  | Rooms of (string * int) list (* each room, and how many are in it *)
  | Entered of string * string list (* you are now in this room, with these (you among them) *)
  | Came of string (* this nick came into your room *)
  | Went of string (* this nick left your room *)
  | Said of string * string (* this nick said this line, in your room *)
  | Seat of { seat : int; map : string } (* in this room's game you are that soldier, on that map *)
  | World of { acked : int; world : string }
      (* the round (Soldat_wire's bytes), after the keys of yours numbered [acked] (-1: none yet) *)

val encode_to_server : to_server -> string
val encode_to_client : to_client -> string

(* the message these bytes are, or what was wrong with them *)
val decode_to_server : string -> (to_server, string) result
val decode_to_client : string -> (to_client, string) result

(* the room everyone is in who is in no other *)
val lobby : string

(* a nick's or a room's name: 1 to 24 printable ASCII characters, no
 * space *)
val valid_name : string -> bool

(* a line said: 1 to 200 bytes, none a control character (bytes above
 * 127 pass: UTF-8, not checked) *)
val valid_text : string -> bool

(* A room's name is its map's, with, after a dot, the mode asked for
 * (Soldat_model.mode_words): "Arena2.rm" is a Rambomatch on Arena2,
 * "ctf_Ash" the map's own mode. A word that is no mode is none *)
val room_map : string -> string
val room_mode : string -> Soldat_model.mode option
