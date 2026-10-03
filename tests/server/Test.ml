(* Claude Code
 *
 * Copyright (C) 2026 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License
 * (LGPL) as published by the Free Software Foundation; either version
 * 2 of the License, or (at your option) any later version.
 *)

(* some builders (opam's sandbox, a container without a network) forbid
 * even a socket bound to localhost: the socket tests are then left
 * out, rather than failed *)
let sockets_allowed () : bool =
  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Fun.protect
    ~finally:(fun () -> Unix.close sock)
    (fun () ->
      match Unix.bind sock (Unix.ADDR_INET (Unix.inet_addr_loopback, 0)) with
      | () -> true
      | exception Unix.Unix_error ((Unix.EPERM | Unix.EACCES), _, _) -> false)

(* the socket tests reach the network (localhost): the capability from
 * here *)
let () =
  Cap.main (fun caps ->
      Testo.interpret_argv ~project_name:"server" (fun _env ->
          Unit_protocol.tests @ Unit_wire.tests @ Unit_lobby.tests @ Unit_room.tests @ if sockets_allowed () then Unit_server.tests caps @ Unit_online.tests caps else []))
