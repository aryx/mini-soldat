(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* See Soldat_space.mli *)

let heard ~(listener : float * float) ((x, y) : float * float) : float * float =
  let (dx, dy) = (x -. fst listener, y -. snd listener) in
  ( Space.attenuation ~reference:100. (Float.hypot dx dy),
    Space.direction ~listener:(Space.vec 0. 0. (-300.)) ~right:(Space.vec 1. 0. 0.) (Space.vec dx dy 0.) )
