(* Soldat_server over localhost, talked to by real WebSocket clients
 * (elm-playground's Relay_client): two players name themselves, one
 * makes a room, the other joins it and they talk; bytes that are no
 * message close the connection that sent them, and only that one,
 * the other told it went *)
val tests : < Cap.network ; .. > -> Testo.t list
