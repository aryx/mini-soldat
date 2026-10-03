(* Soldat_gui: the lobby's screen's twin, on the Playground's Gui.

   Soldat_online's lobby is lines of text and keys: the arrows move a
   mark, enter enters. This is the same screen as elm-playground's Gui
   would have one write it first (docs/twins.md): a button a room, a
   menu for the mode, clicked.

   Gui is *immediate mode*: there is no button object, no callback. A
   widget is a question asked each frame, in update:

     Gui.button computer ~at label   was I clicked this frame?
     Gui.menu computer ~at items i   which item is chosen now?

   and the view asks for what they drew (Gui.draw, in Soldat_view),
   which ends the frame. A room that comes or goes needs nothing done:
   its button is asked for, or it is not.

   It is the interface's level 2 (the key u, interface=2).
*)
open Playground

(* the lobby's widgets for a frame: a button for each room (its name,
 * how many play there) and a menu of the modes' names, the one chosen
 * by its place. The place chosen after this frame, and the room whose
 * button was clicked, if one was *)
val lobby : computer -> rooms:(string * int) list -> modes:string list -> int -> int * string option
