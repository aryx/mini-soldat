all:
	dune build
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

#coupling: see also .github/workflows/docker.yml
build-docker:
	docker build -t "mini-soldat" .
build-docker-ocaml5:
	docker build -t "mini-soldat" --build-arg OCAML_VERSION=5.5.1 .

.PHONY: all test clean run run-software build-docker build-docker-ocaml5
