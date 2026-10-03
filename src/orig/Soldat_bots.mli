(* Soldat_bots: Soldat's own bots (the bots' part, Soldat's way:
   Soldat_parts.mli; its twin is src/twin/Soldat_engine_bot).

   A bot presses the keys a player would (Soldat_soldier.control), and
   its soldier moves and fires by the same rules. Each tick it decides
   afresh, from what it sees:

   **It sees nobody: the waypoints.** A map carries a graph drawn by
   its author for the bots, the *waypoints*: points, each saying which
   keys to hold on the way to it (left, right, jump, crouch, jets) and
   which points come next. A bot looks for a waypoint within 21 units
   of itself (350 when it has none), takes one of its connections by
   chance as the next, and holds the next one's keys until it is
   within 21 of another. So a bot does not find its way: it follows
   the keys a person drew, and a map without waypoints has bots that
   stand still until somebody comes. Stuck for 90 ticks, it jumps;
   every 320 ticks it jumps anyway and goes back a waypoint; 480 ticks
   on the same one, it forgets it. A waypoint may say to stop and camp,
   or to wait some seconds.

   **It sees somebody** (nothing of the map on the line from its head
   to theirs, within 651 units): that is its target, the nearest of
   those it sees, or who last shot it. What it does is a ladder of
   distances along x (SimpleDecision):

        35 or less   backs away, firing
        55           stands and fires; reloading, backs away
        95           crouches and fires
       180           the same, still walking on
       350           fires
       500           jumps, fires one tick in two (a camper crouches)
       730           fires one tick in four
       farther       nothing

   The target 180 or more above: the jets. It aims at where the target
   will be in 10 ticks, raised for the bullet's fall (0.5 x distance /
   the weapon's speed; 1.75 x beyond 350), and off by up to its
   Accuracy, a number of its character: 0 never misses.

   **A character** is a .bot file of Soldat's, 16 of them (Kruger and
   his Ruger, Sniper and his Barrett, Billy and his shotgun...): a
   name, three colours, a favourite weapon (it appears with it one
   time in two, with one of the nine others by chance else), how well
   it aims, how often it throws a grenade (one tick in so many, when
   an enemy is near), whether it camps, whether it goes on shooting
   the dead. Boogie Man likes the chainsaw, which is not here: he does
   not play.

   Besides: hurt, it walks to a medikit it sees within 350; short of
   grenades, to a grenade kit; it runs from a grenade within 119; it
   fires its jets when it falls fast.

   The chance in all this (which connection, whether to fire, how far
   off to aim) is the game's ([random]), so a round replays the same.

   One bot of another making can play beside these: Soldat_engine_bot,
   on elm-playground's Sense and Bot.

   In a Rambomatch (AI.pas:587, 613, 992): Rambo, seen, is the target
   whoever is nearer; a bot without the bow fires at nobody else; it
   walks to the bow it sees and, near it, throws its weapon away, for
   only empty hands take it.

   Left out: the teams and the flags (which path a bot takes with a
   flag), hiding behind a collider, the fists, the difficulty (it is
   Soldat's "normal": 100), the chat.

   In Soldat: shared/AI.pas (ControlBot, SimpleDecision, GoToThing),
   shared/Waypoints.pas, LoadBotConfig (shared/SharedConfig.pas), and
   server/configs/bots/.
*)
open Soldat_model

(* what a bot has in mind from a tick to the next: Soldat's Brain. A
 * waypoint is its number in the map's file, from 1; none: 0. A
 * soldier is its place among the round's, none: -1 *)
type brain = {
  character : character;
  target : int;
  (* who shot it: seen, it becomes the target *)
  pissed_off : int;
  (* the waypoint it is at, the one it goes to, and the one before *)
  current : int;
  next : int;
  old : int;
  (* ticks at the same waypoint, and what is left before it gives up
   * and goes back *)
  last : int;
  waypoint_time : int;
  timeout : int;
  (* ticks it has not moved, or has waited where a waypoint says to *)
  one_place : int;
  (* it is walking to a kit *)
  go_thing : bool;
  (* it is falling fast: the jets *)
  fall_save : bool;
  (* its keys last tick: a grenade's is held from a tick to the next *)
  keys : Soldat_soldier.control;
}

(* a bot's mind in a round is its Brain *)
type Soldat_state.mind += Brain of brain

(* a mind's Brain, if it is one *)
val brain_of : Soldat_state.mind -> brain option

(* Soldat's bots as the game's bots: what Soldat_orig registers *)
val part : Soldat_parts.bots

(* a .bot file read; None if it has no [BOT] section, or likes a
 * weapon that is not here *)
val character : string -> character option

(* Soldat's, those that can play: 15 *)
val characters : character list Lazy.t

(* [cast n round]: the [n] bots of a round, each round's cast starting
 * one further in the list *)
val cast : int -> int -> character list

(* a mind that has seen nothing yet *)
val brain : character -> brain

(* the weapon a bot appears with: its favourite one time in two *)
val weapon : character -> random:(unit -> float) -> Soldat_weapons.id

(* [control p i brain ~random]: the keys of soldier [i], a bot, this
 * tick; its mind after; and the things it looked at with a mind to
 * go, by their place in [p.things] (each look wears its interest) *)
val control : play -> int -> brain -> random:(unit -> float) -> Soldat_soldier.control * brain * int list

(* which of 35, 55, 95, 180, 350, 500, 730 a distance along an axis is
 * within, or 731 (CheckDistance) *)
val bucket : float -> float -> int
