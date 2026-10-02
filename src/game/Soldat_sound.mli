(* Soldat_sound: the tick's sounds, played.

   The game says what was heard in a tick and where
   ([Soldat_model.play.sounds]); this plays it, through the
   Playground's Audio, as it is heard from where the player's soldier
   is. It is the one module of the game that does something rather
   than compute something, called from [Soldat_update.update] and
   nowhere else: no rule of the game knows of it.

   **How loud, and from where** (Soldat's FPlaySound). A sound is as
   loud as it is near: at a distance d from the listener, of its
   loudness is kept

       1 - d / 750

   and beyond 750 units it is not played. It comes from the left or
   the right by where it is across: OpenAL is given the sound's place
   with the listener 1000 units in front of the map, which is a pan of
   dx / sqrt (dx^2 + 1000^2).

   Worked example: a shot 300 units to the right is played at 1 - 300
   / 750 = 0.6 of its loudness, panned 300 / 1044 = 0.29 to the right.

   **Heard from far.** A shot or an explosion beyond half that
   distance is also heard as another recording, a dull one (dist-gun1
   to 4, dist-grenade, dist-m79), which grows *louder* with the
   distance up to 750 and then fades up to 1500: so a fight across
   the map is heard as a rumble, where its own sounds no longer reach.

   **The files** are Soldat's .wav recordings, asked from the content
   (sfx/, through Soldat_assets) the first time each is played and
   kept: a sound whose file has not come yet is not heard. Half of
   them are 8-bit, which the Playground's reader does not take: those
   are rewritten as 16-bit first ([to_16_bit]).

   **The jets** are a sound that lasts as long as they push: one
   recording looped for each soldier flying (Audio.loop), stopped
   when it lands.

   At most 12 sounds are started in a tick (5 in a browser), the
   loudest first: a minigun and its shells would be 30.

   **In a browser** a sound is not put to a side, and is played at one
   of four loudnesses (1, 0.7, 0.45, 0.25): making a recording louder
   and panned is computing all of it again at each play, which
   JavaScript does too slowly for an explosion; a recording played as
   it is costs nothing, so each is kept at those four.

   In Soldat: client/Sound.pas (LoadSounds, FPlaySound), over OpenAL.
*)

(* [play ~listener ~frame sounds]: the sounds of a tick, heard from
 * [listener]; [frame] chooses among a sound's recordings *)
val play : listener:float * float -> frame:int -> (Soldat_sfx.t * (float * float)) list -> unit

(* [jets ~listener flying]: the jets' sound for each soldier of
 * [flying] (its number, where it is), and none for the others *)
val jets : listener:float * float -> soldiers:int -> (int * (float * float)) list -> unit

(* how loud and how far to a side a sound at [at] is, heard from
 * [listener]: None beyond 750 units *)
val heard : listener:float * float -> float * float -> (float * float) option

(* a .wav file's bytes with 16-bit samples: itself, or, 8-bit, each
 * sample s made (s - 128) x 256 *)
val to_16_bit : string -> string

(* ask for the recordings ahead of their first use, three at each
 * call: how many are still to come. Called while the title shows, so
 * that a round's first shot does not wait for its file *)
val warm : unit -> int

(* no sound at all: for a program that only steps the game *)
val mute : bool ref
