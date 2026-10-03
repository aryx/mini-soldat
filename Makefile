# @default (recursive) rather than plain 'dune build', so that the
# 'default' alias of src/main/web/ is used and its page is copied into
# _build/ next to the generated MiniSoldat.bc.js
all:
	dune build @default
test:
	dune runtest -f
clean:
	dune clean
# the two programs, bin/mini-soldat (Cairo when its platform is
# installed, else the software one) and bin/mini-soldat-software (the
# Playground's own rasterizer, always): see src/main/dune
run:
	dune exec mini-soldat
run-software:
	dune exec mini-soldat-software

# the third program, in a browser (src/main/web/dune): build, then
# serve it from _build over HTTP. 127.0.0.1, so only this machine can
# connect; Ctrl-C to stop. Flags go after a '?':
#   http://localhost:8001/index.html?hitboxes&ai=engine
# The page asks for its content in assets/ beside it: a link to the
# website's, which 'make website' makes.
serve: all website
	ln -sfn $(CURDIR)/docs/assets _build/default/src/main/web/assets
	@echo "serving mini-soldat at http://localhost:8001/"
	python3 -m http.server --directory _build/default/src/main/web --bind 127.0.0.1 8001

# the website, docs/, what Github Pages serves ("Deploy from a branch",
# main, /docs): docs/index.html is written by hand; the game's page and
# its program are copied there, the program built with the release
# profile (js_of_ocaml then compiles the whole program at once and
# drops what is not used: 160 KB instead of 4 MB), and the content the
# game fetches (docs/assets/, which a browser asks for beside its page:
# the maps of data/, its sounds as they are, and its textures, scenery,
# weapons and sparks turned into plain pixels, name.rgba, since a
# browser is slow to decode a PNG with our own decoder:
# Soldat_assets.mli; an explosion's 26 big pictures at half their
# size). To commit after.
# serve-website to look at it before: http://localhost:8000/
website:
	dune build --profile release src/main/web/MiniSoldat.bc.js
	cp _build/default/src/main/web/MiniSoldat.bc.js docs/MiniSoldat.bc.js
	cp src/main/web/index.html docs/play.html
	chmod u+w docs/MiniSoldat.bc.js
	rm -rf docs/assets
	mkdir -p docs/assets/textures/objects docs/assets/scenery-gfx docs/assets/weapons-gfx docs/assets/sparks-gfx/explosion
	cp -r data/sfx docs/assets/
	cp -r data/maps docs/assets/
	dune build src/assets/Gen_assets.exe
	_build/default/src/assets/Gen_assets.exe data/textures docs/assets/textures
	_build/default/src/assets/Gen_assets.exe data/textures/objects docs/assets/textures/objects
	_build/default/src/assets/Gen_assets.exe data/scenery-gfx docs/assets/scenery-gfx
	_build/default/src/assets/Gen_assets.exe data/weapons-gfx docs/assets/weapons-gfx
	_build/default/src/assets/Gen_assets.exe data/sparks-gfx docs/assets/sparks-gfx
	_build/default/src/assets/Gen_assets.exe data/sparks-gfx/explosion docs/assets/sparks-gfx/explosion half
serve-website:
	@echo "serving docs/ at http://localhost:8000/"
	python3 -m http.server --directory docs --bind 127.0.0.1 8000

# the lines of OCaml, and how much of the budget (10,000 for src/, a
# tenth of OpenSoldat's Pascal; a file's opening comments not counted)
# they are; loc-v: a library a line. docs/omitted.md is the other side
# of that number
loc:
	scripts/stats/loc.py
loc-v:
	scripts/stats/loc.py -v

#coupling: see also .github/workflows/docker.yml
build-docker:
	docker build -t "mini-soldat" .
build-docker-ocaml5:
	docker build -t "mini-soldat" --build-arg OCAML_VERSION=5.5.1 .

.PHONY: all test clean run run-software serve website serve-website loc loc-v build-docker build-docker-ocaml5
