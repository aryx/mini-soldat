(lang dune 3.0)

(name mini-soldat)

(generate_opam_files true)

(license "LGPL-2.1-only")

(authors
   "Yoann Padioleau <yoann.padioleau@gmail.com>"
)

(maintainers
   "Yoann Padioleau <yoann.padioleau@gmail.com>"
)

(version "0.1.0")

(source (github aryx/mini-soldat))
(homepage "https://github.com/aryx/mini-soldat")
(bug_reports "https://github.com/aryx/mini-soldat/issues")

;; one package, the game; the libraries of src/ are private (see
;; README.md). It stands on elm-playground's packages: the Playground
;; for its window (or a browser's page), its drawing and its Physics
;; layer, tiny_libs for the 2D physics underneath (the solver, the
;; swept tests, the particles and sticks of the ragdolls), the bots'
;; senses, and the server's networking (WebSocket connections on one
;; event loop, values as bytes).
(package (name mini-soldat)
  (synopsis "A clone of Soldat in OCaml, from scratch")
  (description "\
  A side-view deathmatch after Soldat (Michal Marcinkowski, 2002):
  soldiers running, jumping and flying on jet boots over a map of
  polygons, shooting and throwing grenades, and falling as ragdolls.
  It started as elm-playground's TinySoldat. Three programs of it, on
  the desktop (SDL) and in a browser (js_of_ocaml), and a server with
  rooms to talk and, soon, play in.
")
  (depends
    (ocaml (>= "4.14.0"))
    ; the server's authority to listen (Cap.network)
    (caps (>= "0.1.0"))
    ; 0.3.3, the one TinySoldat was copied from
    (tiny_libs (>= "0.3.5"))
    (elm_playground (>= "0.3.5"))
    ; the software platform, SDL only: mini-soldat-software, and
    ; what the tests link
    (elm_playground_software (>= "0.3.5"))
    ; the web platform, js_of_ocaml and vdom: the game in a browser
    ; (src/main/web), the website's
    (elm_playground_web (>= "0.3.5"))
    (testo :with-test)
    (alcotest :with-test)
  )
  ; the native platform, SDL and Cairo: mini-soldat, built on it when
  ; it is installed (src/main/dune's select)
  (depopts
    elm_playground_native)
)
