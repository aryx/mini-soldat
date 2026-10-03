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

   **Limits met here, and what is done about each.**

   1. *The widgets are kept between update and view by the toolkit
      itself* (the one piece of mutable state of the Playground's
      libraries, Gui.mli says why): a frame that asks for widgets and
      is not followed by Gui.draw leaves them for the next. The view
      calls Gui.draw whenever the lobby is shown at this level; a test
      that has no view calls it by hand, each frame.

   2. *A click on a menu's item is also a click on what is under
      it.* While the menu's items show, they cover the rooms'
      buttons.
      Done about it: a button's click counts only when no menu is
      open (Gui.modal).

   3. *A widget needs a cursor to be seen.* Soldat's interface hides
      the system's cursor and draws its own sight; at this level the
      view draws Soldat's arrow instead, everywhere.

   It is the interface's level 2 (the key u, interface=2).
*)
open Playground

(* the lobby's widgets for a frame: a button for each room (its name,
 * how many play there) and a menu of the modes' names, the one chosen
 * by its place. The place chosen after this frame, and the room whose
 * button was clicked, if one was *)
val lobby : computer -> rooms:(string * int) list -> modes:string list -> int -> int * string option
