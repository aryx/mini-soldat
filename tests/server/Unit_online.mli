(* Soldat_online against Soldat_server over localhost, a frame of the
 * one for a tick of the other, its connection made slow (messages
 * held some frames each way): it gets a seat; its own soldier moves
 * the frame a key is pressed, before the server knows of it, and ends
 * where the server has it without ever being corrected, running,
 * jumping and jetting; shot by another player it is corrected; and
 * that other one moves in every frame though rounds come every other *)
val tests : < Cap.network ; .. > -> Testo.t list
