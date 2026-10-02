# Playing over the network

The goal: several players in the same game, from the desktop programs
and from the browser alike, meeting on a server.

## What is there

`mini-soldat-server`, a lobby: players connect, name themselves, enter
rooms and talk. Three modules, each with its story in its `.mli`:

| Module | What |
|---|---|
| `src/net/Soldat_protocol` | the messages as bytes: `Hello`, `Join`, `Leave`, `Say`, `List` up; `Welcome`, `Refused`, `Rooms`, `Entered`, `Came`, `Went`, `Said` down |
| `src/server/Soldat_lobby` | who is in which room and who is told what: a value, no socket, tested by calling it |
| `src/server/Soldat_server` | the lobby on the network |

They stand on elm-playground's `libs/networking` (`tiny_libs`):
`Wire` (values as bytes, anything that does not parse refused),
`Server` (WebSocket connections, one event loop, no thread) and, in the
tests, `Relay_client` (a native WebSocket client).

WebSocket and not UDP, which Soldat uses, because a browser gives a
page nothing else; a native program speaks it too, so both kinds of
players meet on the same server.

Nothing in the game talks to the server yet. `tests/server` does: the
protocol's bytes, the lobby's rule, and the whole server over localhost
with two real clients.

## What is to come

In the order it would be built:

1. **The game talks to the server**: a screen for the lobby (a nick, the
   rooms, the lines said), in the game itself, so in the browser too.
   The Playground has the transport for it on every platform
   (`Transport`: sockets natively, the browser's WebSocket in a page).
2. **A room is a game**: its map, its mode, its score, the server
   stepping it. `src/game` is already apart from `src/render` for this:
   the server links the one and not the other. `Soldat_update.tick`
   already knows no keyboard: it takes the one player's `intent`, and
   has to take one per player instead, wherever each comes from (the
   keyboard, a bot, the network).
3. **The game's messages**, in `Soldat_protocol` beside the lobby's: a
   player's inputs up, the world down. As Quake did, the server owns
   the game: elm-playground's `Snapshot` (the server applies each
   player's numbered inputs and sends the world a few times a second),
   `Prediction` (a player's own soldier moves at once, and is corrected
   when the server's word arrives) and `Interpolation` (the others
   drawn a little in the past, between two snapshots) are written for
   exactly this, in `tiny_libs.networking_netcode`. Soldat itself does
   otherwise for a player's own soldier: the client says where it is
   (`TMsg_ClientSpriteSnapshot_Mov` carries its position and velocity
   with its keys), which is simpler and which a modified client can lie
   about. A choice to make then.
4. **What Soldat's server has**: teams and the modes (deathmatch,
   capture the flag...), a map list, a password, bots filling a room,
   kicks and bans.

## Running one for the website

GitHub Pages serves files only: the server has to run on a machine of
its own, with `bind=0.0.0.0`. And a page served over `https://` (as
Pages' are) may only open a WebSocket that is encrypted too (`wss://`),
except to `localhost`; `Server` speaks plain `ws://`. So a public
server needs TLS in front of it (a reverse proxy, nginx or Caddy, with
a certificate), or TLS of its own. To settle when step 1 is there.
