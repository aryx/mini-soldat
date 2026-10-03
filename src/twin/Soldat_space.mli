(* Soldat_space: the sound's place's twin, on the Playground's Space.

   Soldat says how loud a sound is and from which side by two lines of
   its own (Soldat_sound.heard, from Sound.pas): the loudness falls in
   a straight line to nothing at 750 units, and the side is the
   distance across over a made-up depth of 1000. This is the same
   question asked of elm-playground's audio library (docs/twins.md):

     Space.attenuation   full within 100 units, then as their inverse:
                         twice as far, half as loud, as sound does in
                         air; never quite nothing
     Space.direction     the sine of the angle between straight ahead
                         and the sound, for a listener 300 units
                         behind the screen who looks into it: -1 the
                         left, 1 the right

   Worked example: a shot 300 units to the right of the listener is
   heard at 100 / 300 = 0.333 of its loudness, from sin 45 = 0.707 of
   the way to the right. Soldat's own: 1 - 300 / 750 = 0.6, and 0.287.

   **Limits met here.**

   1. *An inverse never reaches nothing*: at 2,000 units a shot is
      still heard at a twentieth. Soldat's falls to nothing at 750. So
      at this level a fight across the map is a murmur, and more
      sounds reach the mixer; Soldat_sound keeps the loudest few a
      tick, whatever the level.

   2. *Space is in three dimensions, the game in two*: the listener
      is put 300 units behind the screen, looking into it, so that a
      sound straight above is in the middle and one 300 to the right
      is at 45 degrees.

   It is the sound's level 2 (the key v, audio=2).
*)

(* how loud (0 to 1) and from which side (-1 to 1) a sound at a place
 * is heard by a listener at another *)
val heard : listener:float * float -> float * float -> float * float
