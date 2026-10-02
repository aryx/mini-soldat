(* Poa: Soldat's animations and skeletons, as their files have them.

   Two formats of text, one word a line, both exported from a 3D
   modeller, whose axes they keep: x across, y towards the viewer, z up.
   Soldat is flat: it reads x and z, and drops y.

   An animation (anims/biega.poa: "runs") is frames of points:

     1                      a point's number, 1 to 20
     1.51294851303101       x
     2.19840430581986E-11   y, not read
     -0.018487149849534     z
     2                      the next point
     ...
     NEXTFRAME              the frame's end, another begins
     ...
     ENDFILE

   A point is where a joint of the soldier's body is, from its feet:
   the same 20 numbers in every animation. Read, a point is

     x := -3 * x / 1.1        y := -3 * z

   in Soldat's own coordinates, y downwards: 3 is the size of a
   soldier (SCALE), and both are turned over.

   A skeleton (objects/gostek.po: the soldier's) is points then sticks:

     P1                     a point's name, not read: they are numbered as they come
     1                      x
     0                      y, not read
     0                      z
     ...
     CONSTRAINTS
     P2                     a stick, from this point
     P3                     to this one
     ...
     ENDFILE

   with x := -x * scale / 1.2 and y := -z * scale (1.2 here, 1.1 there:
   as the Pascal has them). A stick is as long as its two points are
   apart when read.

   The worked example, checked by the tests: data/anims/stoi.poa
   ("stands") has 17 frames; the first one's first point is
   (-4.126, 0.055); data/objects/gostek.po at a scale of 3 has 24
   points and 30 sticks, the first from point 2 to point 3.

   In Soldat: TAnimation.LoadFromFile (shared/Anims.pas) and
   ParticleSystem.LoadPOObject (shared/Parts.pas).
*)

(* a frame: 20 points, the first at 0. A point a frame does not name is
 * at (0, 0) *)
type frame = (float * float) array

(* the frames of a .poa file's text (40 at most, as Soldat), or what
 * was wrong with it *)
val animation : string -> (frame array, string) result

type skeleton = {
  points : (float * float) array; (* the first at 0 *)
  sticks : (int * int * float) array; (* two points, numbered from 1 as in the file, and the length *)
}

(* the skeleton of a .po file's text, at a scale *)
val skeleton : scale:float -> string -> (skeleton, string) result
