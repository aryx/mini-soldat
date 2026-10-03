# Playing over the network

Several players in the same game, from the desktop programs and from
the browser alike, meeting on a server.

```
./bin/mini-soldat-server                       # on 127.0.0.1:23073
./bin/mini-soldat server=127.0.0.1 nick=pad    # a player, in the lobby: its rooms to choose from
./bin/mini-soldat server=127.0.0.1 nick=mm room=ctf_Ash    # or straight into a room
http://localhost:8000/play.html?server=127.0.0.1&nick=web
```

## How it is made

**The server owns the game.** A room other than the lobby is a round
(`Soldat_update.tick`, the very one a player plays alone) that the
server steps 60 times a second. A room's name is its map's (`Arena2`,
`ctf_Ash`; a name it has no map for plays on Arena2). Its six soldiers
are Soldat's bots until a player takes one, and a bot has it back when
the player leaves: a game is never empty and nobody's number changes.

| | |
|---|---|
| up, 60 a second | a player's keys and cursor, numbered: 10 bytes (`Input`) |
| up, when it changes | the weapon to come back with, by its key in Soldat's menu (`Weapon`): the keys 1 to 9 and 0, as alone |
| down, 30 a second | the round whole, what happened since the last (for the sounds and the sparks), and the number of the player's last keys played (`World`): about 4 KB |

**A player's program plays no round.** It shows the server's, with two
things of its own:

- *its own soldier at once*: a soldier's tick is a function of its
  body and its keys, so the program plays its own soldier's with the
  keys it just sent, and when the server's round comes, puts the
  soldier where the server says and plays again the keys sent since.
  A key is felt at once, whatever the distance to the server;
- *the others a little in the past*: each is drawn where it was two
  rounds ago (66 ms), between two of the server's rounds, so that it
  moves at every frame and not at every other.

Its health, its bullets, who is hit and who dies are the server's
alone. Sparks and sounds are made on each program, from what the
server says happened.

| Module | What |
|---|---|
| `src/net/Soldat_protocol` | the messages as bytes: `Hello`, `Join`, `Leave`, `Say`, `List`, `Input`, `Weapon`, `Secondary` up; `Welcome`, `Refused`, `Rooms`, `Entered`, `Came`, `Went`, `Said`, `Seat`, `World` down |
| `src/net/Soldat_wire` | the game as bytes, inside `Input` and `World`: a player's keys, a soldier's body, a round, its events |
| `src/server/Soldat_lobby` | who is in which room and who is told what: a value, no socket |
| `src/server/Soldat_room` | a room's game: its seats, each player's queue of keys, its tick, what is sent: a value too |
| `src/server/Soldat_server` | the two on the network: connections, a player seated when it enters a room, its keys routed, the rooms ticked |
| `src/orig/Soldat_online` | a player's side: the connection, its keys up, the round down, its soldier ahead, the others between two rounds, the room's talk |

## What of elm-playground it stands on

Five modules of its `tiny_libs`, and how each is used here. The
Playground's own `Multiplayer` is *not* used: its players' inputs are
keyboards (no cursor: no aim), their number is fixed for the game, and
its server-owned mode runs only inside one program (`net=simulate`);
this game needs the cursor, a server of its own with rooms, and seats
that change hands. It is built on what `Multiplayer` is built on.

| Module | The functions that matter here | Where |
|---|---|---|
| `Wire` (`networking_protocols`) | `to_bytes (fun w -> ...)` with `put_u8`, `put_u16`, `put_varint`, `put_signed`, `put_string`; `parse (fun r -> ...)` with the `get_` of each, and `fail`. `parse` refuses bytes missing and bytes left over: nothing half-read is ever used | every message (`Soldat_protocol`) and the whole game (`Soldat_wire`). It has no number that is not whole: `Soldat_wire.put_float` writes a single as two `put_u16` |
| `Server` (`networking_unix`) | `listen caps ~bind ~port`; `step` (what arrived, as `Joined`, `Message (id, bytes)`, `Left`); `send server id bytes`; `close`; `flush`; `wait server timeout`. One loop, no thread | `Soldat_server.step` and `tick`; the 60 ticks a second are the main's, which gives `wait` the time left to the next |
| `Transport` (`networking_protocols`) | `connect caps (Relay { host; port })`: a WebSocket, by sockets natively and by the browser's in a page, the same call; then the record's `send bytes`, `receive ()` (what came, never waiting) and `status ()` | `Soldat_online.connect`, `update`. A platform installs how to connect when it starts (`run_app`), so the connection is made at the first frame, not in the main |
| `Prediction` (`networking_netcode`) | `create ~me ~players ~update model`; `step t ~seq input` (my keys, played at once); `correct t ~world ~acked ~latest` (the server's word: my keys after `acked` played again on it); `model t` | `Soldat_online`: the model is the player's own body and the tick (`Soldat_soldier.t * int`), `update` is `Soldat_soldier.tick` on the player's keys. Not the whole round: the others and the bullets are not guessed |
| `Interpolation` (`networking_netcode`) | `create ~delay`; `add t ~time round`; `sample t ~now`, which gives the two rounds around `now - delay` and how far between them | `Soldat_online.shown`: each other soldier's 20 points (or its dead body's) a fraction of the way from the one to the other (`between`) |

Read but not used: `Snapshot` (`networking_netcode`), which is what
`Soldat_room` does (numbered inputs, one played a tick, the last
repeated, the world sent with the number of the last applied), for a
game whose players are there for good; a room's seats change hands,
and the transport here loses nothing (WebSocket is TCP's), so its
resending of unacknowledged inputs is not needed. And in the tests,
`Relay_client` (`networking_unix`), a native WebSocket client.

WebSocket and not UDP, which Soldat uses, because a browser gives a
page nothing else; a native program speaks it too, so both kinds of
players meet on the same server.

A room's name is its map's and, after a dot, the mode asked for
(`Soldat_model.mode_words`): `Arena2.rm` is a Rambomatch on Arena2,
`ctf_Ash.inf` an Infiltration, `Arena2` the map's own mode. In the
lobby, left and right choose the mode a new room is made with. The
second weapon is said as the first is (`Secondary`); the server's flag
`bonus=N` makes bonus kits appear in every room's rounds. Who killed
whom travels with the round, as do the deaths, the bonuses and the
vests.

## The twin: two players in lockstep

`net=host` and `net=join host=ADDRESS` (`port=7777`), both programs
started with the same flags, play a round with no server
(`Soldat_lockstep`, `docs/twins.md`): each plays the whole round, bots
and all, and only the keys are sent, 10 bytes a tick, 3 ticks ahead
(elm-playground's `Lockstep`). A checksum of the soldiers each second
says if the two rounds ever differ. Against the server's way: nothing
to run and almost nothing to send, but one's keys are always 50 ms
late and the slower connection sets both players' pace. Natively, over
UDP; not between a browser and a native program.

With the flag `rollback` on both sides, one's keys are played at once
and the other's guessed (elm-playground's `Rollback`): when the real
ones come and differ, the round goes back to that tick and is played
again, in one frame. On a network 100 ms away where lockstep plays 6
ticks in 10 frames, rollback plays nearly all of them
(`tests/server/Unit_lockstep.ml`).

## The lobby's screen

Without `room=` a player is in the lobby and sees the rooms: one for
each of the game's maps (a room's name is its map's, and a room is
made by entering it), then any other the server has, each with how
many players are in it (asked each second: `List`, `Rooms`). The
arrows (or `w` and `s`) choose, enter enters (`Join`); in a game,
escape comes back (`Leave`: the seat goes back to its bot, and a game
nobody plays is dropped). `t` says a line there as in a room. The
screen is a scene of the model (`Soldat_model.Lobby`), made each
frame by `Soldat_online` from what the server said.

## What is not there

- **Only what changed**: the round is sent whole, 125 KB a second for
  each player. Fine on a local network; a far server wants deltas, as
  Quake 3's.
- **A hit decided where the shooter saw it** (lag compensation): the
  others are drawn 66 ms in the past, and a shot is judged in the
  server's present.
- **A connection lost** is not found again; a round's end starts
  another on the same map.
- **A password, kicks, bans, a map list.**
- **A measure on a real, far connection**: the player's side is tested
  (`tests/server/Unit_online.ml`: `Soldat_online` against
  `Soldat_server` over localhost, its messages held 100 ms each way)
  and was tried by hand, two native programs and a browser's in the
  same room; never further than this computer.

What the test says of the guess: a key moves the player's soldier the
frame it is pressed, 12 frames before the server's answer; running,
jumping, on the jets, it ends where the server has it without having
been corrected once; shot by another, it is. One thing shows at the
start: until the first keys are answered (a round trip), the server
plays ticks without them and the guess adds them on top, so a soldier
falling from where it appears is shown a little ahead and put back,
five times at 100 ms each way.

## Running one for the website

GitHub Pages serves files only: the server has to run on a machine of
its own, with `bind=0.0.0.0`. And a page served over `https://` (as
Pages' are) may only open a WebSocket that is encrypted too (`wss://`),
except to `localhost`; `Server` speaks plain `ws://`. So a public
server needs TLS in front of it (a reverse proxy, nginx or Caddy, with
a certificate), or TLS of its own. Until then: the page served over
`http://` (`make serve-website`) and a server on the same machine or
network.
