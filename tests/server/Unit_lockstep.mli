(* Soldat_lockstep, two peers in one program, their packets through
 * elm-playground's Sim_net (latency, jitter, loss): the two rounds are
 * the same tick after tick, each player's keys move its soldier in
 * both, a packet is a few bytes, and a slow network makes the game
 * wait, not differ *)
val tests : Testo.t list
