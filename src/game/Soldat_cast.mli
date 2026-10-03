(* Soldat_cast: the bots' characters.

   A bot of Soldat's is a .bot file (server/configs/bots/, 16 of them:
   Kruger and his Ruger, Sniper and his Barrett, Billy and his
   shotgun...): a name, the colours of its shirt, trousers and skin, a
   favourite weapon, and how it fights: how far off it aims
   (Accuracy), whether it goes on shooting who it killed, how often it
   throws a grenade, whether it holds its ground (Camping).

   They are the round's cast whoever moves them: Soldat's own bots
   (src/orig/Soldat_bots) read all of it; the Playground's
   (src/twin/Soldat_engine_bot) only wears the names and the colours.

   In Soldat: LoadBotConfig (shared/SharedConfig.pas).
*)
open Soldat_model

(* a .bot file's text as a character; none if it has no name *)
val character : string -> character option

(* Soldat's, as the program carries them (data/bots/) *)
val characters : character list Lazy.t

(* [cast n round]: n of them for a round, another first each round *)
val cast : int -> int -> character list

(* TSprite.Respawn: its favourite weapon, or one of the first nine *)
val weapon : character -> random:(unit -> float) -> Soldat_weapons.id

(* Random(n): a whole number from 0 to n - 1; 0 for none *)
val whole : random:(unit -> float) -> int -> int

(* the character of the bot of ai=engine *)
val engine : character
