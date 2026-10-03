(* Soldat_parts: the parts of the game that are made twice.

   Most of mini-soldat is made once: the map, the soldier, the
   weapons, the bullets, a round's rules. Four parts are made twice
   (docs/twins.md): Soldat's own, adapted from its Pascal, in
   src/orig; and a *twin*, the same job done with one of
   elm-playground's libraries, in src/twin.

       the part      src/orig                 src/twin
       the bots      Soldat_bots (AI.pas)     Soldat_engine_bot (Sense, Bot, Pathfind, Behavior)
       the effects   Soldat_sparks            Soldat_juice (Emitter, Trauma, Follow)
       the things    Soldat_fall (Particles)  Soldat_bodies (Physics: rigid bodies)
       the sound's   Soldat_sound.places      Soldat_space (Space)
        place          (in Soldat_sound)

   The shared code knows neither folder. Each part is a record of
   functions, and here is a *slot* for each: the Soldat's and the
   twin's. A program fills the slots of the folders it is linked with
   when it starts (Soldat_orig.register, Soldat_twin.register), and a
   round asks the slot for the one its layer's level says, or for the
   other when that one is not there. So the game is whole with both
   folders (a key goes from one to the other while it runs), with
   src/orig alone, or with src/twin alone: three programs, one shared
   code.
*)
open Soldat_model

(* a slot: Soldat's, and the twin's; either may be missing *)
type 'a slot = { mutable orig : 'a option; mutable twin : 'a option }

(* the one asked for ([twin] or not) if the program has it, else the other *)
val pick : 'a slot -> twin:bool -> 'a option

(* the bots: whether a mind is this part's; a new mind for a
 * character; and a tick of it: the keys of soldier [i], the mind
 * after, and the things it looked at (their places in the round's) *)
type bots = {
  owns : Soldat_state.mind -> bool;
  fresh : character -> Soldat_state.mind;
  control : play -> int -> Soldat_state.mind -> random:(unit -> float) -> intent * Soldat_state.mind * int list;
}

(* the effects: what is seen of a tick's events, a tick later, with
 * what they give to hear besides the events' own sounds (a shell on
 * the ground); how much they shake the camera; and how the camera
 * goes after a place ([look]: the cursor, from the screen's middle) *)
type effects = {
  tick : Soldat_map.t -> random:(unit -> float) -> (int * Soldat_event.t) list -> Soldat_state.fx -> Soldat_state.fx * (Soldat_sfx.t * (float * float)) list;
  shake : random:(unit -> float) -> Soldat_state.fx -> float * float;
  follow : camera:float * float -> float * float -> look:float * float -> float * float;
}

(* the things: one that is not at rest, a tick later *)
type things = ?heard:Soldat_event.t list ref -> Soldat_map.t -> Soldat_things.t -> Soldat_things.t

(* the lobby's screen as widgets, which only the twin has
 * (src/twin/Soldat_gui): the rooms and the modes' names in, the mode
 * chosen and the room clicked out *)
val lobby : (Playground.computer -> rooms:(string * int) list -> modes:string list -> int -> int * string option) option ref

val bots : bots slot
val effects : effects slot
val things : things slot
