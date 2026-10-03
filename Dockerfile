# Build and test mini-soldat with OCaml 4.14.4 via OPAM on Ubuntu.
# See also .github/workflows/docker.yml for its use in Github Actions (GHA).
# coupling: adapted from ~/github/mini-chrome/Dockerfile

# 24.04, not 22.04: tsdl calls SDL_RenderGetWindow, SDL 2.0.22's,
# and 22.04 has SDL 2.0.20
FROM ubuntu:24.04

# Setup a basic C dev environment
RUN apt-get update # needed otherwise can't find any package
RUN apt-get install -y build-essential autoconf automake pkgconf git

# Setup OPAM and OCaml
RUN apt-get install -y opam
# Initialize opam (disable sandboxing due to Docker)
RUN opam init --disable-sandboxing -y
ARG OCAML_VERSION=4.14.4
RUN opam switch create ${OCAML_VERSION} -v

# System deps of elm-playground: its native platform (SDL2 and Cairo),
# and what the rest of its repository builds with.
# coupling: ~/playground/Dockerfile
# (the list of packages again: a layer of it kept from an earlier build goes stale)
RUN apt-get update && apt-get install -y pkg-config libsdl2-dev libcairo2-dev libcurl4-gnutls-dev libgl-dev

# elm-playground, from its sources: cloned, built and installed in the
# switch (its 'make install' is 'dune install'), as one does to work on
# both at once (README.md). So that this does not wait for a version of
# it on opam, nor for a tag: mini-soldat uses what its master has.
# Only the packages mini-soldat links are built, and the two of its own
# that elm_playground needs (tiny_languages, tiny_appkits).
# ELM_PLAYGROUND_REF: a branch, a tag or a commit of it.
ARG ELM_PLAYGROUND_REF=master
RUN git clone https://github.com/aryx/ocaml-elm-playground /playground \
 && cd /playground && git checkout ${ELM_PLAYGROUND_REF} && git log --oneline -1
WORKDIR /playground
RUN eval $(opam env) && ./configure
RUN eval $(opam env) \
 && dune build -p tiny_libs,tiny_languages,tiny_appkits,elm_playground,elm_playground_native,elm_playground_software,elm_playground_web @install \
 && dune install tiny_libs tiny_languages tiny_appkits elm_playground elm_playground_native elm_playground_software elm_playground_web

WORKDIR /src

# Install the other dependencies (copy minimal files for Docker layer
# caching): ./configure finds elm-playground's packages installed, and
# pins nothing
COPY configure mini-soldat.opam ./
RUN eval $(opam env) && ./configure

# Now copy the full source and build
COPY . .
RUN eval $(opam env) && make

# Test
RUN eval $(opam env) && make test
