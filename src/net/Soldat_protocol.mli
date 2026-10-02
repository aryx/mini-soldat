(* Soldat_protocol: what a player's program and the server say to each
   other, as bytes.

   For now the words of the lobby only: a player names itself, enters a
   room, talks in it, asks which rooms there are; the server tells it
   who came, who went and what was said. A room is where a game will be
   played: the game's own messages (a player's keys up, the world down)
   are to come here beside these.

     player                              server
       Hello "pad"            ---->
                              <----      Welcome "pad"
                              <----      Entered ("lobby", ["mm"; "pad"])
       Join "ctf_Ash"         ---->
                              <----      Entered ("ctf_Ash", ["pad"])
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

(* from the server to a player *)
type to_client =
  | Welcome of string (* you are in, under this nick *)
  | Refused of string (* what you asked was not done, and why *)
  | Rooms of (string * int) list (* each room, and how many are in it *)
  | Entered of string * string list (* you are now in this room, with these (you among them) *)
  | Came of string (* this nick came into your room *)
  | Went of string (* this nick left your room *)
  | Said of string * string (* this nick said this line, in your room *)

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
