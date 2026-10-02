(* Soldat_map: the map a game is played on.

   What the game needs of a map, whatever it was made from: polygons
   to draw, those that stop a soldier and those that stop a bullet, the
   places a soldier appears at, the sky's colours, and how far it goes.
   Two makers: [of_pms], from one of Soldat's own maps as its file has
   it (Pms.mli), and [toy], the one screen TinySoldat was played on,
   kept for the tests and for comparison (the flag map=toy).

   From Soldat's coordinates to the game's:

   - y is turned over: Soldat's grows downwards, the Playground's
     upwards;
   - everything is twice as big ([scale]). Soldat's soldier is about 20
     of its units tall and the one inherited from TinySoldat 44 pixels,
     with its speeds and its gravity tuned to that: for now the map is
     brought to the soldier. It goes away the day the soldier is
     Soldat's own;
   - a triangle's corners are put counterclockwise, which the physics
     wants and the file does not promise; one with no area is dropped.

   What a polygon stops is its kind's business (Pms.kind), here without
   teams or flags, which the game does not have yet: a soldier is
   stopped by the plain ones and by all those that do something to it
   (ice, the deadly ones, lava...), not by those for bullets only, for
   the eye, for one team or for the background; a bullet the same, with
   "players only" for "bullets only". What the kinds do (slide, hurt,
   kill, bounce) is not done yet: all are plain ground.

   A polygon is filled with one colour: the mean of its three corners'
   times the mean colour of the map's texture (Texture_tints), a first
   approximation of what Soldat draws, the texture itself shaded by the
   corners; a polygon whose corners are all transparent is not drawn
   (Soldat's maps have many: walls one cannot see). Its props (the
   scenery) are not drawn yet.

   In Soldat: shared/PolyMap.pas (TPolyMap: the polygons, their kinds,
   the sectors, CollisionTest and RayCast, where which kind stops what
   is decided) and client/MapGraphics.pas (the map as vertices to
   draw).
*)
open Playground

type t = {
  name : string;
  (* behind the soldiers: the sky, then the background polygons *)
  back : shape list;
  (* over them, as Soldat draws its polygons: their feet sink in a
   * little *)
  front : shape list;
  (* what stops a soldier: convex polygons, counterclockwise, and the
   * same as bodies nothing moves, for the Physics layer's world *)
  walls : (number * number) list list;
  bodies : Physics.body list;
  (* what stops a bullet, and a line of sight *)
  bullet_walls : (number * number) list list;
  bullet_bodies : Physics.body list;
  (* where a soldier appears: never empty *)
  spawns : (number * number) list;
  (* how far the map goes: what the camera stays within *)
  bounds : Camera2d.rect;
}

(* how many pixels of the game a unit of Soldat's is: 2 *)
val scale : number

(* what pulls everything down, in pixels per second per second *)
val gravity : number

(* the game's map for one of Soldat's *)
val of_pms : Pms.t -> t

(* TinySoldat's one screen: hills, two walls, five platforms, a bunker *)
val toy : t

(* the map the game starts on, carried in the program: Soldat's Arena2
 * (data/maps/Arena2.pms) *)
val arena2 : t Lazy.t

(* nothing of the map between a and b: one sees the other, and a
 * bullet would get there *)
val clear : t -> number * number -> number * number -> bool

(* which kinds stop a soldier, and a bullet *)
val stops_soldier : Pms.kind -> bool
val stops_bullet : Pms.kind -> bool
