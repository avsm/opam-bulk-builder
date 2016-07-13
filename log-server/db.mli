type t = 
  < add : string -> string Lwt.t; delete : string -> bool Lwt.t;
    get : string -> string option Lwt.t >

val file : string -> t
val memory : unit -> t

